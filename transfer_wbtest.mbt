///|
test "identifier remap rewrites references without changing text or source document" {
  let source = parse(sample())
  let moved = remap_ids(source, Map([("I1", "P1"), ("F1", "HOUSE1")]))
  assert_eq(person(moved, "P1").display_name(), "An /Li/")
  assert_eq(family(moved, "HOUSE1").husband, Some("P1"))
  assert_eq(person(moved, "I3").child_families, ["HOUSE1"])
  assert_eq(source.lookup("P1"), None)
  assert_eq(full_audit(moved).length(), 0)
  assert_true(equivalent(moved, parse(serialize(moved))))
}

///|
test "remap refuses collisions unknown IDs invalid IDs and allows simultaneous swaps" {
  let doc = parse(sample())
  for
    mapping in [
      Map([("I1", "I2")]),
      Map([("MISSING", "P")]),
      Map([("I1", "VOID")]),
      Map([("I1", "with space")]),
    ] {
    assert_true(
      try {
        remap_ids(doc, mapping) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  let swapped = remap_ids(doc, Map([("I1", "I2"), ("I2", "I1")]))
  assert_eq(family(swapped, "F1").husband, Some("I2"))
  assert_eq(family(swapped, "F1").wife, Some("I1"))
}

///|
test "record extraction follows citations and families and excludes disconnected records" {
  let text = sample().replace(
    old="0 TRLR",
    new="0 @I9@ INDI\n1 NAME Disconnected\n0 TRLR",
  )
  let doc = parse(text)
  let selected = extract_records(doc, ["I3"])
  assert_eq(people(selected.document).length(), 3)
  assert_true(!selected.included_ids.contains("I9"))
  assert_true(selected.included_ids.contains("I1"))
  assert_eq(full_audit(selected.document).length(), 0)
  assert_true(
    try {
      extract_records(doc, ["I3"], max_records=3) |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      extract_records(doc, ["NOT_FOUND"]) |> ignore
      false
    } catch {
      _ => true
    },
  )
}
