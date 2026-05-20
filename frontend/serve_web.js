const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, 'build', 'web');
const port = Number(process.env.PORT || 8081);
const host = process.env.HOST || '0.0.0.0';
const apiTarget = process.env.API_TARGET || 'http://127.0.0.1:3000';

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const noCacheHeaders = {
    'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
    Pragma: 'no-cache',
    Expires: '0',
    'Surrogate-Control': 'no-store',
  };

  if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/uploads/')) {
    const target = new URL(`${url.pathname}${url.search}`, apiTarget);
    const proxyReq = http.request(
      target,
      {
        method: req.method,
        headers: {
          ...req.headers,
          host: target.host,
        },
      },
      (proxyRes) => {
        res.writeHead(proxyRes.statusCode || 500, proxyRes.headers);
        proxyRes.pipe(res);
      }
    );

    proxyReq.on('error', () => {
      res.writeHead(502, { 'Content-Type': 'application/json', ...noCacheHeaders });
      res.end(JSON.stringify({ message: 'Backend is not reachable' }));
    });

    req.pipe(proxyReq);
    return;
  }

  if (url.pathname === '/flutter_service_worker.js') {
    res.writeHead(200, {
      'Content-Type': 'application/javascript; charset=utf-8',
      ...noCacheHeaders,
    });
    res.end(`
self.addEventListener('install', event => self.skipWaiting());
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    if (self.caches) {
      const keys = await caches.keys();
      await Promise.all(keys.map(key => caches.delete(key)));
    }
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach(client => client.navigate(client.url));
  })());
});
`);
    return;
  }

  if (url.pathname === '/login') {
    res.writeHead(302, { Location: '/#/login', ...noCacheHeaders });
    res.end();
    return;
  }

  let filePath = path.normalize(path.join(root, decodeURIComponent(url.pathname)));

  if (!filePath.startsWith(root)) {
    res.writeHead(403, noCacheHeaders);
    res.end('Forbidden');
    return;
  }

  if (url.pathname === '/' || !path.extname(filePath)) {
    filePath = path.join(root, 'index.html');
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      fs.readFile(path.join(root, 'index.html'), (indexErr, indexData) => {
        if (indexErr) {
          res.writeHead(404, noCacheHeaders);
          res.end('Not found');
          return;
        }
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', ...noCacheHeaders });
        res.end(indexData);
      });
      return;
    }

    res.writeHead(200, {
      'Content-Type': types[path.extname(filePath)] || 'application/octet-stream',
      ...noCacheHeaders,
    });
    res.end(data);
  });
});

server.listen(port, host, () => {
  console.log(`Frontend server running at http://${host}:${port}`);
});
