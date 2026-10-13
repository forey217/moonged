///|
test "Gregorian and Julian leap days differ and cross-calendar days compare" {
  assert_true(
    try {
      parse_date("29 FEB 1900") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_eq(parse_date("JULIAN 29 FEB 1900").first.unwrap().day, Some(29))
  assert_eq(parse_date("1 JAN 2000").window().earliest, Some(2451545L))
  assert_eq(parse_date("JULIAN 19 DEC 1999").window().earliest, Some(2451545L))
  assert_eq(parse_date("29 FEB 2000").first.unwrap().day, Some(29))
}

///|
test "partial approximate and unbounded dates are never assigned a guessed birthday" {
  assert_true(certainly_before(parse_date("1900"), parse_date("1901")))
  assert_true(!certainly_before(parse_date("1900"), parse_date("1 JAN 1900")))
  assert_eq(parse_date("ABT 1900").window().earliest, None)
  assert_eq(parse_date("EST 1900").window().latest, None)
  assert_true(!certainly_before(parse_date("ABT 1800"), parse_date("1900")))
  assert_eq(parse_date("BEF 1900").window().earliest, None)
  assert_eq(parse_date("AFT 1900").window().latest, None)
  assert_true(parse_date("TO 1900").first is None)
}

///|
test "BCE transitions and period ordering are handled without year zero input" {
  let last = parse_date("31 DEC 1 BCE").window().latest.unwrap()
  let first = parse_date("1 JAN 1").window().earliest.unwrap()
  assert_eq(first - last, 1L)
  assert_true(
    try {
      parse_date("0") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      parse_date("BET 2000 AND 1900") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      parse_date("FROM 2000 TO 1900") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_eq(parse_date("BET 1900 AND 1901").qualifier, Between)
}

///|
test "date audit reports definite chronology conflict but preserves unsupported calendars" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME A\n1 BIRT\n2 DATE 2000\n1 DEAT\n2 DATE 1900\n1 EVEN\n2 DATE HEBREW 1 TSH 5700\n0 TRLR\n",
  )
  let issues = audit_dates(doc)
  assert_true(issues.any(fn(d) { d.code == "birth-after-death" }))
  assert_true(
    issues.any(fn(d) {
      d.code == "unsupported-calendar" && d.severity == Warning
    }),
  )
  assert_true(serialize(doc).contains("HEBREW 1 TSH 5700"))
}
