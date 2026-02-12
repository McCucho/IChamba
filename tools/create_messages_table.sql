-- Messages table for user-to-user messaging
CREATE TABLE IF NOT EXISTS public.messages (
  id BIGSERIAL PRIMARY KEY,
  sender_id UUID NOT NULL,
  receiver_id UUID NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  read BOOLEAN NOT NULL DEFAULT false
);

-- Index for fast conversation lookups
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages (sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON public.messages (receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages (sender_id, receiver_id, created_at DESC);

-- Enable RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert messages they send
CREATE POLICY messages_insert ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Allow users to read messages they sent or received
CREATE POLICY messages_select ON public.messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Allow receiver to mark messages as read
CREATE POLICY messages_update_read ON public.messages
  FOR UPDATE USING (auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = receiver_id);
