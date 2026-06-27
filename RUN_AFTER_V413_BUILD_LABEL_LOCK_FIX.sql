-- Co Pilot Security Marketplace v4.0.13
-- Build Label Lock Fix
-- No schema change required. Optional PostgREST cache refresh only.
notify pgrst, 'reload schema';
