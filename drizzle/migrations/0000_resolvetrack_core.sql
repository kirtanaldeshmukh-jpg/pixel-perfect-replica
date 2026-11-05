CREATE TYPE public.app_role AS ENUM ('student','staff','hod','admin');
CREATE TYPE public.complaint_status AS ENUM ('SUBMITTED','UNDER_REVIEW','ASSIGNED','IN_PROGRESS','RESOLVED','CLOSED','REJECTED');
CREATE TYPE public.priority_level AS ENUM ('LOW','MEDIUM','HIGH','CRITICAL');

CREATE TABLE public.departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.departments TO authenticated;
GRANT ALL ON public.departments TO service_role;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in users read departments" ON public.departments FOR SELECT TO authenticated USING (true);
INSERT INTO public.departments (code,name) VALUES
 ('IT','IT Department'),('MAINT','Maintenance'),('HOSTEL','Hostel Administration'),
 ('CANTEEN','Canteen Administration'),('TRANSPORT','Transport Department'),
 ('LIBRARY','Library Administration'),('ACADEMIC','Academic Administration'),
 ('SECURITY','Campus Security'),('GENERAL','General Administration');

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL DEFAULT '',
  usn text UNIQUE,
  email text,
  department text,
  academic_year text,
  phone text,
  staff_department_id uuid REFERENCES public.departments(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;
CREATE OR REPLACE FUNCTION public.staff_department(_user_id uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT staff_department_id FROM public.profiles WHERE id = _user_id
$$;

CREATE POLICY "Users read own roles" ON public.user_roles FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid() OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE OR REPLACE FUNCTION public.protect_profile_fields()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN
    NEW.staff_department_id := OLD.staff_department_id;
    NEW.usn := OLD.usn;
    NEW.email := OLD.email;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
CREATE TRIGGER profiles_protect BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.protect_profile_fields();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, usn, email, department, academic_year, phone)
  VALUES (NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    NULLIF(upper(trim(NEW.raw_user_meta_data->>'usn')),''),
    NEW.email,
    NEW.raw_user_meta_data->>'department',
    NEW.raw_user_meta_data->>'academic_year',
    NULLIF(NEW.raw_user_meta_data->>'phone',''));
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'student');
  RETURN NEW;
END $$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.usn_available(_usn text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT NOT EXISTS (SELECT 1 FROM public.profiles WHERE usn = upper(trim(_usn)))
$$;
GRANT EXECUTE ON FUNCTION public.usn_available(text) TO anon, authenticated;

CREATE TABLE public.deadline_config (
  priority public.priority_level PRIMARY KEY,
  hours int NOT NULL
);
GRANT SELECT, UPDATE ON public.deadline_config TO authenticated;
GRANT ALL ON public.deadline_config TO service_role;
ALTER TABLE public.deadline_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in read deadlines" ON public.deadline_config FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins update deadlines" ON public.deadline_config FOR UPDATE TO authenticated USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
INSERT INTO public.deadline_config VALUES ('CRITICAL',12),('HIGH',24),('MEDIUM',72),('LOW',120);

CREATE SEQUENCE public.complaint_code_seq;

CREATE TABLE public.complaints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  reporter_id uuid NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL,
  location text NOT NULL,
  room text,
  urgency public.priority_level NOT NULL,
  safety_impact int NOT NULL DEFAULT 0,
  reported_affected int NOT NULL DEFAULT 1,
  is_anonymous boolean NOT NULL DEFAULT false,
  priority_score int NOT NULL,
  suggested_priority public.priority_level NOT NULL,
  priority public.priority_level NOT NULL,
  priority_reason text NOT NULL,
  department_id uuid REFERENCES public.departments(id),
  assigned_staff_id uuid,
  status public.complaint_status NOT NULL DEFAULT 'SUBMITTED',
  deadline timestamptz NOT NULL,
  merged_into uuid REFERENCES public.complaints(id),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX complaints_reporter_idx ON public.complaints(reporter_id);
CREATE INDEX complaints_dept_idx ON public.complaints(department_id);
CREATE INDEX complaints_status_idx ON public.complaints(status);
GRANT SELECT ON public.complaints TO authenticated;
GRANT ALL ON public.complaints TO service_role;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read own, department, or all as admin" ON public.complaints FOR SELECT TO authenticated USING (
  reporter_id = auth.uid() OR public.has_role(auth.uid(),'admin')
  OR ((public.has_role(auth.uid(),'staff') OR public.has_role(auth.uid(),'hod')) AND department_id = public.staff_department(auth.uid()))
);

CREATE TABLE public.complaint_supports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (complaint_id, user_id)
);
GRANT SELECT ON public.complaint_supports TO authenticated;
GRANT ALL ON public.complaint_supports TO service_role;
ALTER TABLE public.complaint_supports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read own supports" ON public.complaint_supports FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(),'admin'));

CREATE TABLE public.complaint_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  previous_status public.complaint_status,
  new_status public.complaint_status NOT NULL,
  note text,
  updated_by uuid,
  updated_by_role text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX csh_complaint_idx ON public.complaint_status_history(complaint_id);
GRANT SELECT ON public.complaint_status_history TO authenticated;
GRANT ALL ON public.complaint_status_history TO service_role;
ALTER TABLE public.complaint_status_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read history of visible complaints" ON public.complaint_status_history FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.complaints c WHERE c.id = complaint_id)
);

CREATE TABLE public.priority_change_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  old_priority public.priority_level,
  new_priority public.priority_level NOT NULL,
  reason text NOT NULL,
  changed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.priority_change_history TO authenticated;
GRANT ALL ON public.priority_change_history TO service_role;
ALTER TABLE public.priority_change_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins read priority history" ON public.priority_change_history FOR SELECT TO authenticated USING (public.has_role(auth.uid(),'admin'));

CREATE TABLE public.complaint_escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  level int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (complaint_id, level)
);
GRANT SELECT ON public.complaint_escalations TO authenticated;
GRANT ALL ON public.complaint_escalations TO service_role;
ALTER TABLE public.complaint_escalations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read escalations of visible complaints" ON public.complaint_escalations FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.complaints c WHERE c.id = complaint_id)
);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL,
  message text NOT NULL,
  complaint_id uuid REFERENCES public.complaints(id) ON DELETE CASCADE,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_idx ON public.notifications(user_id, created_at DESC);
GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read own notifications" ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Mark own notifications" ON public.notifications FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE TABLE public.complaint_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL UNIQUE REFERENCES public.complaints(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  satisfied boolean NOT NULL,
  comments text CHECK (char_length(comments) <= 1000),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.complaint_feedback TO authenticated;
GRANT ALL ON public.complaint_feedback TO service_role;
ALTER TABLE public.complaint_feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read own or admin feedback" ON public.complaint_feedback FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(),'admin'));

-- helpers
CREATE OR REPLACE FUNCTION public.notify_roles(_complaint uuid, _type text, _msg text, _dept uuid, _include_staff boolean, _include_hod boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, message, complaint_id)
  SELECT DISTINCT r.user_id, _type, _msg, _complaint FROM public.user_roles r
  LEFT JOIN public.profiles p ON p.id = r.user_id
  WHERE r.role = 'admin'
     OR (_include_staff AND r.role = 'staff' AND p.staff_department_id = _dept)
     OR (_include_hod AND r.role = 'hod' AND p.staff_department_id = _dept);
END $$;
REVOKE EXECUTE ON FUNCTION public.notify_roles(uuid,text,text,uuid,boolean,boolean) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.affected_count(_complaint uuid)
RETURNS int LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.reported_affected + (SELECT count(*)::int FROM public.complaint_supports s WHERE s.complaint_id = c.id)
  FROM public.complaints c WHERE c.id = _complaint
$$;

-- submission: priority, routing, deadline computed in the database
CREATE OR REPLACE FUNCTION public.submit_complaint(
  _title text, _description text, _category text, _location text, _room text,
  _urgency public.priority_level, _safety int, _affected int, _anonymous boolean)
RETURNS TABLE (id uuid, code text, priority public.priority_level, priority_score int, priority_reason text, department text, deadline timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid uuid := auth.uid();
  u int; a int; s int; cat int; raw int; score int; pr public.priority_level;
  dept_code text; dept_id uuid; dept_name text; hrs int; dl timestamptz; new_id uuid; new_code text; reason text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  IF char_length(trim(_title)) < 5 OR char_length(_title) > 150 THEN RAISE EXCEPTION 'Title must be 5-150 characters'; END IF;
  IF char_length(trim(_description)) < 15 OR char_length(_description) > 3000 THEN RAISE EXCEPTION 'Description must be 15-3000 characters'; END IF;
  IF _safety NOT IN (0,15,30) THEN RAISE EXCEPTION 'Invalid safety impact'; END IF;
  _affected := GREATEST(1, LEAST(COALESCE(_affected,1), 5000));

  u := CASE _urgency WHEN 'LOW' THEN 10 WHEN 'MEDIUM' THEN 20 WHEN 'HIGH' THEN 30 ELSE 40 END;
  a := CASE WHEN _affected <= 5 THEN 5 WHEN _affected <= 20 THEN 10 WHEN _affected <= 50 THEN 15 ELSE 20 END;
  s := _safety;
  cat := CASE WHEN _category IN ('Electricity','Safety and Security') THEN 20
              WHEN _category IN ('Wi-Fi and Internet','Drinking Water','Sanitation','Canteen and Food Hygiene','Hostel Facilities') THEN 15
              ELSE 5 END;
  raw := u + a + s + cat;
  score := round(raw * 100.0 / 110);
  pr := CASE WHEN score >= 75 THEN 'CRITICAL' WHEN score >= 50 THEN 'HIGH' WHEN score >= 30 THEN 'MEDIUM' ELSE 'LOW' END;
  reason := initcap(lower(pr::text)) || ' priority suggested: ' || lower(_urgency::text) || ' urgency, affects ' || _affected || ' student(s)'
    || CASE WHEN s = 30 THEN ', serious safety risk' WHEN s = 15 THEN ', potential safety risk' ELSE '' END
    || CASE WHEN cat = 20 THEN ', critical infrastructure' WHEN cat = 15 THEN ', essential facility' ELSE ', normal facility issue' END
    || ' (score ' || score || '/100).';

  dept_code := CASE _category
    WHEN 'Wi-Fi and Internet' THEN 'IT' WHEN 'Laboratory Equipment' THEN 'IT'
    WHEN 'Classroom Infrastructure' THEN 'MAINT' WHEN 'Drinking Water' THEN 'MAINT'
    WHEN 'Electricity' THEN 'MAINT' WHEN 'Sanitation' THEN 'MAINT'
    WHEN 'Hostel Facilities' THEN 'HOSTEL' WHEN 'Canteen and Food Hygiene' THEN 'CANTEEN'
    WHEN 'Transportation' THEN 'TRANSPORT' WHEN 'Library' THEN 'LIBRARY'
    WHEN 'Academics' THEN 'ACADEMIC' WHEN 'Safety and Security' THEN 'SECURITY'
    ELSE 'GENERAL' END;
  SELECT d.id, d.name INTO dept_id, dept_name FROM public.departments d WHERE d.code = dept_code;
  SELECT hours INTO hrs FROM public.deadline_config WHERE deadline_config.priority = pr;
  dl := now() + make_interval(hours => hrs);
  new_code := 'RT-' || to_char(now(),'YYYY') || '-' || lpad(nextval('public.complaint_code_seq')::text, 4, '0');

  INSERT INTO public.complaints (code, reporter_id, title, description, category, location, room, urgency, safety_impact,
    reported_affected, is_anonymous, priority_score, suggested_priority, priority, priority_reason, department_id, deadline)
  VALUES (new_code, uid, trim(_title), trim(_description), _category, _location, NULLIF(trim(_room),''), _urgency, s,
    _affected, _anonymous, score, pr, pr, reason, dept_id, dl)
  RETURNING complaints.id INTO new_id;

  INSERT INTO public.complaint_status_history (complaint_id, previous_status, new_status, note, updated_by, updated_by_role)
  VALUES (new_id, NULL, 'SUBMITTED', 'Complaint submitted and routed to ' || dept_name, uid, 'student');
  INSERT INTO public.notifications (user_id, type, message, complaint_id)
  VALUES (uid, 'SUBMITTED', 'Your complaint ' || new_code || ' was submitted and routed to ' || dept_name || '.', new_id);
  PERFORM public.notify_roles(new_id, 'NEW_COMPLAINT', 'New ' || pr::text || ' complaint ' || new_code || ': ' || trim(_title), dept_id, true, true);

  RETURN QUERY SELECT new_id, new_code, pr, score, reason, dept_name, dl;
END $$;
GRANT EXECUTE ON FUNCTION public.submit_complaint(text,text,text,text,text,public.priority_level,int,int,boolean) TO authenticated;

-- duplicate detection (Jaccard over keyword tokens, plus category/location bonus)
CREATE OR REPLACE FUNCTION public.rt_tokens(_t text)
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(array_agg(DISTINCT w), '{}') FROM (
    SELECT CASE WHEN w IN ('wifi','internet','network','connection','connect','connectivity') THEN 'wifi' ELSE w END AS w
    FROM regexp_split_to_table(regexp_replace(replace(lower(COALESCE(_t,'')),'wi-fi','wifi'), '[^a-z0-9 ]', ' ', 'g'), '\s+') w
    WHERE char_length(w) > 2 AND w NOT IN ('the','and','not','for','are','was','with','this','that','from','have','has','our','all','unable','working','available','unavailable','issue','problem','college','please','there','been','very','since','its','into','any')
  ) x
$$;

CREATE OR REPLACE FUNCTION public.find_similar_complaints(_title text, _description text, _category text, _location text)
RETURNS TABLE (id uuid, code text, title text, category text, location text, status public.complaint_status, affected int, similarity int, supported boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH q AS (SELECT public.rt_tokens(_title || ' ' || _description) AS t),
  cand AS (
    SELECT c.*, public.rt_tokens(c.title || ' ' || c.description) AS t2
    FROM public.complaints c
    WHERE c.status NOT IN ('CLOSED','REJECTED') AND c.merged_into IS NULL
  ),
  scored AS (
    SELECT cand.*, (
      SELECT CASE WHEN cardinality(q.t) = 0 THEN 0 ELSE
        (SELECT count(*) FROM unnest(q.t) x WHERE x = ANY(cand.t2))::numeric
        / NULLIF((SELECT count(DISTINCT y) FROM unnest(q.t || cand.t2) y),0) END FROM q
    ) AS j
    FROM cand
  )
  SELECT s.id, s.code, s.title, s.category, s.location, s.status, public.affected_count(s.id),
    LEAST(100, round(COALESCE(s.j,0)*60 + CASE WHEN s.category = _category THEN 25 ELSE 0 END + CASE WHEN s.location = _location THEN 15 ELSE 0 END))::int AS sim,
    EXISTS (SELECT 1 FROM public.complaint_supports cs WHERE cs.complaint_id = s.id AND cs.user_id = auth.uid())
  FROM scored s
  WHERE auth.uid() IS NOT NULL
    AND s.reporter_id <> auth.uid()
    AND (COALESCE(s.j,0)*60 + CASE WHEN s.category = _category THEN 25 ELSE 0 END + CASE WHEN s.location = _location THEN 15 ELSE 0 END) >= 50
  ORDER BY sim DESC LIMIT 5
$$;
GRANT EXECUTE ON FUNCTION public.find_similar_complaints(text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.toggle_support(_complaint uuid, _support boolean)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c public.complaints; uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  SELECT * INTO c FROM public.complaints WHERE id = _complaint;
  IF NOT FOUND THEN RAISE EXCEPTION 'Complaint not found'; END IF;
  IF c.reporter_id = uid THEN RAISE EXCEPTION 'You reported this complaint'; END IF;
  IF _support THEN
    IF c.status IN ('CLOSED','REJECTED') THEN RAISE EXCEPTION 'Complaint is no longer active'; END IF;
    INSERT INTO public.complaint_supports (complaint_id, user_id) VALUES (_complaint, uid) ON CONFLICT DO NOTHING;
    IF FOUND THEN
      INSERT INTO public.notifications (user_id, type, message, complaint_id)
      VALUES (c.reporter_id, 'SUPPORTED', 'Another student supported your complaint ' || c.code || '.', c.id);
    END IF;
  ELSE
    DELETE FROM public.complaint_supports WHERE complaint_id = _complaint AND user_id = uid;
  END IF;
  RETURN public.affected_count(_complaint);
END $$;
GRANT EXECUTE ON FUNCTION public.toggle_support(uuid, boolean) TO authenticated;

-- campus board: privacy-safe columns only
CREATE OR REPLACE FUNCTION public.campus_issues()
RETURNS TABLE (id uuid, code text, title text, category text, location text, priority public.priority_level, status public.complaint_status, affected int, created_at timestamptz, overdue boolean, supported boolean, mine boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.code, c.title, c.category, c.location, c.priority, c.status, public.affected_count(c.id), c.created_at,
    (c.deadline < now() AND c.status NOT IN ('RESOLVED','CLOSED','REJECTED')),
    EXISTS (SELECT 1 FROM public.complaint_supports s WHERE s.complaint_id = c.id AND s.user_id = auth.uid()),
    c.reporter_id = auth.uid()
  FROM public.complaints c
  WHERE auth.uid() IS NOT NULL AND c.merged_into IS NULL
  ORDER BY c.created_at DESC LIMIT 200
$$;
GRANT EXECUTE ON FUNCTION public.campus_issues() TO authenticated;

-- status updates with role checks, history, notifications
CREATE OR REPLACE FUNCTION public.update_complaint_status(_complaint uuid, _status public.complaint_status, _note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c public.complaints; uid uuid := auth.uid(); is_admin boolean; is_dept boolean; role_label text;
BEGIN
  SELECT * INTO c FROM public.complaints WHERE id = _complaint;
  IF NOT FOUND THEN RAISE EXCEPTION 'Complaint not found'; END IF;
  is_admin := public.has_role(uid,'admin');
  is_dept := (public.has_role(uid,'staff') OR public.has_role(uid,'hod')) AND c.department_id = public.staff_department(uid);
  IF NOT (is_admin OR is_dept) THEN RAISE EXCEPTION 'Not authorized to update this complaint'; END IF;
  IF NOT is_admin AND _status NOT IN ('IN_PROGRESS','RESOLVED') THEN RAISE EXCEPTION 'Department staff can only mark work in progress or resolved'; END IF;
  IF c.status = _status THEN RAISE EXCEPTION 'Complaint already has this status'; END IF;
  IF char_length(COALESCE(_note,'')) > 1000 THEN RAISE EXCEPTION 'Note too long'; END IF;
  role_label := CASE WHEN is_admin THEN 'admin' WHEN public.has_role(uid,'hod') THEN 'hod' ELSE 'staff' END;
  UPDATE public.complaints SET status = _status, updated_at = now(),
    resolved_at = CASE WHEN _status = 'RESOLVED' THEN now() ELSE resolved_at END,
    assigned_staff_id = CASE WHEN _status = 'IN_PROGRESS' AND assigned_staff_id IS NULL AND NOT is_admin THEN uid ELSE assigned_staff_id END
  WHERE id = _complaint;
  INSERT INTO public.complaint_status_history (complaint_id, previous_status, new_status, note, updated_by, updated_by_role)
  VALUES (_complaint, c.status, _status, NULLIF(trim(_note),''), uid, role_label);
  INSERT INTO public.notifications (user_id, type, message, complaint_id)
  VALUES (c.reporter_id, CASE WHEN _status = 'RESOLVED' THEN 'RESOLVED' ELSE 'STATUS' END,
    'Complaint ' || c.code || ' is now ' || replace(_status::text,'_',' ') ||
    CASE WHEN _status = 'RESOLVED' THEN '. Please share your feedback.' ELSE '.' END, c.id);
END $$;
GRANT EXECUTE ON FUNCTION public.update_complaint_status(uuid, public.complaint_status, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_update_complaint(_complaint uuid, _priority public.priority_level, _department uuid, _reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c public.complaints; uid uuid := auth.uid(); dname text;
BEGIN
  IF NOT public.has_role(uid,'admin') THEN RAISE EXCEPTION 'Administrators only'; END IF;
  SELECT * INTO c FROM public.complaints WHERE id = _complaint;
  IF NOT FOUND THEN RAISE EXCEPTION 'Complaint not found'; END IF;
  IF _priority IS NOT NULL AND _priority <> c.priority THEN
    IF char_length(trim(COALESCE(_reason,''))) < 3 THEN RAISE EXCEPTION 'A reason is required to change priority'; END IF;
    INSERT INTO public.priority_change_history (complaint_id, old_priority, new_priority, reason, changed_by)
    VALUES (_complaint, c.priority, _priority, trim(_reason), uid);
    UPDATE public.complaints SET priority = _priority, updated_at = now() WHERE id = _complaint;
  END IF;
  IF _department IS NOT NULL AND (_department IS DISTINCT FROM c.department_id OR c.status IN ('SUBMITTED','UNDER_REVIEW')) THEN
    SELECT name INTO dname FROM public.departments WHERE id = _department;
    IF dname IS NULL THEN RAISE EXCEPTION 'Department not found'; END IF;
    UPDATE public.complaints SET department_id = _department, status = CASE WHEN status IN ('SUBMITTED','UNDER_REVIEW') THEN 'ASSIGNED' ELSE status END, updated_at = now() WHERE id = _complaint;
    INSERT INTO public.complaint_status_history (complaint_id, previous_status, new_status, note, updated_by, updated_by_role)
    VALUES (_complaint, c.status, CASE WHEN c.status IN ('SUBMITTED','UNDER_REVIEW') THEN 'ASSIGNED'::public.complaint_status ELSE c.status END, 'Assigned to ' || dname, uid, 'admin');
    INSERT INTO public.notifications (user_id, type, message, complaint_id) VALUES (c.reporter_id, 'ASSIGNED', 'Complaint ' || c.code || ' was assigned to ' || dname || '.', c.id);
    PERFORM public.notify_roles(c.id, 'ASSIGNED', 'Complaint ' || c.code || ' assigned to your department.', _department, true, true);
  END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.admin_update_complaint(uuid, public.priority_level, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.merge_complaint(_duplicate uuid, _primary uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE d public.complaints; p public.complaints;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'Administrators only'; END IF;
  IF _duplicate = _primary THEN RAISE EXCEPTION 'Cannot merge into itself'; END IF;
  SELECT * INTO d FROM public.complaints WHERE id = _duplicate;
  SELECT * INTO p FROM public.complaints WHERE id = _primary;
  IF d.id IS NULL OR p.id IS NULL THEN RAISE EXCEPTION 'Complaint not found'; END IF;
  UPDATE public.complaints SET merged_into = _primary, status = 'CLOSED', updated_at = now() WHERE id = _duplicate;
  INSERT INTO public.complaint_supports (complaint_id, user_id) VALUES (_primary, d.reporter_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.complaint_status_history (complaint_id, previous_status, new_status, note, updated_by, updated_by_role)
  VALUES (_duplicate, d.status, 'CLOSED', 'Merged into ' || p.code || ' (original record preserved)', auth.uid(), 'admin');
  INSERT INTO public.notifications (user_id, type, message, complaint_id)
  VALUES (d.reporter_id, 'MERGED', 'Your complaint ' || d.code || ' was merged into ' || p.code || '. You are counted as an affected student.', p.id);
END $$;
GRANT EXECUTE ON FUNCTION public.merge_complaint(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_feedback(_complaint uuid, _rating int, _satisfied boolean, _comments text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c public.complaints;
BEGIN
  SELECT * INTO c FROM public.complaints WHERE id = _complaint;
  IF c.id IS NULL OR c.reporter_id <> auth.uid() THEN RAISE EXCEPTION 'Not your complaint'; END IF;
  IF c.status <> 'RESOLVED' THEN RAISE EXCEPTION 'Feedback opens after resolution'; END IF;
  INSERT INTO public.complaint_feedback (complaint_id, user_id, rating, satisfied, comments)
  VALUES (_complaint, auth.uid(), _rating, _satisfied, NULLIF(trim(_comments),''));
  IF _satisfied THEN
    UPDATE public.complaints SET status = 'CLOSED', updated_at = now() WHERE id = _complaint;
    INSERT INTO public.complaint_status_history (complaint_id, previous_status, new_status, note, updated_by, updated_by_role)
    VALUES (_complaint, 'RESOLVED', 'CLOSED', 'Student confirmed resolution (' || _rating || '/5)', auth.uid(), 'student');
  ELSE
    UPDATE public.complaints SET status = 'UNDER_REVIEW', resolved_at = NULL, updated_at = now() WHERE id = _complaint;
    INSERT INTO public.complaint_status_history (complaint_id, previous_status, new_status, note, updated_by, updated_by_role)
    VALUES (_complaint, 'RESOLVED', 'UNDER_REVIEW', 'Reopened: student reports issue persists', auth.uid(), 'student');
    PERFORM public.notify_roles(c.id, 'REOPENED', 'Complaint ' || c.code || ' was reopened by the student.', c.department_id, true, true);
  END IF;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'Feedback already submitted';
END $$;
GRANT EXECUTE ON FUNCTION public.submit_feedback(uuid,int,boolean,text) TO authenticated;

-- escalation: idempotent per level, run on demand and on dashboard load
CREATE OR REPLACE FUNCTION public.run_escalations()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r record; lvl int; n int := 0;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  FOR r IN SELECT * FROM public.complaints WHERE deadline < now() AND status NOT IN ('RESOLVED','CLOSED','REJECTED') AND merged_into IS NULL LOOP
    lvl := CASE WHEN now() - r.deadline > (r.deadline - r.created_at) THEN 3
                WHEN now() - r.deadline > (r.deadline - r.created_at) / 2 THEN 2 ELSE 1 END;
    FOR i IN 1..lvl LOOP
      INSERT INTO public.complaint_escalations (complaint_id, level) VALUES (r.id, i) ON CONFLICT DO NOTHING;
      IF FOUND THEN
        n := n + 1;
        PERFORM public.notify_roles(r.id, 'OVERDUE', 'Escalation level ' || i || ': ' || r.code || ' is overdue.', r.department_id, i = 1, i = 2);
      END IF;
    END LOOP;
  END LOOP;
  RETURN n;
END $$;
GRANT EXECUTE ON FUNCTION public.run_escalations() TO authenticated;