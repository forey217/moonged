import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { run_json } from '../_build/host/engine.mjs';

function engine(command, text) {
  const response = JSON.parse(run_json(JSON.stringify({ command, text })));
  assert.equal(response.ok, true, response.error);
  return response.result;
}
function fixture(name) {
  return readFileSync(new URL(`../examples/conformance/${name}.ged`, import.meta.url), 'utf8');
}
function nodes(text) { return engine('nodes', text).map(({ line, ...node }) => node); }

test('complete document retains all seven standard record types, citations and multimedia metadata', () => {
  const text = fixture('all-records');
  const before = nodes(text);
  assert.deepEqual(before.filter(n => n.level === 0).map(n => n.tag),
    ['HEAD', 'INDI', 'INDI', 'FAM', 'SOUR', 'REPO', 'OBJE', 'SNOTE', 'SUBM', 'TRLR']);
  const output = engine('normalize', text);
  assert.deepEqual(nodes(output), before);
  assert.equal(engine('inspect', output).valid, true);
  assert.match(output, /3 TEXT 第一行抄录\n4 CONT 第二行抄录 😀/);
  assert.match(output, /1 FILE media\/portrait.jpg\n2 FORM image\/jpeg/);
  assert.match(output, /0 @N1@ SNOTE 共享注释/);
});

test('name preference, translations, Hebrew/French dates and spouse ages survive writing', () => {
  const text = fixture('names-events');
  const output = engine('normalize', text);
  assert.deepEqual(nodes(output), nodes(text));
  const report = engine('inspect', output);
  assert.equal(report.valid, true);
  assert.equal(report.diagnostics.filter(d => d.code === 'unsupported-calendar').length, 0);
  assert.deepEqual(report.people[0].names, ['/示例/安', '安 /笔名/']);
  assert.match(output, /2 HUSB\n3 AGE 25y/);
  assert.match(output, /2 DATE HEBREW 1 TSH 5660/);
  assert.match(output, /3 TIME 12:30:00Z/);
});

test('declared extension subtrees and their literal standard-looking tags are retained', () => {
  const text = fixture('extensions');
  const output = engine('normalize', text);
  assert.deepEqual(nodes(output), nodes(text));
  assert.equal(engine('inspect', output).valid, true);
  assert.match(output, /1 FAMC shelf A\n1 DATE not a calendar date/);
  assert.match(output, /1 _CATALOG @X1@/);
});

test('whole-file CLI normalization matches the explicit whitespace golden file', () => {
  const text = fixture('whitespace');
  const expected = fixture('whitespace.expected');
  assert.equal(text.charCodeAt(0), 0xfeff);
  assert.ok(text.includes('\r\n'));
  assert.ok(!text.endsWith('\n'));
  const cli = spawnSync(process.execPath,
    ['scripts/moonged.mjs', 'normalize', 'examples/conformance/whitespace.ged'],
    { cwd: new URL('../', import.meta.url), encoding: 'utf8' });
  assert.equal(cli.status, 0, cli.stderr);
  assert.equal(cli.stdout, expected);
  assert.deepEqual(nodes(expected), nodes(text));
  assert.equal(engine('normalize', expected), expected);
});

test('person CSV is an explicit projection and is never used as the GEDCOM serialization model', () => {
  const text = fixture('all-records');
  const before = engine('normalize', text);
  const csv = engine('csv', text);
  assert.ok(!csv.includes('media/portrait.jpg'));
  assert.equal(engine('normalize', text), before);
  assert.ok(before.includes('media/portrait.jpg'));
});
