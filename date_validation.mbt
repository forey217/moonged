///|
/// Validate arbitrarily long lexical years without narrowing them to machine ints.
/// Arithmetic limits in parse_date are reported separately from conformance.
fn normalized_date_point(s : String, ctx : SchemaContext) -> String? {
  let ts = s.split(" ").map(fn(x) { x.to_owned() }).to_array()
  if ts.any(fn(x) { x == "" }) {
    return None
  }
  let mut cal = "GREGORIAN"
  if ["GREGORIAN", "JULIAN", "HEBREW", "FRENCH_R"].contains(ts[0]) ||
    ts[0].has_prefix("_") {
    cal = ts[0]
    if ctx.declarations.get(cal) is Some(uri) &&
      uri.has_prefix("https://gedcom.io/terms/v7/cal-") {
      cal = uri[31:].to_owned()
    }
    ts.remove(0) |> ignore
  }
  let mut epoch = ""
  if ts.get(ts.length() - 1) is Some(t) && (t == "BCE" || t.has_prefix("_")) {
    epoch = t
    ts.remove(ts.length() - 1) |> ignore
  }
  if ts.length() < 1 || ts.length() > 3 {
    return None
  }
  let year = ts[ts.length() - 1]
  if !ascii_digits(year) || year.code_units().all(fn(c) { c == 48 }) {
    return None
  }
  let mut n = 0
  let cycle = if cal == "HEBREW" {
    689472
  } else if cal == "JULIAN" {
    4
  } else {
    400
  }
  for c in year.code_units() {
    n = (n * 10 + c.to_int() - 48) % cycle
  }
  if n == 0 {
    n = cycle
  }
  // Use actual year when bounded; French leap history has no agreed prolepsis.
  let bounded = @string.parse_int(year[:]) catch { _ => 0 }
  if bounded > 0 && bounded <= 9999999 {
    n = bounded
  } else if cal == "FRENCH_R" {
    n = 9999999
  }
  ts[ts.length() - 1] = n.to_string()
  if ts.length() >= 2 {
    let m = ts.length() - 2
    if ts[m].has_prefix("_") &&
      ctx.declarations.get(ts[m]) is Some(uri) &&
      uri.has_prefix("https://gedcom.io/terms/v7/month-") {
      ts[m] = uri[33:].to_owned()
    }
  }
  Some(cal + " " + ts.join(" ") + (if epoch == "" { "" } else { " " + epoch }))
}

///|
fn valid_date_payload(s : String, kind : String, ctx : SchemaContext) -> Bool {
  if s == "" {
    return kind != "type-Date#exact"
  }
  if kind == "type-Date#exact" {
    let ts = s.split(" ").to_array()
    if ts.length() != 3 ||
      !ascii_digits(ts[0].to_owned()) ||
      !ascii_digits(ts[2].to_owned()) {
      return false
    }
    if ![
        "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV",
        "DEC",
      ].contains(ts[1].to_owned()) {
      return false
    }
  }
  let mut points = [s]
  let mut period = false
  if s.has_prefix("FROM ") {
    period = true
    points = s[5:].split(" TO ").map(fn(x) { x.to_owned() }).to_array()
    if points.length() > 2 {
      return false
    }
  } else if s.has_prefix("TO ") {
    period = true
    points = [s[3:].to_owned()]
  } else if s.has_prefix("BET ") {
    points = s[4:].split(" AND ").map(fn(x) { x.to_owned() }).to_array()
    if points.length() != 2 {
      return false
    }
  } else {
    for prefix in ["BEF ", "AFT ", "ABT ", "CAL ", "EST "] {
      if s.has_prefix(prefix) {
        points = [s[prefix.length():].to_owned()]
        break
      }
    }
  }
  if kind == "type-Date#period" && !period {
    return false
  }
  for point in points {
    guard normalized_date_point(point, ctx) is Some(p) else { return false }
    let valid = try {
      parse_point(p) |> ignore
      true
    } catch {
      _ => false
    }
    if !valid {
      return false
    }
  }
  true
}
