///|
fn document_from_nodes(nodes : Array[Node]) -> Document {
  let records = []
  let ids : Map[String, Int32] = Map([])
  for i, node in nodes {
    if node.level == 0 {
      records.push(i)
    }
    if node.xref is Some(id) && ids.get(id) == None {
      ids.set(id, i)
    }
  }
  { nodes, records, ids, }
}

///|
/// Rename identifiers and every pointer together. Unmentioned IDs remain unchanged.
/// Reject collisions, unknown source IDs and @VOID@; input document stays intact.
pub fn remap_ids(
  doc : Document,
  mapping : Map[String, String],
) -> Document raise GedError {
  let defined : Map[String, Bool] = Map([])
  for node in doc.nodes {
    if node.xref is Some(id) {
      if defined.get(id) != None {
        raise Query("cannot remap ambiguous duplicate identifiers")
      }
      defined.set(id, true)
    }
  }
  for (from, to) in mapping {
    if defined.get(from) == None {
      raise Query("unknown source identifier " + from)
    }
    if !valid_id(to) {
      raise Query("invalid target identifier " + to)
    }
  }
  let target_ids : Map[String, Bool] = Map([])
  for (id, _) in defined {
    let target = mapping.get_or_default(id, id)
    if target_ids.get(target) != None {
      raise Query("remapped identifiers collide at " + target)
    }
    target_ids.set(target, true)
  }
  let nodes = doc.nodes.map(fn(node) {
    let xref = node.xref.map(fn(id) { mapping.get_or_default(id, id) })
    let payload = match node.payload {
      Pointer(id) => Pointer(mapping.get_or_default(id, id))
      other => other
    }
    {
      line: node.line,
      level: node.level,
      xref,
      tag: node.tag,
      payload,
      parent: node.parent,
    }
  })
  document_from_nodes(nodes)
}

///|
pub struct Extracted {
  document : Document
  included_ids : Array[String]
}

///|
/// Extract whole records with transitive pointer closure, including header targets.
/// Family pointers can pull in a whole connected family component. This is not a
/// privacy filter or ancestor-only export. The limit fails before returning output.
pub fn extract_records(
  doc : Document,
  ids : Array[String],
  max_records~ : Int32 = 10000,
) -> Extracted raise GedError {
  if max_records < 2 || max_records > 100000 {
    raise Query("record limit must be in 2..100000")
  }
  if has_errors(audit(doc)) {
    raise Query("fix interchange errors before record extraction")
  }
  let owner : Array[Int32] = []
  let mut current = 0
  for i, node in doc.nodes {
    if node.level == 0 {
      current = i
    }
    owner.push(current)
  }
  let included : Map[Int32, Bool] = Map([])
  let queue = []
  for index in [doc.records[0], doc.records[doc.records.length() - 1]] {
    if included.get(index) == None {
      included.set(index, true)
      queue.push(index)
    }
  }
  for id in ids {
    let index = match doc.ids.get(id) {
      Some(i) => owner[i]
      None => raise Query("unknown selected identifier " + id)
    }
    if included.get(index) == None {
      included.set(index, true)
      queue.push(index)
    }
  }
  if queue.length() > max_records {
    raise Limit("selected records exceed extraction limit")
  }
  let mut head = 0
  while head < queue.length() {
    let index = queue[head]
    head = head + 1
    let mut i = index
    while i < doc.nodes.length() && (i == index || doc.nodes[i].level > 0) {
      if doc.nodes[i].payload is Pointer(id) {
        let target = match doc.ids.get(id) {
          Some(t) => owner[t]
          None => raise Query("dangling pointer during extraction")
        }
        if included.get(target) == None {
          if queue.length() >= max_records {
            raise Limit("pointer closure exceeds extraction limit")
          }
          included.set(target, true)
          queue.push(target)
        }
      }
      i = i + 1
    }
  }
  let old_to_new : Map[Int32, Int32] = Map([])
  let nodes = []
  let included_ids = []
  for i, node in doc.nodes {
    if included.get(owner[i]) == None {
      continue
    }
    let parent = node.parent.map(fn(p) { old_to_new[p] })
    old_to_new.set(i, nodes.length())
    nodes.push({
      line: node.line,
      level: node.level,
      xref: node.xref,
      tag: node.tag,
      payload: node.payload,
      parent,
    })
    if node.xref is Some(id) {
      included_ids.push(id)
    }
  }
  { document: document_from_nodes(nodes), included_ids, }
}
