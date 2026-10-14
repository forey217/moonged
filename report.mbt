///|
fn optional_text(value : String?) -> Json {
  match value {
    Some(s) => Json::string(s)
    None => Json::null()
  }
}

///|
fn strings_json(values : Array[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
fn person_json(p : Person) -> Json {
  Json::object(
    Map([
      ("id", optional_text(p.id)),
      ("name", Json::string(p.display_name())),
      ("names", strings_json(p.names)),
      ("sex", optional_text(p.sex)),
      ("child_families", strings_json(p.child_families)),
      ("spouse_families", strings_json(p.spouse_families)),
    ]),
  )
}

///|
fn family_json(f : Family) -> Json {
  Json::object(
    Map([
      ("id", optional_text(f.id)),
      ("husband", optional_text(f.husband)),
      ("wife", optional_text(f.wife)),
      ("children", strings_json(f.children)),
    ]),
  )
}

///|
fn node_json(n : Node) -> Json {
  let (kind, value) = match n.payload {
    Empty => ("empty", Json::null())
    Text(t) => ("text", Json::string(t))
    Pointer(id) => ("pointer", Json::string(id))
    Void => ("void", Json::null())
  }
  Json::object(
    Map([
      ("line", Json::number(n.line.to_double())),
      ("level", Json::number(n.level.to_double())),
      ("xref", optional_text(n.xref)),
      ("tag", Json::string(n.tag)),
      ("kind", Json::string(kind)),
      ("value", value),
    ]),
  )
}

///|
fn diagnostic_json(d : Diagnostic) -> Json {
  Json::object(
    Map([
      (
        "severity",
        Json::string(if d.severity == Error { "error" } else { "warning" }),
      ),
      ("code", Json::string(d.code)),
      ("line", Json::number(d.line.to_double())),
      (
        "related_line",
        match d.related_line {
          Some(n) => Json::number(n.to_double())
          None => Json::null()
        },
      ),
      ("message", Json::string(d.message)),
    ]),
  )
}

///|
fn relation_text(relation : Relation) -> String {
  match relation {
    Parent => "parent"
    Child => "child"
    Partner => "partner"
  }
}

///|
fn edge_json(edge : Edge) -> Json {
  Json::object(
    Map([
      ("from", Json::string(edge.from)),
      ("to", Json::string(edge.to)),
      ("relation", Json::string(relation_text(edge.relation))),
      ("family", optional_text(edge.family)),
      ("pedigree", optional_text(edge.pedigree)),
    ]),
  )
}

///|
pub fn full_audit(doc : Document) -> Array[Diagnostic] {
  let out = audit(doc)
  if !has_errors(out) {
    try audit_relationships(doc) catch {
      _ => ()
    } noraise {
      more => out.append(more)
    }
  }
  out.append(audit_dates(doc))
  out.sort_by(fn(a, b) {
    if a.line != b.line {
      a.line - b.line
    } else {
      a.code.compare(b.code)
    }
  })
  out
}

///|
pub fn inspect_json(doc : Document) -> Json {
  let diagnostics = full_audit(doc)
  Json::object(
    Map([
      ("valid", Json::boolean(!has_errors(diagnostics))),
      (
        "validation_scope",
        Json::string("selected GEDCOM 7 checks; not full schema validation"),
      ),
      ("node_count", Json::number(doc.length().to_double())),
      ("people", Json::array(people(doc).map(person_json))),
      ("families", Json::array(families(doc).map(family_json))),
      ("diagnostics", Json::array(diagnostics.map(diagnostic_json))),
    ]),
  )
}

///|
fn csv_cell(value : String, spreadsheet_safe : Bool) -> String {
  let value = if spreadsheet_safe &&
    (
      value.has_prefix("=") ||
      value.has_prefix("+") ||
      value.has_prefix("-") ||
      value.has_prefix("@") ||
      value.has_prefix("\t") ||
      value.has_prefix("\r")
    ) {
    "'" + value
  } else {
    value
  }
  "\"" + value.replace_all(old="\"", new="\"\"") + "\""
}

///|
/// RFC 4180 quoting and CRLF rows. Spreadsheet protection may prefix an apostrophe;
/// disable it explicitly for raw data interchange rather than silently changing data.
pub fn people_csv(doc : Document, spreadsheet_safe~ : Bool = true) -> String {
  let out = StringBuilder()
  out.write_string("id,name,sex,child_families,spouse_families\r\n")
  for p in people(doc) {
    let fields = [
      p.id.unwrap_or(""),
      p.display_name(),
      p.sex.unwrap_or(""),
      p.child_families.join(";"),
      p.spouse_families.join(";"),
    ]
    out.write_string(
      fields.map(fn(s) { csv_cell(s, spreadsheet_safe) }).join(","),
    )
    out.write_string("\r\n")
  }
  out.to_string()
}
