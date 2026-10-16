///|
test "shared note and submitter records are not pointer-valued structures" {
  let text = "0 HEAD\n1 GEDC\n2 VERS 7.0\n1 SUBM @U1@\n0 @U1@ SUBM\n1 NAME Synthetic contributor\n0 @N1@ SNOTE Shared Chinese 中文\n1 CONT Second line\n0 @I1@ INDI\n1 NAME A /Example/\n1 SNOTE @N1@\n0 TRLR\n"
  let doc = parse(text)
  assert_true(!has_errors(full_audit(doc)))
  assert_true(equivalent(doc, parse(serialize(doc))))
}

///|
test "family event spouse age structures do not require individual pointers" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME A /Example/\n1 FAMS @F1@\n0 @I2@ INDI\n1 NAME B /Example/\n1 FAMS @F1@\n0 @F1@ FAM\n1 HUSB @I1@\n1 WIFE @I2@\n1 MARR\n2 DATE 1900\n2 HUSB\n3 AGE 25y\n2 WIFE\n3 AGE 23y\n0 TRLR\n",
  )
  assert_true(!has_errors(full_audit(doc)))
  assert_eq(graph(doc).neighbors("I1").length(), 1)
  assert_true(equivalent(doc, parse(serialize(doc))))
}

///|
test "extension-defined standard-looking tags keep their own semantics" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n1 SCHMA\n2 TAG _CATALOG urn:moonged:catalog\n0 @X1@ _CATALOG Catalog\n1 FAMC shelf A\n1 DATE not a calendar date\n1 NOTE Reference text\n2 SOUR not a source pointer\n0 TRLR\n",
  )
  assert_true(!has_errors(full_audit(doc)))
  assert_true(equivalent(doc, parse(serialize(doc))))
}

///|
test "extension scope does not suppress real standard pointer errors" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n1 SCHMA\n2 TAG _CATALOG urn:moonged:catalog\n0 @I1@ INDI\n1 _CATALOG x\n2 FAMC shelf A\n1 FAMC not a pointer\n0 TRLR\n",
  )
  assert_eq(
    full_audit(doc).filter(fn(d) { d.code == "pointer-payload" }).length(),
    1,
  )
}

///|
test "BOM and all output line endings preserve the document and writer idempotence" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME 中文 😀\n0 TRLR\n",
  )
  for eol in ["\n", "\r\n", "\r"] {
    for bom in [false, true] {
      let text = serialize(doc, line_ending=eol, bom~)
      assert_eq(text.has_prefix("\u{FEFF}"), bom)
      let bytes = serialize_bytes(doc, line_ending=eol, bom~)
      assert_true(equivalent(doc, parse_bytes(bytes)))
      assert_eq(serialize(parse(text), line_ending=eol, bom~), text)
    }
  }
}

///|
test "normalization golden preserves spaces combining marks empty lines and literal at signs" {
  let input = "\u{FEFF}0 HEAD\r\n1 GEDC\r\n2 VERS 7.0\r\n0 @I1@ INDI\r\n1 NAME 中文 e\u{301} 😀\r\n1 NOTE   leading and trailing  \r\n2 CONT\r\n2 CONT @@I1@ is text\r\n2 CONT \tend  \r\n1 ASSO @VOID@\r\n2 ROLE WITN\r\n0 TRLR"
  let expected = "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME 中文 e\u{301} 😀\n1 NOTE   leading and trailing  \n2 CONT\n2 CONT @@I1@ is text\n2 CONT \tend  \n1 ASSO @VOID@\n2 ROLE WITN\n0 TRLR\n"
  assert_eq(serialize(parse(input)), expected)
  assert_true(equivalent(parse(input), parse(expected)))
}

///|
test "identifier remapping changes tokens while literal text and disconnected records survive" {
  let source = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME A /Synthetic/\n1 ASSO @I2@\n2 ROLE WITN\n1 NOTE @@I1@ remains literal\n0 @I2@ INDI\n1 NAME B /Synthetic/\n0 @I9@ INDI\n1 NAME Disconnected\n0 TRLR\n",
  )
  let moved = remap_ids(source, Map([("I1", "P1"), ("I2", "P2")]))
  let output = serialize(moved)
  assert_true(output.contains("0 @P1@ INDI\n"))
  assert_true(output.contains("1 ASSO @P2@\n"))
  assert_true(output.contains("1 NOTE @@I1@ remains literal\n"))
  assert_true(output.contains("0 @I9@ INDI\n"))
  assert_true(source.lookup("I1") != None)
  let extracted = extract_records(moved, ["P1"])
  assert_eq(extracted.included_ids, ["P1", "P2"])
  assert_true(extracted.document.lookup("I9") == None)
  assert_true(equivalent(moved, parse(output)))
}
