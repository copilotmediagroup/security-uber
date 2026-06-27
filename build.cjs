const fs = require('fs');
const path = require('path');

const root = __dirname;
const dist = path.join(root, 'dist');
const files = [
  "index.html",
  "styles.css",
  "script-v437.js",
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
  "RUN_ONCE_V433_AGENCY_LOGO_VISIBILITY_SAFE_FIX.sql"
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

console.log(`Co Pilot Security Marketplace v4.0.37 PRIORITY RESPONSE CARD CLEANUP + NO PRICING build complete. Copied ${count} files to dist/.`);
