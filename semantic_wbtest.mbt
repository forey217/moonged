///|
fn semantic_doc(
  body : String,
  header~ : String = "",
) -> Document raise GedError {
  parse("0 HEAD\n1 GEDC\n2 VERS 7.0\n" + header + body + "0 TRLR\n")
}

///|
fn semantic_code(body : String, code : String) -> Bool raise GedError {
  full_audit(semantic_doc(body)).any(fn(d) {
    d.code == code && d.severity == Error
  })
}

///|
test "context and cardinality distinguish same tags across all standard record families" {
  for
    body in [
      "0 @I@ INDI\n1 HUSB @VOID@\n", "0 @F@ FAM\n1 SEX M\n", "0 @S@ SOUR\n1 NAME Wrong\n",
      "0 @R@ REPO\n1 CHIL @VOID@\n", "0 @U@ SUBM\n1 FAMC @VOID@\n", "0 @N@ SNOTE x\n1 SEX M\n",
      "0 @M@ OBJE\n1 FILE media/x\n2 FORM image/png\n1 BIRT Y\n",
    ] {
    assert_true(semantic_code(body, "structure-context"))
  }
  assert_true(
    semantic_code("0 @I@ INDI\n1 SEX M\n1 SEX F\n", "structure-cardinality"),
  )
  assert_true(
    semantic_code("0 @M@ OBJE\n1 TITL No file\n", "required-structure"),
  )
  assert_true(semantic_code("0 @I@ INDI\n1 EVEN x\n", "required-structure"))
  assert_true(semantic_code("0 @I@ INDI\n1 FACT x\n", "required-structure"))
  assert_true(semantic_code("0 @I@ INDI\n1 IDNO 123\n", "required-structure"))
  assert_true(
    semantic_code("0 @R@ REPO\n1 NOTE No name\n", "required-structure"),
  )
}

///|
test "contextual enumerations and integer payloads reject strings that only look plausible" {
  for
    body in [
      "0 @I@ INDI\n1 SEX MALE\n", "0 @I@ INDI\n1 RESN PRIVATE\n", "0 @I@ INDI\n1 ASSO @VOID@\n2 ROLE COUSIN\n",
      "0 @I@ INDI\n1 NAME A\n2 TYPE LEGAL\n", "0 @I@ INDI\n1 FAMC @VOID@\n2 PEDI GENETIC\n",
      "0 @I@ INDI\n1 NCHI -1\n", "0 @I@ INDI\n1 BIRT N\n",
    ] {
    assert_true(semantic_code(body, "payload-type"))
  }
  let good = semantic_doc(
    "0 @I@ INDI\n1 NAME A\n1 SEX X\n1 RESN CONFIDENTIAL, LOCKED\n1 NCHI 99999999999999999999999999\n1 ASSO @VOID@\n2 ROLE WITN\n",
  )
  assert_true(!has_errors(full_audit(good)))
}

///|
test "date type depends on structure including exact timestamps and source periods" {
  let ctx = schema_context(semantic_doc(""))
  for s in ["1 JAN 2026", "29 FEB 2000", "0001 JAN 02026"] {
    assert_true(valid_date_payload(s, "type-Date#exact", ctx))
  }
  for
    s in [
      "2026", "JAN 2026", "ABT 2026", "JULIAN 1 JAN 2026", "1 JAN 0", "29 FEB 1900",
    ] {
    assert_true(!valid_date_payload(s, "type-Date#exact", ctx))
  }
  for s in ["", "FROM 1900", "TO HEBREW 5784", "FROM JULIAN 1900 TO 2000"] {
    assert_true(valid_date_payload(s, "type-Date#period", ctx))
  }
  for s in ["1900", "BET 1900 AND 2000", "ABT 1900"] {
    assert_true(!valid_date_payload(s, "type-Date#period", ctx))
  }
  for
    s in [
      "HEBREW 30 CSH 5784", "HEBREW 30 KSL 5784", "FRENCH_R 6 COMP 2", "FRENCH_R 31 VEND 3",
      "JULIAN 30 FEB 1900", "0", "FROM 1 TO", "1 JAN 2 BCE BCE",
    ] {
    assert_true(!valid_date_payload(s, "type-Date", ctx))
  }
  for
    s in [
      "HEBREW 30 CSH 5783", "HEBREW 30 ADR 5784", "HEBREW 29 ADR 5783", "FRENCH_R 6 COMP 3",
      "FRENCH_R 5 COMP 2", "BET JULIAN 1 JAN 1900 AND 2000", "99999999999999999999999999999999999999999999",
    ] {
    assert_true(valid_date_payload(s, "type-Date", ctx))
  }
  assert_true(
    semantic_code("0 @I@ INDI\n1 NAME A\n1 CHAN\n2 DATE 1900\n", "payload-type"),
  )
}

///|
test "Hebrew and French dates compare to independently known Gregorian anchors" {
  for
    (native, gregorian) in [
      ("HEBREW 1 TSH 5784", "16 SEP 2023"),
      ("HEBREW 15 NSN 5784", "23 APR 2024"),
      ("HEBREW 1 TSH 1", "7 SEP 3761 BCE"),
      ("FRENCH_R 1 VEND 1", "22 SEP 1792"),
      ("FRENCH_R 6 COMP 3", "22 SEP 1795"),
    ] {
    assert_eq(
      parse_date(native).window().earliest,
      parse_date(gregorian).window().earliest,
    )
  }
  assert_eq(
    parse_date("HEBREW 29 ADR 5783").window().earliest,
    parse_date("HEBREW 29 ADS 5783").window().earliest,
  )
  assert_eq(parse_date("FRENCH_R 15").window().earliest, None)
  assert_eq(parse_date("_UNKNOWN 1 _MONTH 123").window().latest, None)
}

///|
test "age time language media coordinate and file-path ABNF boundaries" {
  for s in ["", "0y", ">8d", "<1y 30m 8w 400d"] {
    assert_true(valid_age(s))
  }
  for s in ["<", "1Y", "1d 1y", "1y  2m", "1y ", "1.5y"] {
    assert_true(!valid_age(s))
  }
  for s in ["2:50", "02:50:59.123Z", "23:59:00"] {
    assert_true(valid_time(s))
  }
  for s in ["24:00", "23:59:60", "1:2", "12:30.1", "12:30:00.", "12:30+08:00"] {
    assert_true(!valid_time(s))
  }
  for
    s in [
      "en", "zh-Hant-CN", "sr-Latn-RS", "de-CH-1901", "en-US-u-ca-gregory-x-test",
      "i-klingon", "x-project",
    ] {
    assert_true(valid_language(s))
  }
  for
    s in [
      "English_US", "a", "en-", "en-u", "en-1901-1901", "en-u-ca-u-nu", "en-x", "en-abcdefghi",
    ] {
    assert_true(!valid_language(s))
  }
  for
    s in [
      "text/plain", "text/html; charset=utf-8", "text/plain ; charset=\"utf-8\"",
      "image/png",
    ] {
    assert_true(valid_media_type(s))
  }
  for
    s in [
      "text", "text/", "text/plain; charset=", "text/plain; charset=\"unclosed",
      "text/plain\n",
    ] {
    assert_true(!valid_media_type(s))
  }
  for s in ["N90", "S00.001", "n18.5"] {
    assert_true(valid_coordinate(s, true))
  }
  for s in ["N90.1", "N091", "N-1", "N1.", "E10"] {
    assert_true(!valid_coordinate(s, true))
  }
  for s in ["E180", "W000.1", "e168.150944"] {
    assert_true(valid_coordinate(s, false))
  }
  for s in ["E180.1", "W181", "E0000", "W-2"] {
    assert_true(!valid_coordinate(s, false))
  }
  for
    s in [
      "media/中文.jpg", "media/%C3%89.jpg", "https://example.org/a.jpg?x=1#p",
      "file:///C:/scan.jpg", "media/%20scan.jpg",
    ] {
    assert_true(valid_file_path(s))
  }
  for
    s in [
      "../scan.jpg", "media/%2e%2e/scan.jpg", "/scan.jpg", "C:\\scan.jpg", "media/scan.jpg?x",
      "media/scan.jpg#p", "media/%5Cscan.jpg", "media/%00scan.jpg", "https://", "data:x",
    ] {
    assert_true(!valid_file_path(s))
  }
}

///|
test "URI reference accepts RFC3986 components without requiring an absolute scheme" {
  for
    s in [
      "urn:example:thing", "https://example.org/a%20b?q=1#part", "../relative", "#fragment",
      "http://[2001:db8::1]/", "https://user:pass@example.org:443/x",
    ] {
    assert_true(valid_uri_reference(s))
  }
  for
    s in [
      "https://a/%GG", "https://a/a b", "http://[:::]/", "http://[12345::]/", "1bad:thing",
      "https://a#one#two", "urn:中文",
    ] {
    assert_true(!valid_uri_reference(s))
  }
}

///|
test "HTML note projection follows GEDCOM MIME rules without active markup" {
  assert_eq(
    html_to_plain("<P>A  中文 😀<b>B</b></P><br/>&lt;x&gt; &amp;lt;"),
    "\nA 中文 😀B\n\n<x> &lt;",
  )
  assert_true(
    semantic_code(
      "0 INDI\n1 NAME A\n1 NOTE a&nbsp;b\n2 MIME text/html\n", "html-entity",
    ),
  )
  assert_true(
    semantic_code(
      "0 INDI\n1 NAME A\n1 NOTE x\n2 MIME image/png\n", "note-mime-kind",
    ),
  )
  assert_eq(
    media_identity("Text/Plain ; Charset=\"UTF-8\"; a=one"),
    media_identity("text/plain;a=one;charset=utf-8"),
  )
  assert_true(
    media_identity("multipart/mixed; boundary=Ab") !=
    media_identity("multipart/mixed; boundary=ab"),
  )
}

///|
test "family membership requires back pointers without inferring gender or genetic parenthood" {
  assert_true(
    semantic_code(
      "0 @I@ INDI\n1 NAME A\n0 @F@ FAM\n1 HUSB @I@\n", "required-reciprocal-link",
    ),
  )
  let good = semantic_doc(
    "0 @I@ INDI\n1 NAME A\n1 SEX F\n1 FAMS @F@\n0 @C@ INDI\n1 NAME C\n1 FAMC @F@\n2 PEDI ADOPTED\n0 @F@ FAM\n1 HUSB @I@\n1 CHIL @C@\n",
  )
  assert_true(!has_errors(full_audit(good)))
}

///|
test "nonlocal source cycles and translation inheritance have precise diagnostics" {
  assert_true(
    semantic_code(
      "0 @S@ SOUR\n1 TITL Source\n1 SNOTE @N@\n0 @N@ SNOTE Note\n1 SOUR @S@\n", "source-reference-cycle",
    ),
  )
  assert_true(
    semantic_code(
      "0 @S@ SOUR\n1 TITL Source\n1 OBJE @M@\n0 @M@ OBJE\n1 FILE media/a.png\n2 FORM image/png\n1 SOUR @S@\n",
      "source-reference-cycle",
    ),
  )
  assert_true(
    semantic_code(
      "0 @I@ INDI\n1 NAME A\n1 NOTE a\n2 TRAN b\n", "translation-format",
    ),
  )
  assert_true(
    semantic_code(
      "0 @I@ INDI\n1 NAME A\n1 NOTE a\n2 LANG en\n2 TRAN b\n3 LANG en\n", "translation-distinct",
    ),
  )
  assert_true(
    semantic_code(
      "0 @I@ INDI\n1 NAME A\n1 NOTE a\n2 LANG en\n2 TRAN b\n3 LANG fr\n2 TRAN c\n3 LANG fr\n",
      "translation-duplicate",
    ),
  )
  let good = semantic_doc(
    "0 @I@ INDI\n1 NAME A\n1 NOTE <b>a</b>\n2 LANG en\n2 MIME text/html\n2 TRAN a\n3 MIME text/plain\n2 TRAN <b>b</b>\n3 LANG fr\n",
  )
  assert_true(!has_errors(full_audit(good)))
}

///|
test "relocated standards validate their true types while opaque extensions stay unassessed" {
  let h = "1 SCHMA\n2 TAG _DATE https://gedcom.io/terms/v7/DATE\n2 TAG _CAL https://gedcom.io/terms/v7/cal-HEBREW\n2 TAG _TSH https://gedcom.io/terms/v7/month-TSH\n"
  let good = semantic_doc(
    "0 @I@ INDI\n1 NAME A\n2 _DATE FROM _CAL 1 _TSH 5784 TO 2024\n",
    header=h,
  )
  assert_true(!has_errors(full_audit(good)))
  let bad = semantic_doc("0 @I@ INDI\n1 BIRT\n2 _DATE 2024\n", header=h)
  assert_true(full_audit(bad).any(fn(d) { d.code == "relocated-context" }))
  let bad2 = semantic_doc("0 @I@ INDI\n1 NAME A\n2 _DATE nonsense\n", header=h)
  assert_true(has_errors(full_audit(bad2)))
}
