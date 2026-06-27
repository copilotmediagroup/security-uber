const http = require('http');
const fs = require('fs');
const path = require('path');

// v4.0.17: Always serve root files. Do NOT prefer /dist,
// because stale dist/index.html was keeping Bolt locked on older badges.
const root = __dirname;
const port = process.env.PORT || 5173;

function readBuildLabel() {
  try {
    const versionPath = path.join(root, 'VERSION.txt');
    if (fs.existsSync(versionPath)) {
      const text = fs.readFileSync(versionPath, 'utf8');
      const version = (text.match(/Version:\s*([^\n]+)/) || [])[1]?.trim();
      const build = (text.match(/Build Name:\s*([^\n]+)/) || [])[1]?.trim();
      if (version && build) return `v${version} ${build}`;
      if (version) return `v${version}`;
    }
  } catch {}
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
    if (pkg?.version) return `v${pkg.version}`;
  } catch {}
  return 'current build';
}

const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
  '.sql': 'text/plain; charset=utf-8'
};

function resolveTarget(urlPath = '/') {
  const clean = urlPath === '/' ? '/index.html' : decodeURIComponent(urlPath);
  const file = path.normalize(path.join(root, clean));
  return file.startsWith(root) ? file : null;
}

http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  const target = resolveTarget(url.pathname);
  if (!target) {
    res.writeHead(403);
    return res.end('Forbidden');
  }

  fs.readFile(target, (err, data) => {
    if (err) {
      fs.readFile(path.join(root, 'index.html'), (e, html) => {
        if (e) {
          res.writeHead(404);
          return res.end('Not found');
        }
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate' });
        res.end(html);
      });
      return;
    }

    res.writeHead(200, {
      'Content-Type': types[path.extname(target)] || 'application/octet-stream',
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
      Pragma: 'no-cache',
      Expires: '0'
    });
    res.end(data);
  });
}).listen(port, () => console.log(`Co Pilot Security ${readBuildLabel()} running on http://localhost:${port}`));
