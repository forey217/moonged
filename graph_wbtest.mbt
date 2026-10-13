///|
test "parents descendants and shortest paths use explicit family links" {
  let g = graph(parse(sample()))
  assert_eq(g.ancestors("I3").map(fn(r) { r.person }), ["I1", "I2"])
  assert_eq(g.descendants("I1").map(fn(r) { r.person }), ["I3"])
  let path = g.shortest_path("I1", "I2").unwrap()
  assert_eq(path.length(), 1)
  assert_eq(path[0].relation, Partner)
  assert_eq(path[0].family, Some("F1"))
  assert_eq(g.shortest_path("I1", "I1").unwrap().length(), 0)
  assert_eq(g.shortest_path("I1", "I3", max_depth=0), None)
  assert_eq(audit_relationships(parse(sample())).length(), 0)
}

///|
test "graph traversal is bounded and does not return origin through a cycle" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME A\n0 @I2@ INDI\n1 NAME B\n0 @F1@ FAM\n1 HUSB @I1@\n1 CHIL @I2@\n0 @F2@ FAM\n1 WIFE @I2@\n1 CHIL @I1@\n0 TRLR\n",
  )
  let g = graph(doc)
  assert_eq(g.ancestors("I1").map(fn(r) { r.person }), ["I2"])
  assert_true(
    audit_relationships(doc).any(fn(d) { d.code == "ancestry-cycle" }),
  )
  assert_true(
    try {
      g.ancestors("I1", max_depth=-1) |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "adoption qualifier is retained rather than treated as genetic parenthood" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME A\n1 FAMS @F1@\n0 @I2@ INDI\n1 NAME B\n1 FAMC @F1@\n2 PEDI ADOPTED\n0 @F1@ FAM\n1 HUSB @I1@\n1 CHIL @I2@\n0 TRLR\n",
  )
  let edge = graph(doc).shortest_path("I2", "I1").unwrap()[0]
  assert_eq(edge.pedigree, Some("ADOPTED"))
}

///|
test "disconnected and unidentified records do not create inferred links" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME Same /Name/\n0 @I2@ INDI\n1 NAME Same /Name/\n0 INDI\n1 NAME Unreferenced\n0 TRLR\n",
  )
  let g = graph(doc)
  assert_eq(g.shortest_path("I1", "I2"), None)
  assert_eq(g.neighbors("I1").length(), 0)
  assert_true(
    try {
      g.neighbors("Unknown") |> ignore
      false
    } catch {
      _ => true
    },
  )
}
