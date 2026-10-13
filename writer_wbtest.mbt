///|
test "canonical writer preserves multiline whitespace escaped text and void pointers" {
  let source = "0 HEAD\r1 GEDC\r2 VERS 7.0\r0 @I_1@ INDI\r1 NAME 安 /李/\r1 NOTE\r2 CONT @@at@  \r2 CONT\r2 CONT \tspace\r2 CONT  \r1 FAMC @VOID@\r0 TRLR\r"
  let doc = parse(source)
  for eol in ["\n", "\r\n", "\r"] {
    let output = serialize(doc, line_ending=eol)
    assert_true(equivalent(doc, parse(output)))
    assert_eq(serialize(parse(output), line_ending=eol), output)
  }
  assert_true(
    try {
      serialize(doc, line_ending="bad") |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "byte parser preserves every possible split of UTF8 BOM Chinese emoji and CRLF" {
  let bytes = @utf8.encode(
    "0 HEAD\r\n1 NOTE 中文 😀\r\n0 TRLR\r\n",
    bom=true,
  )
  let expected = parse_bytes(bytes)
  for split = 0; split <= bytes.length(); split = split + 1 {
    let parser = ByteParser::new()
    parser.feed(bytes[:split])
    parser.feed(bytes[split:])
    assert_true(equivalent(parser.finish(), expected))
  }
  let single = ByteParser::new()
  for i = 0; i < bytes.length(); i = i + 1 {
    single.feed(bytes[i:i + 1])
  }
  assert_true(equivalent(single.finish(), expected))
}

///|
test "byte parser rejects malformed UTF8 and cannot resume after failure" {
  let parser = ByteParser::new()
  assert_true(
    try {
      parser.feed(b"0 NOTE \xC0\x80\n")
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      parser.feed(b"0 TRLR\n")
      false
    } catch {
      _ => true
    },
  )
  let short = ByteParser::new()
  short.feed(b"0 NOTE \xE4\xB8")
  assert_true(
    try {
      short.finish() |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "unknown extension content survives serialization without schema stripping" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n1 SCHMA\n2 TAG _COLOR https://example.org/color\n0 @I1@ INDI\n1 NAME M /N/\n1 _COLOR 海蓝色\n2 _SOURCE catalog\n0 TRLR\n",
  )
  let output = serialize(doc)
  assert_true(output.contains("_COLOR 海蓝色"))
  assert_true(equivalent(doc, parse(output)))
}
