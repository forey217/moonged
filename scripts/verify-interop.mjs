import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { run_json } from '../_build/host/engine.mjs';

const options = new Map();
for (let i = 2; i < process.argv.length; i += 2) options.set(process.argv[i], process.argv[i + 1]);
const parserDir = options.get('--parser');
const schemaPath = options.get('--schema');
const reportPath = options.get('--report') ?? '_build/interop.json';
if (!parserDir || !schemaPath) throw new Error('Required: --parser REFERENCE_DIR --schema g7validation.json');
const { GEDCStruct, g7ConfGEDC } = await import(pathToFileURL(resolve(parserDir, 'gedcstruct.js')));
const { G7Lookups } = await import(pathToFileURL(resolve(parserDir, 'g7lookups.js')));
const { G7Dataset } = await import(pathToFileURL(resolve(parserDir, 'g7structure.js')));
const schema = JSON.parse(await readFile(schemaPath, 'utf8'));

function engine(command, text) {
  const response = JSON.parse(run_json(JSON.stringify({ command, text })));
  assert.equal(response.ok, true, response.error);
  return response.result;
}
function reference(text) {
  const syntax = [];
  const records = GEDCStruct.fromString(text, g7ConfGEDC, message => syntax.push(message));
  assert.deepEqual(syntax, [], 'independent parser syntax errors');
  const nodes = [];
  function walk(node, level) {
    let kind = 'empty', value = null;
    if (node.payload instanceof GEDCStruct) { kind = 'pointer'; value = node.payload.xref_id; }
    else if (node.payload === null) { kind = 'void'; }
    else if (typeof node.payload === 'string' && node.payload !== '') { kind = 'text'; value = node.payload; }
    nodes.push({ level, xref: node.xref_id ?? null, tag: node.tag, kind, value });
    for (const sub of node.sub) walk(sub, level + 1);
  }
  for (const record of records) walk(record, 0);
  const errors = [], warnings = [];
  const lookup = new G7Lookups(schema);
  lookup.err = message => errors.push(message);
  lookup.warn = message => warnings.push(message);
  G7Dataset.fromGEDC(records, lookup);
  return { nodes, errors, warnings };
}
const cases = [
  ['family-sample', await readFile(new URL('../examples/family.ged', import.meta.url), 'utf8')],
];
for (let i = 0; i < 32; i++) {
  const eol = ['\n', '\r\n', '\r'][i % 3];
  const note = ['@@literal@', 'significant spaces  ', '中文😀', 'comma,"quote"', 'first'][i % 5];
  const lines = ['0 HEAD', '1 SOUR MoonGED', '1 GEDC', '2 VERS 7.0', `0 @P${i}@ INDI`,
    `1 NAME Person${i} /Synthetic/`, `1 NOTE ${note}`, '2 CONT', '2 CONT more text',
    '1 BIRT', `2 DATE ${i % 2 ? 'ABT ' : ''}${1900 + i}`, '0 TRLR'];
  cases.push([`synthetic-${i}`, lines.join(eol) + eol]);
}
const results = [];
for (const [name, text] of cases) {
  const parsed = engine('nodes', text).map(({ line, ...rest }) => rest);
  const original = reference(text);
  assert.deepEqual(original.errors, [], `${name}: independent schema validation`);
  assert.deepEqual(parsed, original.nodes, `${name}: input node semantics`);
  const output = engine('normalize', text);
  const exported = reference(output);
  assert.deepEqual(exported.errors, [], `${name}: exported schema validation`);
  assert.deepEqual(exported.nodes, original.nodes, `${name}: exported node semantics`);
  results.push({ name, node_count: parsed.length, input_semantics_equal: true,
    export_semantics_equal: true, reference_schema_errors: exported.errors.length,
    reference_warnings: exported.warnings });
}
const report = { reference_limitations: ['Upstream parser groups leading payload spaces into the delimiter; that valid GEDCOM 7 case is covered by normative MoonGED tests rather than claimed as an oracle match.'], date: '2026-10-13', scope: '33 synthetic/owned fixtures; not exhaustive GEDCOM conformance',
  reference_repository: 'https://github.com/gedcom7code/js-gedcom',
  parser_commit: '9296068bd6a461cdd93f9edc74d8457995897afe',
  schema_repository: 'https://github.com/FamilySearch/GEDCOM-registries',
  schema_commit: '05519e8aa4162843e737dd761df3a2aae7ea0860',
  cases: results };
await mkdir(dirname(resolve(reportPath)), { recursive: true });
await writeFile(reportPath, JSON.stringify(report, null, 2) + '\n');
console.log(`${results.length} cases: node semantics and exports match independent parser; schema errors 0.`);
