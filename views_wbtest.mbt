///|
test "typed person and family views preserve preference order and ids" {
  let doc = parse(sample())
  assert_eq(people(doc).length(), 3)
  assert_eq(families(doc).length(), 1)
  assert_eq(person(doc, "I1").display_name(), "An /Li/")
  assert_eq(person(doc, "I3").child_families, ["F1"])
  assert_eq(family(doc, "F1").children, ["I3"])
  assert_eq(find_people(doc, "LI").length(), 2)
}

///|
test "events retain exact dates places notes and source references" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME 周 /明/\n1 BIRT\n2 DATE ABT 1900\n2 PLAC 苏州\n2 NOTE oral account\n3 CONT unverified\n2 SOUR @S1@\n0 @S1@ SOUR\n1 TITL Catalog\n0 TRLR\n",
  )
  let p = person(doc, "I1")
  let e = events(doc, p.record)[0]
  assert_eq(e.date, Some("ABT 1900"))
  assert_eq(e.place, Some("苏州"))
  assert_eq(e.notes, ["oral account\nunverified"])
  assert_eq(e.sources, ["S1"])
  assert_eq(find_people(doc, "周").length(), 1)
}

///|
test "typed lookups refuse duplicates missing ids and wrong record types" {
  let doc = parse(sample())
  assert_true(
    try {
      person(doc, "F1") |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      person(doc, "I99") |> ignore
      false
    } catch {
      _ => true
    },
  )
  let duplicate = parse("0 @I1@ INDI\n1 NAME A\n0 @I1@ INDI\n1 NAME B\n")
  assert_true(
    try {
      person(duplicate, "I1") |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "edits to typed view arrays cannot change a document" {
  let doc = parse(sample())
  person(doc, "I1").names.clear()
  family(doc, "F1").children.clear()
  assert_eq(person(doc, "I1").names, ["An /Li/"])
  assert_eq(family(doc, "F1").children, ["I3"])
}
