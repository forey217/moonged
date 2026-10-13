# Third-party sources

MoonGED's MoonBit implementation is original MIT code. The implementation follows the FamilySearch GEDCOM 7 specification; the specification and registries are external standards and are not relicensed by this repository.

The optional interoperability check downloads the following external projects at fixed commits. They retain their own licenses in their checkouts and are not runtime dependencies of the MoonBit package:

- https://github.com/gedcom7code/js-gedcom — Luther Tychonievich; MIT / Unlicense. The original LICENSE-MIT is retained by checkout.
- https://github.com/FamilySearch/GEDCOM-registries — official GEDCOM vocabulary and validation registry; the original LICENSE and NOTICE are retained by checkout.

All `.ged` files in `examples/` and programmatically generated test fixtures are synthetic, authored for this project. They contain no real family records. The upstream implementations were used as independent references, not translated into the library.
