///|
test "parser preserves Unicode, significant spaces, ids, null pointer and CONT" {
  let doc = parse(
    "\u{FEFF}0 HEAD\r\n1 GEDC\r\n2 VERS 7.0\r\n0 @I1@ INDI\r\n1 NAME 周 /树屹/\r\n1 NOTE @@hello@  \r\n2 CONT\r\n2 CONT   第二行\r\n1 FAMC @VOID@\r\n0 TRLR\r\n",
  )
  assert_eq(doc.length(), 8)
  assert_eq(doc.lookup("I1"), Some(3))
  assert_eq(doc.nodes[4].payload, Text("周 /树屹/"))
  assert_eq(doc.nodes[5].payload, Text("@hello@  \n\n  第二行"))
  assert_eq(doc.nodes[6].payload, Void)
  assert_eq(doc.children(3), [4, 5, 6])
  let nodes = doc.nodes()
  nodes.clear()
  assert_eq(doc.length(), 8)
}

///|
test "streaming accepts every Unicode boundary including split CRLF" {
  let text = "0 HEAD\r\n1 NOTE emoji 😀\r\n0 @1@ INDI\r\n1 NAME Mei /Zhou/\r\n0 TRLR"
  let expected = parse(text).nodes()
  for split = 0; split <= text.length(); split = split + 1 {
    if text.get_view(end=split) == None {
      continue
    }
    let parser = Parser::new()
    parser.feed(text[:split].to_owned())
    parser.feed(text[split:].to_owned())
    assert_eq(parser.finish().nodes(), expected)
  }
}

///|
fn reject_syntax(text : String) -> Unit raise {
  let bad = try {
    parse(text) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}

///|
test "reject illegal grammar and CONT placement" {
  for
    text in [
      "", "\n", " 0 HEAD\n", "00 HEAD\n", "0\n", "0  HEAD\n", "0 head\n", "0 _\n",
      "0 @VOID@ INDI\n", "0 @a@ INDI\n", "0 HEAD \n", "0 NOTE @text\n", "0 HEAD\n2 NOTE bad\n",
      "0 CONT bad\n", "0 HEAD\n1 NOTE ok\n2 SOUR @S1@\n2 CONT late\n", "0 HEAD\n1 NOTE ok\n2 CONT hi\n3 NOTE child\n",
      "0 HEAD\n1 NOTE @I1@\n2 CONT bad\n", "0 HEAD\n1 NOTE \u{7F}\n",
    ] {
    reject_syntax(text)
  }
}

///|
test "limits and closed parser have recoverable errors" {
  let limits = Limits::new(max_nodes=2)
  assert_true(
    try {
      parse("0 HEAD\n1 NOTE x\n0 TRLR\n", limits~) |> ignore
      false
    } catch {
      _ => true
    },
  )
  let parser = Parser::new()
  parser.feed("0 TRLR\n")
  parser.finish() |> ignore
  assert_true(
    try {
      parser.feed("0 TRLR\n")
      false
    } catch {
      _ => true
    },
  )
  let failed = Parser::new()
  assert_true(
    try {
      failed.feed("bad\n")
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      failed.finish() |> ignore
      false
    } catch {
      _ => true
    },
  )
}
