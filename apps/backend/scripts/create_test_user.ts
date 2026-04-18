import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY!
);

async function createTestUser() {
  const email = 'renee@lumina.dev';
  const password = 'Lumina@2024';

  console.log('Creating dummy user...');

  // Try admin API first (needs service role key)
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: 'Renee (Demo)', roll_no: 'CS2024001' },
  });

  if (error) {
    console.warn('Admin API not available, trying regular signUp:', error.message);
    const { data: d2, error: e2 } = await supabase.auth.signUp({ email, password });
    if (e2) {
      console.error('SignUp also failed:', e2.message);
    } else {
      console.log('\n✅ User created (check Supabase dashboard to confirm email)');
      console.log('   Email   :', email);
      console.log('   Password:', password);
      console.log('   User ID :', d2.user?.id);
    }
    return;
  }

  console.log('\n✅ Dummy user created & confirmed!');
  console.log('   Email   :', email);
  console.log('   Password:', password);
  console.log('   User ID :', data.user?.id);
}

createTestUser().catch(console.error);
