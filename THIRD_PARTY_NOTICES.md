# Third-party sources

MoonGED's MoonBit implementation is original MIT code. The implementation follows the FamilySearch GEDCOM 7 specification; the specification and registries are external standards and are not relicensed by this repository.

`spec/gedcom-7.0.18/` vendors standard tables and independently extracted schema data from the official FamilySearch/GEDCOM v7.0.18 release. `schema_data.mbt` and the official-schema corpus are derived from those tables. They are governed by Apache-2.0; the full LICENSE and required NOTICE are retained in that directory. The generated file identifies these sources. The MIT project license does not replace those terms.

Hebrew test vectors were generated using pyluach 2.3.0 (MIT), https://github.com/simlist/pyluach. Only test inputs and numerical expected results are retained; pyluach code is not linked, translated or required at runtime. The handwritten date algorithm and the independent oracle agree on 1,040 month-boundary cases.

The optional interoperability check downloads the following external projects at fixed commits. They retain their own licenses in their checkouts and are not runtime dependencies of the MoonBit package:

- https://github.com/gedcom7code/js-gedcom — Luther Tychonievich; MIT / Unlicense. The original LICENSE-MIT is retained by checkout.
- https://github.com/FamilySearch/GEDCOM-registries — official GEDCOM vocabulary and validation registry; the original LICENSE and NOTICE are retained by checkout.

All `.ged` files in `examples/` and programmatically generated test fixtures are synthetic, authored for this project. They contain no real family records. The upstream implementations were used as independent references, not translated into the library.
