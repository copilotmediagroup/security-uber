-- Co Pilot Security Marketplace v4.0.12
-- PLATFORM LIFECYCLE SYNC FIX
-- This build is primarily front-end lifecycle sync. Run after v4.0.11 only to refresh PostgREST schema cache.
-- Platform Command Center reads marketplace_jobs.current_status + job_events + proof_items.

notify pgrst, 'reload schema';
