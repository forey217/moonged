import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { run_json } from '../_build/host/engine.mjs';

const corpusBytes = readFileSync(new URL('./semantic-corpus.json', import.meta.url));
const corpus = JSON.parse(corpusBytes);
function inspect(text) {
  const response = JSON.parse(run_json(JSON.stringify({ command: 'inspect', text })));
  assert.equal(response.ok, true, response.error);
  return response.result;
}

test('official YAML corpus: every standard structure edge, singleton, required child, payload and enumeration', () => {
  const failures = [];
  for (const c of corpus) {
    const report = inspect(c.text);
    if (report.valid !== c.valid || (!c.valid && !report.diagnostics.some(d => d.code === c.code && d.severity === 'error'))) {
      failures.push({ id: c.id, expected: c.valid, diagnostics: report.diagnostics });
    }
  }
  mkdirSync('_build', { recursive: true });
  writeFileSync('_build/semantic-conformance.json', JSON.stringify({
    specification: '7.0.18', source: 'official release YAML, independently extracted from runtime TSV tables',
    corpus_sha256: createHash('sha256').update(corpusBytes).digest('hex'),
    cases: corpus.length, positive: corpus.filter(c => c.valid).length,
    structure_edges: corpus.filter(c => c.id.startsWith('edge:')).length,
    payload_types: corpus.filter(c => c.id.startsWith('payload:')).length,
    passed: corpus.length - failures.length, failures,
    limits: ['Not external certification', 'Extension meanings and external files/URLs are unassessed', 'Human-language registry and media registration are not historical fact verification']
  }, null, 2) + '\n');
  assert.deepEqual(failures.slice(0, 15), [], `${failures.length} corpus failures; see _build/semantic-conformance.json`);
});

test('legal large dates remain conformant even outside arithmetic limits', () => {
  const r = inspect('0 HEAD\n1 GEDC\n2 VERS 7.0.18\n0 INDI\n1 NAME A\n1 BIRT\n2 DATE 99999999999999999999999999999999999999999999\n0 TRLR\n');
  assert.equal(r.valid, true);
  assert.ok(r.diagnostics.some(d => d.code === 'date-arithmetic-limit' && d.severity === 'warning'));
});
