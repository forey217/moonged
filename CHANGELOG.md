# Changelog

## 0.1.0 — 2026-10-13

- Original MoonBit GEDCOM 7 text model, strict UTF-8 byte ingestion and bounded incremental parsers.
- Canonical writing with significant whitespace, CONT, escaped text, extension structures and pointer semantics preserved.
- Selected header, identifier, reference, relationship, Gregorian/Julian date and chronology checks.
- Person/family/event views, bounded ancestors/descendants, shortest recorded-family paths, pointer-closure extraction and collision-safe identifier remapping.
- Shared MoonBit host engine, Node CLI with non-overwriting UTF-8 file output, local browser workbench, and separate MoonBit consumer module.
- 35 library tests plus 2 independent consumer tests, 4 CLI process tests, and 33 independent parser/schema comparison fixtures.
- Clear scope boundaries: no full GEDCOM schema-conformance claim, no GEDCOM 5 conversion, no GEDZIP/media retrieval, no inferred biological kinship or production-adoption claim.
