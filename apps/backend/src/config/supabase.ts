import { createClient } from '@supabase/supabase-js';

// Anon client — used ONLY to verify user JWTs (respects RLS)
// All DB operations go through Prisma, not Supabase client
export const supabaseAnon = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);
