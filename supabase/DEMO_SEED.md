# Demo Seed

Primary demo seed file:

- `supabase/sql/008_reseed_bao_grocery_demo.sql`

What it does:

- Keeps `auth.users` intact.
- Resets app data in `public.*`.
- Rebuilds demo data around `bao@gmail.com`.
- Seeds grocery / mini-mart data from `2025-05-01` to `current_date`.
- Adds seasonal variation so dashboards and order history look more realistic.
- Uses Vietnamese display content for seeded names, products, customers, notes, and speaker templates.

Current seeded shape:

- 1 owner store tied to `bao@gmail.com`
- 3 demo employees
- 16 grocery-friendly products
- 3 bank accounts
- 4 speaker templates
- 1600+ orders spanning from `2025-05-01` to `2026-05-22`

Run options:

1. Supabase SQL Editor

- Open `supabase/sql/008_reseed_bao_grocery_demo.sql`
- Paste into SQL Editor
- Run

2. PowerShell + `psql`

- Set a direct database connection string in `SUPABASE_DB_URL`, or pass `-DbUrl`
- Run:

```powershell
.\supabase\scripts\reseed_demo.ps1 -DbUrl "postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"
```

Notes:

- The helper script uses `psql`. In this workspace, `supabase` CLI is not installed, so `psql` is the simplest repeatable path.
- If you prefer, you can also keep this file as the canonical SQL seed and apply it through any database client.
- Supabase MCP was used to verify the live project data after reseeding.
