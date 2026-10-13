///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let text = "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @P@ INDI\n1 NAME Parent\n1 FAMS @F@\n0 @C@ INDI\n1 NAME Child\n1 FAMC @F@\n0 @F@ FAM\n1 HUSB @P@\n1 CHIL @C@\n0 TRLR\n"
  try {
    let doc = @ged.parse(text)
    println("People: " + @ged.people(doc).length().to_string())
    for ancestor in @ged.graph(doc).ancestors("C") {
      println(
        "Recorded parent: " + @ged.person(doc, ancestor.person).display_name(),
      )
    }
    println(
      "Round-trip: " +
      @ged.equivalent(doc, @ged.parse(@ged.serialize(doc))).to_string(),
    )
  } catch {
    _ => println("Example failed")
  }
}
