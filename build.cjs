const fs = require('fs');
const path = require('path');

const root = __dirname;
const dist = path.join(root, 'dist');
const files = [
  'index.html',
  'styles.css',
  'script.js',
  'script-v416.js',
  'supabase-client.js',
  'config.js',
  'server.cjs',
  'package.json',
  'build.cjs',
  'VERSION.txt',
  'CONSOLIDATED_MANIFEST.json',
  'NEXT_THREAD_HANDOFF.md',
  'CLIENT_SETUP_README.md',
  'RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql',
  'RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql',
  'RUN_AFTER_V401_AGENCY_JOB_BOARD.sql',
  'RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql',
  'RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql',
  'RUN_AFTER_V404_MARKETPLACE_ROLE_CLEANUP.sql',
  'RUN_AFTER_V405_AGENCY_GUARD_DIRECT_ADD.sql',
  'RUN_AFTER_V406_AGENCY_ASSIGNMENT_UI_FIX.sql',
  'RUN_AFTER_V407_AGENCY_LIVE_GPS_ROUTE_VISIBILITY.sql',
  'RUN_AFTER_V408_AGENCY_LIVE_GPS_BOOT_FIX.sql',
  'RUN_AFTER_V409_PLATFORM_COMMAND_CENTER_MAP.sql',
  'RUN_AFTER_V410_PLATFORM_REAL_MAP_ALIGNMENT.sql',
  'RUN_AFTER_V411_GUARD_MARKETPLACE_JOB_FLOW.sql',
  'RUN_AFTER_V412_PLATFORM_LIFECYCLE_SYNC_FIX.sql',
  'RUN_AFTER_V413_BUILD_LABEL_LOCK_FIX.sql',
  'RUN_AFTER_V414_MARKETPLACE_ACTIVITY_GUARD_STATUS_FEED.sql',
  'RUN_AFTER_V415_BADGE_HARD_LOCK_ACTIVITY_FEED.sql',
  'RUN_AFTER_V416_SCRIPT_CACHE_KILLER_ACTIVITY_FEED.sql',
  'RUN_IF_NEEDED_OPTIONAL_SQL_PATCHES_V1312_TO_V1322.sql'
];

fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });

let count = 0;
for (const file of files) {
  const src = path.join(root, file);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(dist, file));
    count++;
  }
}

console.log(`Co Pilot Security Marketplace v4.0.16 script cache killer + activity feed build complete. Copied ${count} files to dist/.`);
