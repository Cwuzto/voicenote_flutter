param(
  [string]$DbUrl,
  [string]$SqlFile = "supabase/sql/008_reseed_bao_grocery_demo.sql"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SqlFile)) {
  throw "SQL file not found: $SqlFile"
}

$resolvedSqlFile = (Resolve-Path -LiteralPath $SqlFile).Path

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
  Write-Host "psql was not found on PATH."
  Write-Host "Install PostgreSQL client tools, then run:"
  Write-Host "  .\supabase\scripts\reseed_demo.ps1 -DbUrl `"postgresql://...`""
  Write-Host ""
  Write-Host "Or open this file in Supabase SQL Editor and run it manually:"
  Write-Host "  $resolvedSqlFile"
  exit 1
}

if (-not $DbUrl) {
  if ($env:SUPABASE_DB_URL) {
    $DbUrl = $env:SUPABASE_DB_URL
  } else {
    throw "Missing -DbUrl and SUPABASE_DB_URL is not set."
  }
}

Write-Host "Applying demo seed from $resolvedSqlFile"
& $psql.Source $DbUrl -v ON_ERROR_STOP=1 -f $resolvedSqlFile
