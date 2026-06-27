const fs = require('fs');
const path = require('path');

const root = __dirname;
const dist = path.join(root, 'dist');
const files = [
  "index.html",
  "styles.css",
  "script-v432.js",
  "script.js",
  "supabase-client.js",
  "config.js",
  "server.cjs",
  "package.json",
  "build.cjs",
  "VERSION.txt",
  "CONSOLIDATED_MANIFEST.json",
  "NEXT_THREAD_HANDOFF.md",
  "CLIENT_SETUP_README.md",
  "RUN_IF_NEEDED_ALL_SQL_V400_TO_V422_CONSOLIDATED.sql",
  "RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql",
  "RUN_ONCE_V432_AGENCY_LOGO_VISIBILITY_FIX.sql"
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

console.log(`Co Pilot Security Marketplace v4.0.32 COMPACT COMPANY CARD LOGO + MAP HEADER CLEANUP build complete. Copied ${count} files to dist/.`);
