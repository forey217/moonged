///|
pub struct Person {
  record : Int32
  id : String?
  names : Array[String]
  sex : String?
  child_families : Array[String]
  spouse_families : Array[String]
}

///|
pub struct Family {
  record : Int32
  id : String?
  husband : String?
  wife : String?
  children : Array[String]
}

///|
pub struct Event {
  node : Int32
  tag : String
  date : String?
  place : String?
  sources : Array[String]
  notes : Array[String]
}

///|
fn texts(doc : Document, parent : Int32, tag : String) -> Array[String] {
  let values = []
  for index in doc.select(parent, tag) {
    if doc.nodes[index].payload is Text(s) {
      values.push(s)
    }
  }
  values
}

///|
fn pointers(doc : Document, parent : Int32, tag : String) -> Array[String] {
  let values = []
  for index in doc.select(parent, tag) {
    if doc.nodes[index].payload is Pointer(s) {
      values.push(s)
    }
  }
  values
}

///|
fn person_view(doc : Document, index : Int32) -> Person {
  {
    record: index,
    id: doc.nodes[index].xref,
    names: texts(doc, index, "NAME"),
    sex: texts(doc, index, "SEX").get(0),
    child_families: pointers(doc, index, "FAMC"),
    spouse_families: pointers(doc, index, "FAMS"),
  }
}

///|
fn family_view(doc : Document, index : Int32) -> Family {
  {
    record: index,
    id: doc.nodes[index].xref,
    husband: pointers(doc, index, "HUSB").get(0),
    wife: pointers(doc, index, "WIFE").get(0),
    children: pointers(doc, index, "CHIL"),
  }
}

///|
pub fn people(doc : Document) -> Array[Person] {
  doc.records
  .filter(fn(i) { doc.nodes[i].tag == "INDI" })
  .map(fn(i) { person_view(doc, i) })
}

///|
pub fn families(doc : Document) -> Array[Family] {
  doc.records
  .filter(fn(i) { doc.nodes[i].tag == "FAM" })
  .map(fn(i) { family_view(doc, i) })
}

///|
fn require_record(
  doc : Document,
  id : String,
  tag : String,
) -> Int32 raise GedError {
  let index = match doc.ids.get(id) {
    Some(i) => i
    None => raise Query("unknown identifier " + id)
  }
  if doc.nodes[index].tag != tag || doc.nodes[index].level != 0 {
    raise Query("identifier does not name a " + tag + " record")
  }
  // A query must not silently resolve an ambiguous duplicate definition.
  let count = doc.nodes.filter(fn(n) { n.xref == Some(id) }).length()
  if count != 1 {
    raise Query("ambiguous duplicate identifier " + id)
  }
  index
}

///|
pub fn person(doc : Document, id : String) -> Person raise GedError {
  person_view(doc, require_record(doc, id, "INDI"))
}

///|
pub fn family(doc : Document, id : String) -> Family raise GedError {
  family_view(doc, require_record(doc, id, "FAM"))
}

///|
pub fn Person::display_name(self : Person) -> String {
  match self.names.get(0) {
    Some(name) => name
    None => "(unnamed)"
  }
}

///|
/// Events retain raw dates and source IDs. An event is a claim, not a verified fact.
pub fn events(doc : Document, record : Int32) -> Array[Event] {
  let tags = [
    "ADOP", "BAPM", "BARM", "BASM", "BIRT", "BLES", "BURI", "CENS", "CHR", "CHRA",
    "CONF", "CREM", "DEAT", "EMIG", "FCOM", "GRAD", "IMMI", "NATU", "ORDN", "RETI",
    "PROB", "WILL", "EVEN", "ANUL", "DIV", "DIVF", "ENGA", "MARB", "MARC", "MARL",
    "MARR", "MARS", "RESI",
  ]
  let out = []
  for index in doc.children(record) {
    let node = doc.nodes[index]
    if tags.contains(node.tag) {
      out.push({
        node: index,
        tag: node.tag,
        date: texts(doc, index, "DATE").get(0),
        place: texts(doc, index, "PLAC").get(0),
        sources: pointers(doc, index, "SOUR"),
        notes: texts(doc, index, "NOTE"),
      })
    }
  }
  out
}

///|
/// Case-insensitive ASCII search; Unicode names are preserved, without locale folding.
pub fn find_people(doc : Document, query : String) -> Array[Person] {
  let query = query.to_lower()
  people(doc).filter(fn(p) {
    p.names.any(fn(n) { n.to_lower().contains(query) })
  })
}
