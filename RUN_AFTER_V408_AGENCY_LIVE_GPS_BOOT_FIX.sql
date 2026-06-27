-- v4.0.8 Agency Live GPS Boot Fix
-- No schema change required. This only refreshes PostgREST schema cache.
notify pgrst, 'reload schema';
