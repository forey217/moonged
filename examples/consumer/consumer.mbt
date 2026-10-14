///|
/// This is a different module using only MoonGED's public interface.
pub fn parent_names(text : String, child : String) -> Array[String] raise {
  let doc = @ged.parse(text)
  let g = @ged.graph(doc)
  g
  .ancestors(child, max_depth=1)
  .map(fn(r) raise { @ged.person(doc, r.person).display_name() })
}

///|
pub fn round_trip(text : String) -> Bool raise {
  let doc = @ged.parse(text)
  @ged.equivalent(doc, @ged.parse(@ged.serialize(doc)))
}
