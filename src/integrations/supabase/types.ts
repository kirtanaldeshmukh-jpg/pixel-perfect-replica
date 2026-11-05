export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      complaint_escalations: {
        Row: {
          complaint_id: string
          created_at: string
          id: string
          level: number
        }
        Insert: {
          complaint_id: string
          created_at?: string
          id?: string
          level: number
        }
        Update: {
          complaint_id?: string
          created_at?: string
          id?: string
          level?: number
        }
        Relationships: [
          {
            foreignKeyName: "complaint_escalations_complaint_id_fkey"
            columns: ["complaint_id"]
            isOneToOne: false
            referencedRelation: "complaints"
            referencedColumns: ["id"]
          },
        ]
      }
      complaint_feedback: {
        Row: {
          comments: string | null
          complaint_id: string
          created_at: string
          id: string
          rating: number
          satisfied: boolean
          user_id: string
        }
        Insert: {
          comments?: string | null
          complaint_id: string
          created_at?: string
          id?: string
          rating: number
          satisfied: boolean
          user_id: string
        }
        Update: {
          comments?: string | null
          complaint_id?: string
          created_at?: string
          id?: string
          rating?: number
          satisfied?: boolean
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "complaint_feedback_complaint_id_fkey"
            columns: ["complaint_id"]
            isOneToOne: true
            referencedRelation: "complaints"
            referencedColumns: ["id"]
          },
        ]
      }
      complaint_status_history: {
        Row: {
          complaint_id: string
          created_at: string
          id: string
          new_status: Database["public"]["Enums"]["complaint_status"]
          note: string | null
          previous_status:
            | Database["public"]["Enums"]["complaint_status"]
            | null
          updated_by: string | null
          updated_by_role: string | null
        }
        Insert: {
          complaint_id: string
          created_at?: string
          id?: string
          new_status: Database["public"]["Enums"]["complaint_status"]
          note?: string | null
          previous_status?:
            | Database["public"]["Enums"]["complaint_status"]
            | null
          updated_by?: string | null
          updated_by_role?: string | null
        }
        Update: {
          complaint_id?: string
          created_at?: string
          id?: string
          new_status?: Database["public"]["Enums"]["complaint_status"]
          note?: string | null
          previous_status?:
            | Database["public"]["Enums"]["complaint_status"]
            | null
          updated_by?: string | null
          updated_by_role?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "complaint_status_history_complaint_id_fkey"
            columns: ["complaint_id"]
            isOneToOne: false
            referencedRelation: "complaints"
            referencedColumns: ["id"]
          },
        ]
      }
      complaint_supports: {
        Row: {
          complaint_id: string
          created_at: string
          id: string
          user_id: string
        }
        Insert: {
          complaint_id: string
          created_at?: string
          id?: string
          user_id: string
        }
        Update: {
          complaint_id?: string
          created_at?: string
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "complaint_supports_complaint_id_fkey"
            columns: ["complaint_id"]
            isOneToOne: false
            referencedRelation: "complaints"
            referencedColumns: ["id"]
          },
        ]
      }
      complaints: {
        Row: {
          assigned_staff_id: string | null
          category: string
          code: string
          created_at: string
          deadline: string
          department_id: string | null
          description: string
          id: string
          is_anonymous: boolean
          location: string
          merged_into: string | null
          priority: Database["public"]["Enums"]["priority_level"]
          priority_reason: string
          priority_score: number
          reported_affected: number
          reporter_id: string
          resolved_at: string | null
          room: string | null
          safety_impact: number
          status: Database["public"]["Enums"]["complaint_status"]
          suggested_priority: Database["public"]["Enums"]["priority_level"]
          title: string
          updated_at: string
          urgency: Database["public"]["Enums"]["priority_level"]
        }
        Insert: {
          assigned_staff_id?: string | null
          category: string
          code: string
          created_at?: string
          deadline: string
          department_id?: string | null
          description: string
          id?: string
          is_anonymous?: boolean
          location: string
          merged_into?: string | null
          priority: Database["public"]["Enums"]["priority_level"]
          priority_reason: string
          priority_score: number
          reported_affected?: number
          reporter_id: string
          resolved_at?: string | null
          room?: string | null
          safety_impact?: number
          status?: Database["public"]["Enums"]["complaint_status"]
          suggested_priority: Database["public"]["Enums"]["priority_level"]
          title: string
          updated_at?: string
          urgency: Database["public"]["Enums"]["priority_level"]
        }
        Update: {
          assigned_staff_id?: string | null
          category?: string
          code?: string
          created_at?: string
          deadline?: string
          department_id?: string | null
          description?: string
          id?: string
          is_anonymous?: boolean
          location?: string
          merged_into?: string | null
          priority?: Database["public"]["Enums"]["priority_level"]
          priority_reason?: string
          priority_score?: number
          reported_affected?: number
          reporter_id?: string
          resolved_at?: string | null
          room?: string | null
          safety_impact?: number
          status?: Database["public"]["Enums"]["complaint_status"]
          suggested_priority?: Database["public"]["Enums"]["priority_level"]
          title?: string
          updated_at?: string
          urgency?: Database["public"]["Enums"]["priority_level"]
        }
        Relationships: [
          {
            foreignKeyName: "complaints_department_id_fkey"
            columns: ["department_id"]
            isOneToOne: false
            referencedRelation: "departments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "complaints_merged_into_fkey"
            columns: ["merged_into"]
            isOneToOne: false
            referencedRelation: "complaints"
            referencedColumns: ["id"]
          },
        ]
      }
      deadline_config: {
        Row: {
          hours: number
          priority: Database["public"]["Enums"]["priority_level"]
        }
        Insert: {
          hours: number
          priority: Database["public"]["Enums"]["priority_level"]
        }
        Update: {
          hours?: number
          priority?: Database["public"]["Enums"]["priority_level"]
        }
        Relationships: []
      }
      departments: {
        Row: {
          code: string
          created_at: string
          id: string
          name: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          complaint_id: string | null
          created_at: string
          id: string
          message: string
          read_at: string | null
          type: string
          user_id: string
        }
        Insert: {
          complaint_id?: string | null
          created_at?: string
          id?: string
          message: string
          read_at?: string | null
          type: string
          user_id: string
        }
        Update: {
          complaint_id?: string | null
          created_at?: string
          id?: string
          message?: string
          read_at?: string | null
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_complaint_id_fkey"
            columns: ["complaint_id"]
            isOneToOne: false
            referencedRelation: "complaints"
            referencedColumns: ["id"]
          },
        ]
      }
      priority_change_history: {
        Row: {
          changed_by: string | null
          complaint_id: string
          created_at: string
          id: string
          new_priority: Database["public"]["Enums"]["priority_level"]
          old_priority: Database["public"]["Enums"]["priority_level"] | null
          reason: string
        }
        Insert: {
          changed_by?: string | null
          complaint_id: string
          created_at?: string
          id?: string
          new_priority: Database["public"]["Enums"]["priority_level"]
          old_priority?: Database["public"]["Enums"]["priority_level"] | null
          reason: string
        }
        Update: {
          changed_by?: string | null
          complaint_id?: string
          created_at?: string
          id?: string
          new_priority?: Database["public"]["Enums"]["priority_level"]
          old_priority?: Database["public"]["Enums"]["priority_level"] | null
          reason?: string
        }
        Relationships: [
          {
            foreignKeyName: "priority_change_history_complaint_id_fkey"
            columns: ["complaint_id"]
            isOneToOne: false
            referencedRelation: "complaints"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          academic_year: string | null
          created_at: string
          department: string | null
          email: string | null
          full_name: string
          id: string
          phone: string | null
          staff_department_id: string | null
          updated_at: string
          usn: string | null
        }
        Insert: {
          academic_year?: string | null
          created_at?: string
          department?: string | null
          email?: string | null
          full_name?: string
          id: string
          phone?: string | null
          staff_department_id?: string | null
          updated_at?: string
          usn?: string | null
        }
        Update: {
          academic_year?: string | null
          created_at?: string
          department?: string | null
          email?: string | null
          full_name?: string
          id?: string
          phone?: string | null
          staff_department_id?: string | null
          updated_at?: string
          usn?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_staff_department_id_fkey"
            columns: ["staff_department_id"]
            isOneToOne: false
            referencedRelation: "departments"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_update_complaint: {
        Args: {
          _complaint: string
          _department: string
          _priority: Database["public"]["Enums"]["priority_level"]
          _reason: string
        }
        Returns: undefined
      }
      affected_count: { Args: { _complaint: string }; Returns: number }
      campus_issues: {
        Args: never
        Returns: {
          affected: number
          category: string
          code: string
          created_at: string
          id: string
          location: string
          mine: boolean
          overdue: boolean
          priority: Database["public"]["Enums"]["priority_level"]
          status: Database["public"]["Enums"]["complaint_status"]
          supported: boolean
          title: string
        }[]
      }
      find_similar_complaints: {
        Args: {
          _category: string
          _description: string
          _location: string
          _title: string
        }
        Returns: {
          affected: number
          category: string
          code: string
          id: string
          location: string
          similarity: number
          status: Database["public"]["Enums"]["complaint_status"]
          supported: boolean
          title: string
        }[]
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      merge_complaint: {
        Args: { _duplicate: string; _primary: string }
        Returns: undefined
      }
      notify_roles: {
        Args: {
          _complaint: string
          _dept: string
          _include_hod: boolean
          _include_staff: boolean
          _msg: string
          _type: string
        }
        Returns: undefined
      }
      rt_tokens: { Args: { _t: string }; Returns: string[] }
      run_escalations: { Args: never; Returns: number }
      staff_department: { Args: { _user_id: string }; Returns: string }
      submit_complaint: {
        Args: {
          _affected: number
          _anonymous: boolean
          _category: string
          _description: string
          _location: string
          _room: string
          _safety: number
          _title: string
          _urgency: Database["public"]["Enums"]["priority_level"]
        }
        Returns: {
          code: string
          deadline: string
          department: string
          id: string
          priority: Database["public"]["Enums"]["priority_level"]
          priority_reason: string
          priority_score: number
        }[]
      }
      submit_feedback: {
        Args: {
          _comments: string
          _complaint: string
          _rating: number
          _satisfied: boolean
        }
        Returns: undefined
      }
      toggle_support: {
        Args: { _complaint: string; _support: boolean }
        Returns: number
      }
      update_complaint_status: {
        Args: {
          _complaint: string
          _note: string
          _status: Database["public"]["Enums"]["complaint_status"]
        }
        Returns: undefined
      }
      usn_available: { Args: { _usn: string }; Returns: boolean }
    }
    Enums: {
      app_role: "student" | "staff" | "hod" | "admin"
      complaint_status:
        | "SUBMITTED"
        | "UNDER_REVIEW"
        | "ASSIGNED"
        | "IN_PROGRESS"
        | "RESOLVED"
        | "CLOSED"
        | "REJECTED"
      priority_level: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["student", "staff", "hod", "admin"],
      complaint_status: [
        "SUBMITTED",
        "UNDER_REVIEW",
        "ASSIGNED",
        "IN_PROGRESS",
        "RESOLVED",
        "CLOSED",
        "REJECTED",
      ],
      priority_level: ["LOW", "MEDIUM", "HIGH", "CRITICAL"],
    },
  },
} as const
