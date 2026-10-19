# Changelog

## 0.2.0 — 2026-10-19

- Replace selected schema checks with the pinned 7.0.18 standard tables: 179 types, 1,379 child contexts, 9 dataset contexts, all 12 enumeration sets and every standard payload class.
- Validate contextual DateExact/DatePeriod, four calendars, ages, times, names, lists, BCP 47 syntax, media types, RFC 3986 references, file paths and coordinates. Keep huge lexical years distinct from bounded date arithmetic.
- Add Hebrew calendar arithmetic, historical French Republican arithmetic, explicit unknown-calendar boundaries, and the standard HTML-to-text projection.
- Enforce normative reciprocal family links, source/note/media acyclicity, translation inheritance/distinctness, REFN uniqueness and relocated-standard contexts. Keep safe graph queries available for incomplete records.
- Add 2,422 positive/negative official-YAML corpus cases, 1,040 independent Hebrew calendar vectors and focused semantic regressions. Retain 36 independent parser round-trips and their oracle limitations.
- Preserve Apache-2.0 standard data, license, notice and provenance; runtime implementation remains MoonBit with core-library dependencies only.

## 0.1.1 — 2026-10-16

- Distinguish pointer-valued substructures from shared-note/submitter records and spouse-age structures inside family events. Scope selected pointer/date checks to standard contexts outside tagged extension subtrees.
- Add optional BOM output to serialize/serialize_bytes; preserve existing defaults and support LF/CRLF/CR.
- Publish an explicit complete-document text interchange contract, normalization/transform boundaries, and four complex synthetic input fixtures with a whitespace golden output.
- Add seven core regressions and five Node checks. Compare 36 fixtures with the pinned independent parser and schema, retaining oracle warnings and limits.
- Pin the MoonBit compiler and standard library in CI to the verified 0.10.15+943464bfa toolchain.

## 0.1.0 — 2026-10-13

- Original MoonBit GEDCOM 7 text model, strict UTF-8 byte ingestion and bounded incremental parsers.
- Canonical writing with significant whitespace, CONT, escaped text, extension structures and pointer semantics preserved.
- Selected header, identifier, reference, relationship, Gregorian/Julian date and chronology checks.
- Person/family/event views, bounded ancestors/descendants, shortest recorded-family paths, pointer-closure extraction and collision-safe identifier remapping.
- Shared MoonBit host engine, Node CLI with non-overwriting UTF-8 file output, local browser workbench, and separate MoonBit consumer module.
- 37 library tests plus 2 independent consumer tests, 4 CLI process tests, and 33 independent parser/schema comparison fixtures.
- Clear scope boundaries: no full GEDCOM schema-conformance claim, no GEDCOM 5 conversion, no GEDZIP/media retrieval, no inferred biological kinship or production-adoption claim.
