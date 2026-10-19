///|
priv struct SchemaContext {
  types : Array[String?]
  children : Array[Array[Int32]]
  declarations : Map[String, String]
  metadata : Array[Map[String, String]]
}

///|
fn schema_context(doc : Document) -> SchemaContext {
  let declarations : Map[String, String] = Map([])
  for node in doc.nodes {
    if node.tag == "TAG" &&
      node.parent is Some(p) &&
      doc.nodes[p].tag == "SCHMA" &&
      doc.nodes[p].parent == Some(0) {
      if node.payload is Text(s) &&
        s.split_once(" ") is Some((tag, uri)) &&
        valid_tag(tag.to_owned()) &&
        tag.has_prefix("_") &&
        valid_uri_reference(uri.to_owned()) {
        declarations.set(tag.to_owned(), uri.to_owned())
      }
    }
  }
  let types : Array[String?] = []
  let metadata : Array[Map[String, String]] = Array::makei(
    doc.nodes.length() + 1,
    fn(_) { Map([]) },
  )
  let children : Array[Array[Int32]] = Array::makei(doc.nodes.length() + 1, fn(
    _,
  ) {
    []
  })
  for i, node in doc.nodes {
    let p = node.parent.unwrap_or(doc.nodes.length())
    children[p].push(i)
    if node.payload is Text(s) && !metadata[p].contains(node.tag) {
      metadata[p].set(node.tag, s)
    }
    let parent = match node.parent {
      None => Some("")
      Some(p) => types[p]
    }
    let edges = standard_children.get_or_default(parent.unwrap_or("?"), [])
    let mut resolved : String? = None
    if node.tag.has_prefix("_") {
      if declarations.get(node.tag) is Some(uri) &&
        uri.has_prefix("https://gedcom.io/terms/v7/") {
        let t = uri[27:].to_owned()
        if standard_payloads.contains(t) {
          resolved = Some(t)
        }
      }
    } else if parent != None {
      for (tag, t, _, _) in edges {
        if tag == node.tag {
          resolved = Some(t)
          break
        }
      }
    }
    types.push(resolved)
  }
  { types, children, declarations, metadata, }
}

///|
fn enum_is_valid(
  s : String,
  allowed : Array[String],
  ctx : SchemaContext,
  structure : String,
) -> Bool {
  if allowed.contains(s) {
    return true
  }
  if s.has_prefix("_") && valid_tag(s) {
    if ctx.declarations.get(s) is Some(uri) {
      // A relocated standard enumeration cannot reuse a standard value in its
      // original set. Unknown extension enumerations are accepted, unassessed.
      if standard_enum_uris.get_or_default(structure, []).contains(uri) {
        return false
      }
    }
    return true
  }
  false
}

///|
fn check_payload(
  kind : String,
  values : Array[String],
  payload : Payload,
  ctx : SchemaContext,
  structure~ : String = "",
) -> Bool {
  if kind == "" {
    return payload == Empty
  }
  if kind.has_prefix("pointer:") {
    return payload is Pointer(_) || payload == Void
  }
  if payload is Pointer(_) || payload == Void {
    return false
  }
  let s = payload.text().unwrap_or("")
  match kind {
    "xsd:string" => true
    "xsd:nonNegativeInteger" => ascii_digits(s)
    "Y|<NULL>" => s == "" || s == "Y"
    "type-Enum" => enum_is_valid(s, values, ctx, structure)
    "type-List#Enum" =>
      !s.has_prefix(" ") &&
      !s.has_suffix(" ") &&
      s
      .split(",")
      .all(fn(x) {
        enum_is_valid(trim_spaces(x.to_owned()), values, ctx, structure)
      })
    "type-List#Text" => {
      let parts = s.split(",").to_array()
      // Separator spaces may surround empty endpoint items as well.
      (parts.length() > 1 || s == trim_spaces(s)) &&
      (!s.has_prefix(" ") || trim_spaces(parts[0].to_owned()) == "") &&
      (
        !s.has_suffix(" ") ||
        trim_spaces(parts[parts.length() - 1].to_owned()) == ""
      )
    }
    "type-Age" => valid_age(s)
    "type-Time" => valid_time(s)
    "type-Name" => {
      let slashes = s.code_units().filter(fn(c) { c == 47 }).length()
      (slashes == 0 || slashes == 2) &&
      s.code_units().all(fn(c) { c >= 32 }) &&
      !s.is_empty()
    }
    "xsd:Language" => valid_language(s)
    "dcat:mediaType" => valid_media_type(s)
    "xsd:anyURI" => valid_uri_reference(s)
    "type-FilePath" => valid_file_path(s)
    "type-Latitude" => valid_coordinate(s, true)
    "type-Longitude" => valid_coordinate(s, false)
    "type-TagDef" =>
      match s.split_once(" ") {
        Some((tag, uri)) =>
          tag.has_prefix("_") &&
          valid_tag(tag.to_owned()) &&
          valid_uri_reference(uri.to_owned())
        None => false
      }
    "type-Date" | "type-Date#period" | "type-Date#exact" =>
      valid_date_payload(s, kind, ctx)
    _ => false
  }
}

///|
fn audit_schema(doc : Document, ctx : SchemaContext) -> Array[Diagnostic] {
  let out = []
  for i, node in doc.nodes {
    let parent = match node.parent {
      Some(p) => ctx.types[p]
      None => Some("")
    }
    let edges = standard_children.get_or_default(parent.unwrap_or("?"), [])
    let t = ctx.types[i]
    if t is None {
      if !node.tag.has_prefix("_") && parent != None {
        out.push(
          diagnostic(
            "structure-context",
            node.line,
            "standard tag " +
            node.tag +
            " is not permitted in " +
            parent.unwrap_or("dataset"),
          ),
        )
      }
      continue
    }
    let t = t.unwrap()
    if node.tag.has_prefix("_") {
      if node.parent == None || t.has_prefix("record-") {
        out.push(
          diagnostic(
            "relocated-record",
            node.line,
            "standard records cannot be relocated; standard substructures cannot become records",
          ),
        )
      } else if edges.any(fn(e) { e.1 == t }) {
        out.push(
          diagnostic(
            "relocated-context",
            node.line,
            "relocated standard structure must use its standard tag in an already permitted context",
          ),
        )
      }
    }
    let (kind, values) = standard_payloads.get_or_default(t, ("?", []))
    if !check_payload(kind, values, node.payload, ctx, structure=t) {
      out.push(diagnostic("payload-type", node.line, t + " requires " + kind))
    }
    if kind.has_prefix("pointer:") &&
      node.payload is Pointer(id) &&
      doc.lookup(id) is Some(target) {
      if ctx.types[target] != Some(kind[8:].to_owned()) {
        out.push(
          diagnostic(
            "schema-pointer-type",
            node.line,
            "pointer target requires " + kind[8:].to_owned(),
            related_line=doc.nodes[target].line,
          ),
        )
      }
    }
  }
  for p = 0; p < ctx.children.length(); p = p + 1 {
    let parent = if p == doc.nodes.length() { Some("") } else { ctx.types[p] }
    if parent is None {
      continue
    }
    let edges = standard_children.get_or_default(parent.unwrap(), [])
    let counts : Map[String, Int32] = Map([])
    for index in ctx.children[p] {
      if ctx.types[index] is Some(t) && !doc.nodes[index].tag.has_prefix("_") {
        counts.set(t, counts.get_or_default(t, 0) + 1)
      }
    }
    for (tag, t, required, singular) in edges {
      let count = counts.get_or_default(t, 0)
      let line = if p < doc.nodes.length() { doc.nodes[p].line } else { 1 }
      if required && count == 0 {
        out.push(
          diagnostic(
            "required-structure",
            line,
            parent.unwrap() + " requires " + tag,
          ),
        )
      }
      if singular && count > 1 {
        out.push(
          diagnostic(
            "structure-cardinality",
            line,
            parent.unwrap() + " permits at most one " + tag,
          ),
        )
      }
    }
  }
  out
}
