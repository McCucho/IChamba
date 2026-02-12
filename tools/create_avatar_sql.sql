-- Create column for avatar URL
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Example RLS: allow authenticated users to update their own row
-- Enable RLS (if not already enabled)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policy to allow authenticated users to update only their row
CREATE POLICY allow_update_own_profile ON public.users
  FOR UPDATE
  USING (auth.uid() = auth_id)
  WITH CHECK (auth.uid() = auth_id);

-- Note: Depending on your schema, `auth_id` should contain the Supabase
-- authenticated user's ID for that row. Adjust column names if different.
