# MoonGED

Original MoonBit GEDCOM 7 text interchange, genealogy relationship queries and selected data-quality checks. The library uses only MoonBit standard libraries. The CLI and local browser share a compiled MoonBit engine; JavaScript handles host I/O and UI only.

## Run

Requires MoonBit stable and Node.js 24:

```sh
moon test --target js --deny-warn
node scripts/build-engine.mjs
node scripts/moonged.mjs inspect examples/family.ged
node scripts/moonged.mjs path examples/family.ged I5 I1
node scripts/moonged.mjs normalize examples/family.ged --save exported.ged
node scripts/serve.mjs
```

Open `http://127.0.0.1:4273/`. All bundled data is synthetic. Browser files are processed locally, with an 8 MiB file limit. The UI lists up to 20 families and 500 queryable people.

## Library

Published module: [`forey217/moonged@0.1.0`](https://mooncakes.io/docs/forey217/moonged@0.1.0). Install with `moon add forey217/moonged@0.1.0`; a fresh unauthenticated consumer passed JS and WasmGC tests. See [registry verification](docs/registry-verification.md).

Public APIs cover bounded string/UTF-8 stream parsing, canonical writing, person/family/event views, selected diagnostics, Gregorian/Julian partial date ranges, bounded ancestry/descendancy, shortest recorded-family paths, reference-closure record extraction and collision-safe ID remapping. See `pkg.generated.mbti` and the separate `examples/consumer` module.

Opaque document/parser/graph containers prevent caller mutation of internal indices. Text chunks must respect Unicode character boundaries; ByteParser accepts arbitrary byte chunks. Incomplete physical lines are buffered, while the completed Document remains in memory. This is not constant-memory whole-file processing.

## Boundaries

GEDCOM 7.0 UTF-8 text only. The reader retains generic and extension structures, but the auditor is a documented subset, not a full GEDCOM schema validator. Byte preservation, GEDZIP, legacy encoding/version conversion, media retrieval, production adoption and biological kinship inference are not claimed. Approximate dates do not receive invented exact days. Unsupported calendars are retained without arithmetic. Ancestry cycles and missing reciprocal links are review warnings because non-biological relationships may be involved.

`--save` uses a temporary file and exclusive hard-link publication, refuses overwrite, requires an existing parent and a hard-link-capable filesystem. CLI exits 0 on success, 1 on parsing/I/O failure and 2 on usage/inspection errors. CSV uses RFC 4180 quoting with optional spreadsheet formula-prefix protection.

## Verification

37 core tests plus 2 external-module tests, 4 real CLI process tests, and 33 synthetic fixtures cross-checked with a pinned independent GEDCOM parser and official schema. See [interop details](docs/interop.md), including an observed limitation of the reference parser for leading payload spaces. JS and Wasm GC pass locally; native results are supplied by actual CI runs. None of these counts implies exhaustive standard conformance.

## License

MIT, original implementation based on the FamilySearch GEDCOM 7 standard. AI-assisted development is disclosed. Independent validation sources retain their own licenses and are not bundled as runtime dependencies. See `THIRD_PARTY_NOTICES.md` and [ecosystem review](docs/ecosystem-review.md).
