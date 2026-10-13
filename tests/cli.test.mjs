import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
function cli(...args) { return spawnSync(process.execPath, ['scripts/moonged.mjs', ...args], { cwd: root, encoding: 'utf8' }); }

test('CLI uses the MoonBit engine for Unicode inspection and family paths', () => {
  const inspected = cli('inspect', 'examples/family.ged');
  assert.equal(inspected.status, 0, inspected.stderr);
  const result = JSON.parse(inspected.stdout);
  assert.equal(result.people.length, 5);
  assert.equal(result.families.length, 2);
  assert.equal(result.people[0].name, '安 /李/');
  const path = cli('path', 'examples/family.ged', 'I5', 'I1');
  assert.equal(path.status, 0, path.stderr);
  const steps = JSON.parse(path.stdout);
  assert.deepEqual(steps.map(e => e.to), ['I3', 'I1']);
  assert.equal(steps[0].pedigree, 'ADOPTED');
});

test('audit errors produce a readable report with exit 2 and cannot build an ambiguous graph', () => {
  const bad = cli('inspect', 'examples/broken.ged');
  assert.equal(bad.status, 2);
  assert.equal(JSON.parse(bad.stdout).valid, false);
  assert.match(bad.stdout, /dangling-pointer/);
  assert.match(bad.stdout, /duplicate-id/);
  const query = cli('ancestors', 'examples/broken.ged', 'I1');
  assert.equal(query.status, 1);
  assert.match(query.stderr, /fix interchange errors/);
});

test('normalized UTF8 can be inspected again and files are saved without overwrite or residue', () => {
  const directory = mkdtempSync(join(tmpdir(), 'moonged-'));
  try {
    const output = join(directory, '导出.ged');
    const saved = cli('normalize', 'examples/family.ged', '--save', output);
    assert.equal(saved.status, 0, saved.stderr);
    assert.equal(saved.stdout, '');
    const before = readFileSync(output);
    assert.equal(cli('inspect', output).status, 0);
    assert.equal(cli('normalize', 'examples/family.ged', '--save', output).status, 1);
    assert.deepEqual(readFileSync(output), before);
    assert.deepEqual(readdirSync(directory), ['导出.ged']);
    const input = join(directory, 'invalid.ged');
    writeFileSync(input, 'malformed');
    const invalidOutput = join(directory, 'invalid-out.ged');
    assert.equal(cli('normalize', input, '--save', invalidOutput).status, 1);
    assert.deepEqual(readdirSync(directory).sort(), ['invalid.ged', '导出.ged'].sort());
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('malformed UTF8 and unknown command flags fail explicitly', () => {
  const directory = mkdtempSync(join(tmpdir(), 'moonged-utf8-'));
  try {
    const bad = join(directory, 'bad.ged');
    writeFileSync(bad, Buffer.from([0xc0, 0x80]));
    assert.equal(cli('inspect', bad).status, 1);
    assert.equal(cli('inspect', 'examples/family.ged', '--unknown').status, 2);
    assert.equal(cli('normalize', 'examples/family.ged', '--save', 'a', '--save', 'b').status, 2);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
