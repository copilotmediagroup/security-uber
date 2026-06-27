const fs = require('fs');
const path = require('path');

const root = __dirname;
const dist = path.join(root, 'dist');
const files = [
  'index.html',
  'styles.css',
  'script.js',
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

console.log(`Co Pilot Security Marketplace v4.0.1 agency job board build complete. Copied ${count} files to dist/.`);
