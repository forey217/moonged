///|
fn required_string(
  o : Map[String, Json],
  field : String,
) -> String raise GedError {
  match o.get(field) {
    Some(String(s)) => s
    _ => raise Query(field + " must be a string")
  }
}

///|
fn error_json(error : Error) -> Json {
  let (code, line, message) = match error {
    GedError::Syntax(line, message) => ("syntax", Some(line), message)
    GedError::Limit(message) => ("limit", None, message)
    GedError::InvalidState(message) => ("state", None, message)
    GedError::Query(message) => ("query", None, message)
    _ => ("invalid_request", None, "invalid JSON request")
  }
  Json::object(
    Map([
      ("ok", Json::boolean(false)),
      ("code", Json::string(code)),
      (
        "line",
        match line {
          Some(n) => Json::number(n.to_double())
          None => Json::null()
        },
      ),
      ("error", Json::string(message)),
    ]),
  )
}

///|
/// Pure host boundary shared by CLI and browser. GEDCOM is a string field parsed
/// independently, so malformed GEDCOM cannot inject fields into the envelope.
pub fn run_json(request : String) -> String {
  try {
    if request.length() > 34000000 {
      raise Limit("request is too large")
    }
    guard @json.parse(request) is Object(o) else {
      raise Query("request must be an object")
    }
    let doc = parse(required_string(o, "text"))
    let result = match required_string(o, "command") {
      "inspect" => inspect_json(doc)
      "nodes" => Json::array(doc.nodes.map(node_json))
      "normalize" => Json::string(serialize(doc))
      "csv" => Json::string(people_csv(doc))
      "people" => Json::array(people(doc).map(person_json))
      "path" => {
        let path = graph(doc).shortest_path(
          required_string(o, "from"),
          required_string(o, "to"),
        )
        match path {
          Some(edges) => Json::array(edges.map(edge_json))
          None => Json::null()
        }
      }
      "ancestors" | "descendants" as command => {
        let g = graph(doc)
        let id = required_string(o, "id")
        let rows = if command == "ancestors" {
          g.ancestors(id)
        } else {
          g.descendants(id)
        }
        Json::array(
          rows.map(fn(r) {
            Json::object(
              Map([
                ("person", Json::string(r.person)),
                ("generations", Json::number(r.generations.to_double())),
              ]),
            )
          }),
        )
      }
      other => raise Query("unknown command " + other)
    }
    Json::object(Map([("ok", Json::boolean(true)), ("result", result)])).stringify()
  } catch {
    error => error_json(error).stringify()
  }
}
