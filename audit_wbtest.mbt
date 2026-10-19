///|
fn sample() -> String {
  "0 HEAD\n1 SOUR MoonGED\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME An /Li/\n1 FAMS @F1@\n0 @I2@ INDI\n1 NAME Mei /Zhou/\n1 FAMS @F1@\n0 @I3@ INDI\n1 NAME Jun /Li/\n1 FAMC @F1@\n0 @F1@ FAM\n1 HUSB @I1@\n1 WIFE @I2@\n1 CHIL @I3@\n0 TRLR\n"
}

///|
test "complete sample passes selected interchange audit" {
  assert_eq(audit(parse(sample())).length(), 0)
}

///|
test "extension declarations accept URNs without remote resolution" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n1 SCHMA\n2 TAG _COLOR urn:example:color\n0 @I1@ INDI\n1 _COLOR teal\n0 TRLR\n",
  )
  assert_true(!has_errors(audit(doc)))
  assert_true(audit(doc).any(fn(d) { d.code == "extension-unassessed" }))
  assert_true(equivalent(doc, parse(serialize(doc))))
}

///|
test "duplicate IDs and dangling pointers retain actionable line numbers" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME A\n0 @I1@ INDI\n1 NAME B\n1 FAMC @F9@\n0 TRLR\n",
  )
  let issues = audit(doc)
  assert_true(
    issues.any(fn(d) {
      d.code == "duplicate-id" && d.line == 6 && d.related_line == Some(4)
    }),
  )
  assert_true(issues.any(fn(d) { d.code == "dangling-pointer" && d.line == 8 }))
  assert_true(has_errors(issues))
}

///|
test "wrong pointer type and repeated family links are errors" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @F1@ FAM\n1 HUSB @F1@\n1 HUSB @F1@\n0 TRLR\n",
  )
  let issues = audit(doc)
  for code in ["pointer-type", "family-cardinality", "duplicate-family-link"] {
    assert_true(issues.any(fn(d) { d.code == code }))
  }
}

///|
test "legacy files are readable structurally but unsupported in audit" {
  let issues = audit(parse("0 HEAD\n1 GEDC\n2 VERS 5.5.1\n0 TRLR\n"))
  assert_true(issues.any(fn(d) { d.code == "unsupported-version" }))
}

///|
test "empty standard structures and invalid trailer are detected" {
  let issues = audit(
    parse(
      "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n0 TRLR\n1 NOTE unexpected\n",
    ),
  )
  assert_true(issues.any(fn(d) { d.code == "empty-structure" }))
  assert_true(issues.any(fn(d) { d.code == "trailer-order" }))
}

///|
test "extension schema warnings do not strip data or masquerade as full validation" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 _COLOR teal\n0 TRLR\n",
  )
  let issues = audit(doc)
  assert_true(
    issues.any(fn(d) {
      d.code == "undeclared-extension" && d.severity == Warning
    }),
  )
  assert_true(!has_errors(issues))
  assert_true(serialize(doc).contains("_COLOR teal"))
}
