import { spawnSync } from 'node:child_process';
import { copyFile, mkdir, stat } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const result = spawnSync('moon', ['build', '--target', 'js', '--release', 'cmd/engine'],
  { cwd: root, stdio: 'inherit' });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);

// Workspaces namespace artifacts by module; standalone builds and older moon
// versions use the package path. Expose one host path for both layouts.
const candidates = [
  join(root, '_build/js/release/build/forey217/moonged/cmd/engine/engine.js'),
  join(root, '_build/js/release/build/cmd/engine/engine.js'),
];
let source;
for (const path of candidates) {
  try { if ((await stat(path)).isFile()) { source = path; break; } }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
}
if (!source) throw new Error('MoonBit build did not produce the expected engine.js artifact.');
const destination = join(root, '_build/host/engine.mjs');
await mkdir(dirname(destination), { recursive: true });
await copyFile(source, destination);
console.log('Shared engine ready: _build/host/engine.mjs');
