# MoonGED

[中文](README.md) · [Semantic conformance](docs/semantic-conformance.md) · [Text interchange](docs/text-conformance.md)

Original MoonBit GEDCOM 7 interchange, validation and relationship-query library. SDK, Node CLI and local workbench use the same core-only implementation. Synthetic examples contain no real family records.

Version 0.2.0 implements the pinned GEDCOM 7.0.18 standard tables: 179 structure types, 1,379 parent/child combinations, 9 dataset contexts and all 12 enum sets. Contextual payload validation covers every standard payload class, including DateExact/DatePeriod, four calendars, ages, time, names, lists, BCP 47 syntax, media types, URI references, file paths and coordinates. Normative family reciprocity, source/note/media cycles, translation formats and REFN conflicts receive line-numbered diagnostics.

Gregorian, Julian and Hebrew dates have calendar arithmetic; French Republican arithmetic uses historical years 1–14. Unknown extension calendars and extrapolated French years remain unassessed instead of silently becoming Gregorian. Lexical years can exceed the arithmetic resource limit. Approximate dates do not acquire fabricated exact birthdays. HTML notes have an inert standard plain-text projection.

```sh
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target wasm --deny-warn
node scripts/build-engine.mjs
node --test tests/*.test.mjs
node scripts/moonged.mjs inspect examples/family.ged
node scripts/serve.mjs
```

Open http://127.0.0.1:4273/ for the Chinese local workbench. Files stay local. CLI also provides normalize, csv, people, ancestors, descendants, path and nodes. Output saving refuses to overwrite existing files. Run inspect before exporting; normalize itself preserves containers, including invalid semantic content.

Local validation: 55 library tests + 2 independent consumer tests on JS/Wasm GC/Wasm; 11 Node tests, including 2,422 official-YAML positive/negative cases; 1,040 independent pyluach calendar boundary vectors; and 36 independently parsed input/output documents. Native results are established by Actions. Reports include oracle limitations and do not constitute external certification.

`examples/consumer` demonstrates the public package. See `pkg.generated.mbti` and [registry verification](docs/registry-verification.md). Graph queries require unambiguous targets but can still describe explicit links in incomplete records. Whole-document writing retains all structure types, text, ordering, pointers and opaque extensions. CSV is a lossy projection. Identifier remapping changes actual references; record extraction follows the full pointer closure.

Scope: GEDCOM 7.0 dataset chapters 1–3, standard structural/payload checking and documented machine-checkable semantic rules. Extension meanings, live IANA registration, external resource content and historical truth are not remotely certified. GEDZIP, GEDCOM 5 conversion and media downloading are outside this release. Default configurable resource limits are 100,000 nodes, depth 128, line 1,048,576 UTF-16 units and document 16,777,216 units. Date arithmetic supports years 1–9,999,999. Full documents remain in memory.

Implementation code is MIT. Vendored standard data and generated tables retain their Apache-2.0 license and NOTICE. See THIRD_PARTY_NOTICES.md.
