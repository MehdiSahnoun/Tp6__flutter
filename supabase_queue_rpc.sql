-- Supabase SQL Function for Authoritative Queue Registration
-- Run this in the Supabase SQL Editor

CREATE OR REPLACE FUNCTION register_queue_client(
  p_id UUID,
  p_name TEXT,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_accuracy DOUBLE PRECISION,
  p_created_at TIMESTAMPTZ
)
RETURNS SETOF public.clients AS $$
BEGIN
  RETURN QUERY
  INSERT INTO public.clients (id, name, lat, lng, location_accuracy_m, created_at)
  VALUES (p_id, p_name, p_lat, p_lng, p_accuracy, p_created_at)
  ON CONFLICT (id) DO UPDATE
  SET name = EXCLUDED.name
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;