///|
test "byte stream counts decoded units as well as raw byte bounds" {
  let text = "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 TRLR\n"
  let limits = Limits::new(max_total_units=text.length())
  let parser = ByteParser::new(limits~)
  parser.feed(@utf8.encode(text))
  assert_eq(parser.finish().length(), 4)
  let smaller = Limits::new(max_total_units=text.length() - 1)
  let bad = ByteParser::new(limits=smaller)
  assert_true(
    try {
      bad.feed(@utf8.encode(text))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "large continuation payload assembles once and remains semantically stable" {
  let out = StringBuilder()
  out.write_string("0 HEAD\n1 NOTE start\n")
  for i = 0; i < 10000; i = i + 1 {
    out.write_string("2 CONT x\n")
  }
  out.write_string("0 TRLR\n")
  let doc = parse(out.to_string())
  let note = doc.nodes()[1].payload.text().unwrap()
  assert_eq(note.length(), 20005)
  assert_true(equivalent(doc, parse(serialize(doc))))
}

///|
test "anonymous family records still define relationships without invented ids" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @P1@ INDI\n1 NAME Parent\n0 @C1@ INDI\n1 NAME Child\n0 FAM\n1 HUSB @P1@\n1 CHIL @C1@\n0 TRLR\n",
  )
  let edge = graph(doc).shortest_path("C1", "P1").unwrap()[0]
  assert_eq(edge.relation, Parent)
  assert_eq(edge.family, None)
}

///|
test "wide family graphs retain all sibling links without repeated adjacency scans" {
  let text = StringBuilder()
  text.write_string(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @P@ INDI\n1 NAME Parent\n1 FAMS @F@\n",
  )
  for i = 0; i < 5000; i = i + 1 {
    text.write_string(
      "0 @C" + i.to_string() + "@ INDI\n1 NAME Child\n1 FAMC @F@\n",
    )
  }
  text.write_string("0 @F@ FAM\n1 HUSB @P@\n")
  for i = 0; i < 5000; i = i + 1 {
    text.write_string("1 CHIL @C" + i.to_string() + "@\n")
  }
  text.write_string("0 TRLR\n")
  let g = graph(parse(text.to_string()))
  assert_eq(g.neighbors("P").length(), 5000)
  assert_eq(g.descendants("P").length(), 5000)
}
