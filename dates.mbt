///|
pub(all) enum Calendar {
  Gregorian
  Julian
} derive(Eq, @debug.Debug)

///|
pub extend Calendar with Eq::{equal, not_equal}

///|
pub extend Calendar with @debug.Debug::{to_repr}

///|
pub(all) enum DateQualifier {
  Exact
  Before
  After
  Approximate
  Calculated
  Estimated
  Between
  Period
} derive(Eq, @debug.Debug)

///|
pub extend DateQualifier with Eq::{equal, not_equal}

///|
pub extend DateQualifier with @debug.Debug::{to_repr}

///|
pub struct DatePoint {
  calendar : Calendar
  year : Int32
  month : Int32?
  day : Int32?
  bce : Bool
}

///|
pub struct DateValue {
  qualifier : DateQualifier
  first : DatePoint?
  second : DatePoint?
}

///|
/// Inclusive Julian-day bounds. None is unbounded, never filled in by guessing.
pub struct DateWindow {
  earliest : Int64?
  latest : Int64?
}

///|
fn leap(year : Int32, calendar : Calendar) -> Bool {
  year % 4 == 0 && (calendar == Julian || year % 100 != 0 || year % 400 == 0)
}

///|
fn month_days(year : Int32, month : Int32, calendar : Calendar) -> Int32 {
  match month {
    2 => if leap(year, calendar) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
fn date_number(text : StringView) -> Int32 raise GedError {
  if text.is_empty() || !text.code_units().all(fn(c) { c >= 48 && c <= 57 }) {
    raise Query("date requires ASCII positive integers")
  }
  let n = @string.parse_int(text) catch {
    _ => raise Query("date number is out of range")
  }
  if n < 1 || n > 9999999 {
    raise Query("date number outside supported range 1..9999999")
  }
  n
}

///|
fn parse_point(input : String) -> DatePoint raise GedError {
  let tokens = input.split(" ").map(fn(s) { s.to_owned() }).to_array()
  if tokens.any(fn(s) { s.is_empty() }) {
    raise Query("date components require single spaces")
  }
  let mut calendar = Gregorian
  if tokens.get(0) == Some("GREGORIAN") || tokens.get(0) == Some("JULIAN") {
    calendar = if tokens[0] == "JULIAN" { Julian } else { Gregorian }
    tokens.remove(0) |> ignore
  } else if tokens.get(0) is Some(t) &&
    (t == "HEBREW" || t == "FRENCH_R" || t.has_prefix("_")) {
    raise Query("unsupported-calendar: preserved without date arithmetic")
  }
  let bce = tokens.get(tokens.length() - 1) == Some("BCE")
  if bce {
    tokens.remove(tokens.length() - 1) |> ignore
  }
  if tokens.length() < 1 || tokens.length() > 3 {
    raise Query("expected year, month year, or day month year")
  }
  let year = date_number(tokens[tokens.length() - 1])
  let month = if tokens.length() >= 2 {
    let name = tokens[tokens.length() - 2]
    let names = [
      "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV",
      "DEC",
    ]
    let mut n = 0
    for i, value in names {
      if name == value {
        n = i + 1
      }
    }
    if n == 0 {
      raise Query("invalid Gregorian/Julian month")
    }
    Some(n)
  } else {
    None
  }
  let day = if tokens.length() == 3 {
    Some(date_number(tokens[0]))
  } else {
    None
  }
  let astro_year = if bce { 1 - year } else { year }
  if day is Some(d) &&
    month is Some(m) &&
    d > month_days(astro_year, m, calendar) {
    raise Query("day is outside the calendar month")
  }
  { calendar, year, month, day, bce, }
}

///|
pub fn parse_date(text : String) -> DateValue raise GedError {
  if text == "" {
    return { qualifier: Exact, first: None, second: None, }
  }
  for
    (prefix, qualifier) in [
      ("BEF ", Before),
      ("AFT ", After),
      ("ABT ", Approximate),
      ("CAL ", Calculated),
      ("EST ", Estimated),
    ] {
    if text.has_prefix(prefix) {
      return {
        qualifier,
        first: Some(parse_point(text[prefix.length():].to_owned())),
        second: None,
      }
    }
  }
  if text.has_prefix("BET ") {
    let parts = text[4:].split(" AND ").map(fn(s) { s.to_owned() }).to_array()
    if parts.length() != 2 {
      raise Query("BET requires AND and two dates")
    }
    let date = {
      qualifier: Between,
      first: Some(parse_point(parts[0])),
      second: Some(parse_point(parts[1])),
    }
    let window = date.window()
    if window.earliest is Some(a) && window.latest is Some(b) && a > b {
      raise Query("reversed date range")
    }
    return date
  }
  if text.has_prefix("FROM ") {
    let parts = text[5:].split(" TO ").map(fn(s) { s.to_owned() }).to_array()
    if parts.length() > 2 {
      raise Query("FROM has more than one TO")
    }
    let second = if parts.length() == 2 {
      Some(parse_point(parts[1]))
    } else {
      None
    }
    let date = {
      qualifier: Period,
      first: Some(parse_point(parts[0])),
      second,
    }
    let window = date.window()
    if window.earliest is Some(a) && window.latest is Some(b) && a > b {
      raise Query("reversed date period")
    }
    return date
  }
  if text.has_prefix("TO ") {
    return {
      qualifier: Period,
      first: None,
      second: Some(parse_point(text[3:].to_owned())),
    }
  }
  { qualifier: Exact, first: Some(parse_point(text)), second: None, }
}

///|
fn floor_div(n : Int64, d : Int64) -> Int64 {
  let q = n / d
  if n % d < 0 {
    q - 1L
  } else {
    q
  }
}

///|
fn julian_day(point : DatePoint, month : Int32, day : Int32) -> Int64 {
  let year = if point.bce { 1 - point.year } else { point.year }
  let a = (14 - month) / 12
  let y = year.to_int64() + 4800L - a.to_int64()
  let m = (month + 12 * a - 3).to_int64()
  let base = day.to_int64() + (153L * m + 2L) / 5L + 365L * y + floor_div(y, 4L)
  if point.calendar == Gregorian {
    base - floor_div(y, 100L) + floor_div(y, 400L) - 32045L
  } else {
    base - 32083L
  }
}

///|
fn point_bounds(point : DatePoint) -> (Int64, Int64) {
  let first_month = point.month.unwrap_or(1)
  let last_month = point.month.unwrap_or(12)
  let astro_year = if point.bce { 1 - point.year } else { point.year }
  (
    julian_day(point, first_month, point.day.unwrap_or(1)),
    julian_day(
      point,
      last_month,
      point.day.unwrap_or(month_days(astro_year, last_month, point.calendar)),
    ),
  )
}

///|
pub fn DateValue::window(self : DateValue) -> DateWindow {
  let first = self.first.map(point_bounds)
  let second = self.second.map(point_bounds)
  match self.qualifier {
    Approximate | Estimated => { earliest: None, latest: None, }
    Before => { earliest: None, latest: first.map(fn(pair) { pair.1 }), }
    After => { earliest: first.map(fn(pair) { pair.0 }), latest: None, }
    Between | Period =>
      {
        earliest: first.map(fn(pair) { pair.0 }),
        latest: second.map(fn(pair) { pair.1 }),
      }
    Exact | Calculated =>
      {
        earliest: first.map(fn(pair) { pair.0 }),
        latest: first.map(fn(pair) { pair.1 }),
      }
  }
}

///|
/// Certain ordering only. Partial/approximate dates never become fabricated days.
pub fn certainly_before(a : DateValue, b : DateValue) -> Bool {
  match (a.window().latest, b.window().earliest) {
    (Some(x), Some(y)) => x < y
    _ => false
  }
}

///|
pub fn audit_dates(doc : Document) -> Array[Diagnostic] {
  let out = []
  let standard = standard_contexts(doc)
  for i, node in doc.nodes {
    if standard[i] && node.tag == "DATE" && node.payload is Text(text) {
      try parse_date(text) catch {
        Query(message) =>
          out.push(
            diagnostic(
              if message.has_prefix("unsupported-calendar") {
                "unsupported-calendar"
              } else {
                "invalid-date"
              },
              node.line,
              message,
              severity=if message.has_prefix("unsupported-calendar") {
                Warning
              } else {
                Error
              },
            ),
          )
        _ =>
          out.push(
            diagnostic("invalid-date", node.line, "date could not be parsed"),
          )
      } noraise {
        _ => ()
      }
    }
  }
  for p in people(doc) {
    let es = events(doc, p.record)
    let births = es.filter(fn(e) { e.tag == "BIRT" })
    let deaths = es.filter(fn(e) { e.tag == "DEAT" })
    if births.get(0) is Some(b) &&
      deaths.get(0) is Some(d) &&
      b.date is Some(bt) &&
      d.date is Some(dt) {
      try {
        if certainly_before(parse_date(dt), parse_date(bt)) {
          out.push(
            diagnostic(
              "birth-after-death",
              doc.nodes[b.node].line,
              "recorded birth range is certainly later than death range; review claims",
              severity=Warning,
              related_line=doc.nodes[d.node].line,
            ),
          )
        }
      } catch {
        _ => ()
      }
    }
  }
  out
}
