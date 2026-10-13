#!/usr/bin/env node
import { readFile, stat, open, link, unlink } from 'node:fs/promises';
import { resolve, dirname, join, basename } from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const usage = `MoonGED — GEDCOM 7 library CLI
  node scripts/moonged.mjs inspect FILE
  node scripts/moonged.mjs normalize FILE [--save OUTPUT.ged]
  node scripts/moonged.mjs csv FILE [--save OUTPUT.csv]
  node scripts/moonged.mjs people FILE
  node scripts/moonged.mjs ancestors FILE ID
  node scripts/moonged.mjs descendants FILE ID
  node scripts/moonged.mjs path FILE FROM TO
  node scripts/moonged.mjs nodes FILE

Build first: moon build --target js --release cmd/engine
Exit: 0 success, 1 syntax/I/O failure, 2 usage or audit errors.
--save requires an existing parent directory and never replaces a file.
IDs omit @ delimiters. Use -- before arguments beginning with --.
`;

async function saveExclusive(path, text) {
  const destination = resolve(path);
  const temporary = join(dirname(destination), `.${basename(destination)}.${randomUUID()}.tmp`);
  let handle;
  let created = false;
  try {
    handle = await open(temporary, 'wx', 0o600);
    created = true;
    await handle.writeFile(text, 'utf8');
    await handle.sync();
    await handle.close();
    handle = undefined;
    await link(temporary, destination);
  } finally {
    await handle?.close();
    if (created) await unlink(temporary).catch(() => {});
  }
}

async function main(args) {
  if (!args.length || args[0] === '--help' || args[0] === '-h') {
    process.stdout.write(usage);
    return 0;
  }
  let save;
  let literal = false;
  const positional = [];
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (!literal && arg === '--') { literal = true; continue; }
    if (!literal && arg === '--save') {
      if (save !== undefined || i + 1 >= args.length) { process.stderr.write('Use --save exactly once with a path.\n'); return 2; }
      save = args[++i];
    } else if (!literal && arg.startsWith('--')) {
      process.stderr.write(`Unknown flag ${arg}\n`);
      return 2;
    } else { positional.push(arg); }
  }
  const [command, file, ...ids] = positional;
  const expected = new Map([['inspect', 0], ['normalize', 0], ['csv', 0], ['people', 0], ['nodes', 0], ['ancestors', 1], ['descendants', 1], ['path', 2]]);
  if (!expected.has(command) || !file || ids.length !== expected.get(command)) {
    process.stderr.write(usage);
    return 2;
  }
  const size = (await stat(file)).size;
  if (size > 64 * 1024 * 1024) throw new Error('Input exceeds the 64 MiB host file limit.');
  const bytes = await readFile(file);
  const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  const engineUrl = new URL('../_build/js/release/build/cmd/engine/engine.js', import.meta.url);
  let engine;
  try { engine = await import(engineUrl.href); }
  catch { throw new Error('Build the MoonBit engine first: moon build --target js --release cmd/engine'); }
  const request = { command, text };
  if (command === 'path') Object.assign(request, { from: ids[0], to: ids[1] });
  if (command === 'ancestors' || command === 'descendants') request.id = ids[0];
  const response = JSON.parse(engine.run_json(JSON.stringify(request)));
  if (!response.ok) throw new Error(`${response.code}${response.line ? ` at line ${response.line}` : ''}: ${response.error}`);
  const output = ['normalize', 'csv'].includes(command) ? response.result : JSON.stringify(response.result, null, 2) + '\n';
  if (save !== undefined) {
    await saveExclusive(save, output);
    process.stderr.write(`Saved ${resolve(save)}\n`);
  } else { process.stdout.write(output); }
  return command === 'inspect' && !response.result.valid ? 2 : 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.exitCode = await main(process.argv.slice(2)); }
  catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
}
