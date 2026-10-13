import http from 'node:http';
import { readFile, realpath } from 'node:fs/promises';
import { dirname, resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.ged': 'text/plain' };
http.createServer(async (req, res) => {
  try {
    if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
    const pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
    const relative = pathname === '/' ? 'demo/index.html' : pathname.slice(1);
    if (relative.split('/').some(part => part.startsWith('.'))) throw new Error('private path');
    const file = await realpath(resolve(root, relative));
    if (!file.startsWith(root + sep)) throw new Error('outside project');
    const bytes = await readFile(file);
    res.writeHead(200, { 'Content-Type': `${types[extname(file)] ?? 'application/octet-stream'}; charset=utf-8`, 'Cache-Control': 'no-store' });
    res.end(req.method === 'HEAD' ? undefined : bytes);
  } catch { res.writeHead(404).end('Not found'); }
}).listen(4273, '127.0.0.1', () => console.log('MoonGED demo: http://127.0.0.1:4273/'));
