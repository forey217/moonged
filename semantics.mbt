///|
fn child_payload(
  doc : Document,
  ctx : SchemaContext,
  parent : Int32,
  tag : String,
) -> String? {
  if parent < 0 || parent >= doc.nodes.length() {
    None
  } else {
    ctx.metadata[parent].get(tag)
  }
}

///|
fn inherited_language(
  doc : Document,
  ctx : SchemaContext,
  index : Int32,
) -> String {
  let mut current = Some(index)
  while current is Some(i) {
    if child_payload(doc, ctx, i, "LANG") is Some(s) {
      return s.to_lower()
    }
    current = doc.nodes[i].parent
  }
  child_payload(doc, ctx, 0, "LANG").unwrap_or("und").to_lower()
}

///|
fn translation_format(
  doc : Document,
  ctx : SchemaContext,
  index : Int32,
  parent : Int32,
) -> (String, String) {
  let language = child_payload(doc, ctx, index, "LANG")
    .map(fn(s) { s.to_lower() })
    .unwrap_or(inherited_language(doc, ctx, parent))
  let is_file = ctx.types[index] == Some("FILE-TRAN") ||
    ctx.types[index] == Some("FILE")
  let format = if is_file { "FORM" } else { "MIME" }
  let media = child_payload(doc, ctx, index, format).unwrap_or(
    child_payload(doc, ctx, parent, format).unwrap_or("text/plain"),
  )
  (language, media_identity(media))
}

///|
fn audit_semantics(doc : Document, ctx : SchemaContext) -> Array[Diagnostic] {
  let out = []
  let references : Map[String, Int32] = Map([])
  let owner : Array[Int32] = []
  let links : Map[String, Bool] = Map([])
  let translations : Map[String, Int32] = Map([])
  // Materialize pointers once, including reverse-link evidence. No quadratic
  // scan across all records and no recursion on attacker-controlled graphs.
  for i, node in doc.nodes {
    owner.push(
      match node.parent {
        Some(p) => owner[p]
        None => i
      },
    )
    if node.payload is Pointer(id) && node.parent is Some(p) {
      links.set(p.to_string() + "/" + node.tag + "/" + id, true)
    }
  }
  let cycle_edges : Map[Int32, Array[(Int32, Int32)]] = Map([])
  for i, node in doc.nodes {
    let t = ctx.types[i].unwrap_or("?")
    if standard_enum_uris.contains(t) && node.payload is Text(s) {
      for value in s.split(",") {
        let value = trim_spaces(value.to_owned())
        if value.has_prefix("_") {
          out.push(
            diagnostic(
              "enum-extension-unassessed",
              node.line,
              "extension enumeration is retained without certifying its external meaning",
              severity=Warning,
            ),
          )
        }
      }
    }
    if t == "MIME" && node.payload is Text(s) {
      if !s.to_lower().has_prefix("text/") {
        out.push(
          diagnostic(
            "note-mime-kind",
            node.line,
            "NOTE and SNOTE MIME must be a text media type",
          ),
        )
      }
      if s.to_lower() == "text/html" &&
        node.parent is Some(p) &&
        doc.nodes[p].payload is Text(text) &&
        noncore_html_entity(text) {
        out.push(
          diagnostic(
            "html-entity",
            doc.nodes[p].line,
            "HTML note contains non-core named entities; export requires their Unicode characters",
          ),
        )
      }
    }
    if t == "NO" &&
      node.payload is Text(value) &&
      !value.has_prefix("_") &&
      node.parent is Some(p) {
      let edges = standard_children.get_or_default(
        ctx.types[p].unwrap_or("?"),
        [],
      )
      if !edges.any(fn(e) { e.0 == value }) {
        out.push(
          diagnostic(
            "no-event-context",
            node.line,
            "NO event must be legal in its enclosing structure",
          ),
        )
      }
    }
    if ["FAM-HUSB", "FAM-WIFE", "CHIL"].contains(t) &&
      node.payload is Pointer(id) &&
      doc.lookup(id) is Some(person) {
      let family = owner[i]
      let back = if t == "CHIL" { "FAMC" } else { "FAMS" }
      let reciprocal = match doc.nodes[family].xref {
        Some(fid) => links.contains(person.to_string() + "/" + back + "/" + fid)
        None => false
      }
      if !reciprocal {
        out.push(
          diagnostic(
            "required-reciprocal-link",
            node.line,
            "FAM membership requires INDI." +
            back +
            " pointing back to this family",
            related_line=doc.nodes[person].line,
          ),
        )
      }
    }
    if t == "REFN" && node.payload is Text(s) && node.parent is Some(p) {
      if references.get(s) is Some(previous) &&
        doc.nodes[previous].parent != Some(p) {
        out.push(
          diagnostic(
            "refn-reuse",
            node.line,
            "REFN must not identify distinct structures describing different aspects",
            related_line=doc.nodes[previous].line,
          ),
        )
      } else {
        references.set(s, i)
      }
    }
    if t == "NOTE-TRAN" ||
      t == "NAME-TRAN" ||
      t == "PLAC-TRAN" ||
      t == "FILE-TRAN" {
      if node.parent is Some(p) {
        if t == "NOTE-TRAN" &&
          child_payload(doc, ctx, i, "LANG") == None &&
          child_payload(doc, ctx, i, "MIME") == None {
          out.push(
            diagnostic(
              "translation-format",
              node.line,
              "note translation requires LANG or MIME",
            ),
          )
        }
        let format = translation_format(doc, ctx, i, p)
        if format == translation_format(doc, ctx, p, p) {
          out.push(
            diagnostic(
              "translation-distinct",
              node.line,
              "translation must differ in language or media type from its superstructure",
              related_line=doc.nodes[p].line,
            ),
          )
        }
        let key = p.to_string() +
          "/" +
          Json::array([Json::string(format.0), Json::string(format.1)]).stringify()
        if translations.get(key) is Some(sibling) {
          out.push(
            diagnostic(
              "translation-duplicate",
              node.line,
              "translations must have distinct effective language/media-type pairs",
              related_line=doc.nodes[sibling].line,
            ),
          )
        } else {
          translations.set(key, i)
        }
      }
    }
    if node.payload is Pointer(id) &&
      doc.lookup(id) is Some(target) &&
      ctx.types[target] != None {
      let source = owner[i]
      let a = ctx.types[source].unwrap_or("?")
      let b = ctx.types[target].unwrap_or("?")
      if (a == "record-SOUR" && (b == "record-OBJE" || b == "record-SNOTE")) ||
        (b == "record-SOUR" && (a == "record-OBJE" || a == "record-SNOTE")) {
        let list = cycle_edges.get_or_default(source, [])
        list.push((target, i))
        cycle_edges.set(source, list)
      }
    }
    if t == "MIME" &&
      node.payload is Text(s) &&
      s != "text/plain" &&
      s != "text/html" {
      out.push(
        diagnostic(
          "note-media-type",
          node.line,
          "unsupported note media type should be treated as text/plain",
          severity=Warning,
        ),
      )
    }
    if node.tag.has_prefix("_") && ctx.types[i] == None {
      out.push(
        diagnostic(
          "extension-unassessed",
          node.line,
          "extension data is preserved; its external semantic definition is not certified",
          severity=Warning,
        ),
      )
    }
  }
  let colors : Map[Int32, Int32] = Map([])
  for start in doc.records {
    if colors.get_or_default(start, 0) != 0 {
      continue
    }
    let stack = [(start, 0)]
    colors.set(start, 1)
    while stack.length() > 0 {
      let k = stack.length() - 1
      let (current, next) = stack[k]
      let edges = cycle_edges.get_or_default(current, [])
      if next >= edges.length() {
        colors.set(current, 2)
        stack.remove(k) |> ignore
        continue
      }
      stack[k] = (current, next + 1)
      let (target, line_index) = edges[next]
      let color = colors.get_or_default(target, 0)
      if color == 1 {
        out.push(
          diagnostic(
            "source-reference-cycle",
            doc.nodes[line_index].line,
            "source/note/media references must not form a cycle",
            related_line=doc.nodes[target].line,
          ),
        )
      } else if color == 0 {
        colors.set(target, 1)
        stack.push((target, 0))
      }
    }
  }
  out
}
