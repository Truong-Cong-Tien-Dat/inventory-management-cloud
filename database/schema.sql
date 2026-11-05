-- psql entry point for a fresh database.
-- Run with: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/schema.sql
\ir migrations/001_init.sql
