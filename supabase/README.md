# Supabase Bootstrap Guide

Run in order from Supabase SQL Editor:
1. `supabase/sql/001_schema.sql`
2. `supabase/sql/002_rls.sql`
3. `supabase/sql/011_add_is_default_to_bank_accounts.sql`
4. `supabase/sql/003_seed_demo.sql` (edit username first)

For the current Bao grocery demo reset / reseed flow, use:
- `supabase/sql/008_reseed_bao_grocery_demo.sql`
- Guide: `supabase/DEMO_SEED.md`

## Important
- In app code, keep env keys as:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Run app with:
  - `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## Why I cannot connect directly
I cannot sign in to your Supabase account from this session, so I prepare runnable SQL/scripts and you execute them in your project.
