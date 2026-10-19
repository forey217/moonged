///|
pub(all) enum Calendar {
  Gregorian
  Julian
  Hebrew
  FrenchRepublican
  Extension(String)
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
  month_tag : String?
  epoch : String?
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
  if calendar == Hebrew {
    let length = hebrew_new_year(year + 1) - hebrew_new_year(year)
    return match month {
      1 | 5 | 6 | 8 | 10 | 12 => 30
      2 => if length % 10L == 5L { 30 } else { 29 }
      3 => if length % 10L == 3L { 29 } else { 30 }
      _ => 29
    }
  }
  if calendar == FrenchRepublican {
    if month < 13 {
      return 30
    }
    return if [3, 7, 11].contains(year) || year > 14 { 6 } else { 5 }
  }
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
  } else if tokens.get(0) == Some("HEBREW") || tokens.get(0) == Some("FRENCH_R") {
    calendar = if tokens[0] == "HEBREW" { Hebrew } else { FrenchRepublican }
    tokens.remove(0) |> ignore
  } else if tokens.get(0) is Some(t) && t.has_prefix("_") {
    if !valid_tag(t) {
      raise Query("invalid extension calendar")
    }
    calendar = Extension(t)
    tokens.remove(0) |> ignore
  }
  let last = tokens.get(tokens.length() - 1).unwrap_or("")
  let epoch = if last == "BCE" || last.has_prefix("_") {
    Some(last)
  } else {
    None
  }
  let bce = epoch == Some("BCE")
  if epoch != None {
    tokens.remove(tokens.length() - 1) |> ignore
  }
  if (calendar == Gregorian || calendar == Julian) && epoch != None && !bce {
    raise Query("invalid epoch for Gregorian/Julian calendar")
  }
  if (calendar == Hebrew || calendar == FrenchRepublican) && epoch != None {
    raise Query("calendar does not permit an epoch")
  }
  if calendar is Extension(_) &&
    epoch is Some(e) &&
    (!e.has_prefix("_") || !valid_tag(e)) {
    raise Query("extension epoch requires extension tag")
  }
  if tokens.length() < 1 || tokens.length() > 3 {
    raise Query("expected year, month year, or day month year")
  }
  let year = date_number(tokens[tokens.length() - 1])
  let month = if tokens.length() >= 2 {
    let name = tokens[tokens.length() - 2]
    let names = match calendar {
      Hebrew =>
        [
          "TSH", "CSH", "KSL", "TVT", "SHV", "ADR", "ADS", "NSN", "IYR", "SVN", "TMZ",
          "AAV", "ELL",
        ]
      FrenchRepublican =>
        [
          "VEND", "BRUM", "FRIM", "NIVO", "PLUV", "VENT", "GERM", "FLOR", "PRAI",
          "MESS", "THER", "FRUC", "COMP",
        ]
      Extension(_) => []
      _ =>
        [
          "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV",
          "DEC",
        ]
    }
    let mut n = 0
    for i, value in names {
      if name == value {
        n = i + 1
      }
    }
    if calendar is Extension(_) {
      if !name.has_prefix("_") || !valid_tag(name) {
        raise Query("extension calendar requires extension month tags")
      }
    } else if n == 0 {
      raise Query("invalid month for calendar")
    }
    // Common-year ADR is a documented legacy spelling of ADS (搂Appendix A).
    Some(if calendar == Hebrew && n == 6 && !hebrew_leap(year) { 7 } else { n })
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
    !(calendar is Extension(_)) &&
    d > month_days(astro_year, m, calendar) {
    raise Query("day is outside the calendar month")
  }
  {
    calendar,
    year,
    month,
    day,
    bce,
    month_tag: if tokens.length() >= 2 {
      Some(tokens[tokens.length() - 2])
    } else {
      None
    },
    epoch,
  }
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
  if point.calendar == Hebrew {
    let mut value = hebrew_new_year(point.year)
    for m = 1; m < month; m = m + 1 {
      if m != 6 || hebrew_leap(point.year) {
        value = value + month_days(point.year, m, Hebrew).to_int64()
      }
    }
    return value + day.to_int64() - 1L
  }
  if point.calendar == FrenchRepublican {
    let mut n = 0
    for y = 1; y < point.year; y = y + 1 {
      if [3, 7, 11].contains(y) {
        n = n + 1
      }
    }
    return 2375840L +
      365L * (point.year.to_int64() - 1L) +
      n.to_int64() +
      30L * (month.to_int64() - 1L) +
      day.to_int64() -
      1L
  }
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
  let last_month = point.month.unwrap_or(
    if point.calendar == Hebrew || point.calendar == FrenchRepublican {
      13
    } else {
      12
    },
  )
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
  if [self.first, self.second].any(fn(p) {
      match p {
        Some(p) =>
          p.calendar is Extension(_) ||
          (p.calendar == FrenchRepublican && p.year > 14)
        None => false
      }
    }) {
    return { earliest: None, latest: None, }
  }
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
fn hebrew_leap(year : Int32) -> Bool {
  (7 * year + 1) % 19 < 7
}

///|
// Molad and postponement rules in integer arithmetic; Julian day at civil noon.
fn hebrew_delay(year : Int32) -> Int64 {
  let y = year.to_int64()
  let months = (235L * y - 234L) / 19L
  let parts = 12084L + 13753L * months
  let day = 29L * months + parts / 25920L
  if 3L * (day + 1L) % 7L < 3L {
    day + 1L
  } else {
    day
  }
}

///|
fn hebrew_new_year(year : Int32) -> Int64 {
  let current = hebrew_delay(year)
  let adjust = if hebrew_delay(year + 1) - current == 356L {
    2L
  } else if current - hebrew_delay(year - 1) == 382L {
    1L
  } else {
    0L
  }
  347998L + current + adjust
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
  let ctx = schema_context(doc)
  for i, node in doc.nodes {
    let t = ctx.types[i].unwrap_or("?")
    let (kind, _) = standard_payloads.get_or_default(t, ("", []))
    if !kind.has_prefix("type-Date") {
      continue
    }
    let text = node.payload.text().unwrap_or("")
    if !check_payload(kind, [], node.payload, ctx) {
      out.push(
        diagnostic(
          "invalid-date",
          node.line,
          "date does not match its contextual GEDCOM date type",
        ),
      )
      continue
    }
    try parse_date(text) catch {
      Query(message) =>
        out.push(
          diagnostic(
            if message.has_prefix("reversed") {
              "date-order"
            } else {
              "date-arithmetic-limit"
            },
            node.line,
            message,
            severity=if message.has_prefix("reversed") {
              Error
            } else {
              Warning
            },
          ),
        )
      _ =>
        out.push(
          diagnostic(
            "date-arithmetic-limit",
            node.line,
            "valid date is outside arithmetic resource policy",
            severity=Warning,
          ),
        )
    } noraise {
      value =>
        if [value.first, value.second].any(fn(p) {
            match p {
              Some(p) =>
                p.calendar is Extension(_) ||
                (p.calendar == FrenchRepublican && p.year > 14)
              None => false
            }
          }) {
          out.push(
            diagnostic(
              "date-arithmetic-unassessed",
              node.line,
              "calendar value retained without inventing a proleptic conversion",
              severity=Warning,
            ),
          )
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
