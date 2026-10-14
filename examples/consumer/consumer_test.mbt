///|
test "external module queries a family and preserves its interchange payload" {
  let text = "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @P1@ INDI\n1 NAME 梅 /周/\n1 FAMS @F1@\n0 @C1@ INDI\n1 NAME 君 /周/\n1 FAMC @F1@\n0 @F1@ FAM\n1 WIFE @P1@\n1 CHIL @C1@\n0 TRLR\n"
  assert_eq(@genealogy-consumer-example.parent_names(text, "C1"), ["梅 /周/"])
  assert_true(@genealogy-consumer-example.round_trip(text))
}

///|
test "returned arrays cannot mutate opaque Document and Parser state" {
  let doc = @ged.parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @P1@ INDI\n1 NAME A\n0 TRLR\n",
  )
  doc.nodes().clear()
  doc.record_indices().clear()
  assert_eq(@ged.people(doc).length(), 1)
  assert_true(!@ged.has_errors(@ged.audit(doc)))
}
