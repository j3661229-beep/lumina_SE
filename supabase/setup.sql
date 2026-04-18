-- =============================================================
-- LUMINA — Raw SQL Setup (run AFTER prisma db push/migrate)
-- Handles: views, materialized views, RLS, realtime, triggers
-- Run once in Supabase SQL Editor
-- =============================================================

-- ============================================================
-- EXTENSIONS (Prisma db push won't create these automatically)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- GENERATED COLUMN: duration_secs on context_switch_logs
-- (Prisma doesn't support generated columns natively)
-- ============================================================
ALTER TABLE public.context_switch_logs
  ADD COLUMN IF NOT EXISTS duration_secs INTEGER
  GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (session_end - session_start))::integer
  ) STORED;

-- ============================================================
-- MATERIALIZED VIEW: attendance_summary
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS public.attendance_summary AS
SELECT
  al.user_id,
  ts.subject_id,
  s.name AS subject_name,
  COUNT(*) FILTER (WHERE al.status = 'present') AS attended,
  COUNT(*) FILTER (WHERE al.status IN ('present','absent')) AS total_held,
  ROUND(
    COUNT(*) FILTER (WHERE al.status = 'present')::numeric /
    NULLIF(COUNT(*) FILTER (WHERE al.status IN ('present','absent')), 0) * 100, 2
  ) AS percentage,
  GREATEST(
    0,
    FLOOR(
      (COUNT(*) FILTER (WHERE al.status = 'present') - 0.75 *
       COUNT(*) FILTER (WHERE al.status IN ('present','absent'))) / 0.75
    )
  ) AS bunks_remaining
FROM public.attendance_logs al
JOIN public.timetable_slots ts ON al.slot_id = ts.id
JOIN public.subjects s ON ts.subject_id = s.id
GROUP BY al.user_id, ts.subject_id, s.name;

CREATE UNIQUE INDEX IF NOT EXISTS attendance_summary_user_subject
  ON public.attendance_summary (user_id, subject_id);

-- ============================================================
-- VIEW: weekly_expense_summary
-- ============================================================
CREATE OR REPLACE VIEW public.weekly_expense_summary AS
SELECT
  user_id,
  DATE_TRUNC('week', expense_date) AS week_start,
  category,
  SUM(amount)  AS total,
  COUNT(*)     AS transaction_count
FROM public.expenses
GROUP BY user_id, DATE_TRUNC('week', expense_date), category;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetable_slots      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_logs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.context_switch_logs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cognitive_debt_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.squad_flow_snapshots  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_strokes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pasteboard_items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kanban_tasks         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_events      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses             ENABLE ROW LEVEL SECURITY;

-- Profiles: own row only
CREATE POLICY "profiles_own" ON public.profiles
  FOR ALL USING (auth.uid() = id);

-- Groups: members can read
CREATE POLICY "groups_member_read" ON public.groups
  FOR SELECT USING (
    id IN (SELECT group_id FROM public.group_members WHERE profile_id = auth.uid())
  );
CREATE POLICY "groups_creator_write" ON public.groups
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- Group members
CREATE POLICY "group_members_view" ON public.group_members
  FOR SELECT USING (
    group_id IN (SELECT group_id FROM public.group_members WHERE profile_id = auth.uid())
  );
CREATE POLICY "group_members_join" ON public.group_members
  FOR INSERT WITH CHECK (profile_id = auth.uid());

-- Personal data (subjects, timetable, attendance, expenses, calendar, context)
DO $$
DECLARE tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'subjects','timetable_slots','attendance_logs',
    'context_switch_logs','cognitive_debt_scores',
    'calendar_events','expenses'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY "%s_own" ON public.%I FOR ALL USING (user_id = auth.uid())',
      tbl, tbl
    );
  END LOOP;
END $$;

-- Group content: group members can CRUD
DO $$
DECLARE tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'messages','whiteboard_strokes','pasteboard_items',
    'kanban_tasks','squad_flow_snapshots'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY "%s_group_member" ON public.%I FOR ALL USING (
        group_id IN (SELECT group_id FROM public.group_members WHERE profile_id = auth.uid())
      )',
      tbl, tbl
    );
  END LOOP;
END $$;

-- ============================================================
-- REALTIME
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.whiteboard_strokes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.kanban_tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.pasteboard_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.squad_flow_snapshots;

-- ============================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================

-- Auto-create profile on Supabase auth sign-up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-refresh attendance materialized view
CREATE OR REPLACE FUNCTION public.refresh_attendance_summary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.attendance_summary;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER refresh_attendance_on_change
  AFTER INSERT OR UPDATE OR DELETE ON public.attendance_logs
  FOR EACH STATEMENT EXECUTE FUNCTION public.refresh_attendance_summary();
