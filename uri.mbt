///|
// Extension identifiers can use URNs and other URI schemes. No network lookup.
fn documented_uri(value : StringView) -> Bool {
  let parts = value.split_once(":")
  guard parts is Some((scheme, payload)) else { return false }
  if scheme.is_empty() || payload.is_empty() || value.contains_char('\t') {
    return false
  }
  let first = scheme[0]
  if !((first >= 65 && first <= 90) || (first >= 97 && first <= 122)) {
    return false
  }
  scheme
  .code_units()
  .all(fn(c) {
    (c >= 65 && c <= 90) ||
    (c >= 97 && c <= 122) ||
    (c >= 48 && c <= 57) ||
    c == 43 ||
    c == 45 ||
    c == 46
  })
}
