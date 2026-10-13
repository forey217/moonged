///|
pub(all) enum Relation {
  Parent
  Child
  Partner
} derive(Eq, @debug.Debug)

///|
pub extend Relation with Eq::{equal, not_equal}

///|
pub extend Relation with @debug.Debug::{to_repr}

///|
/// Direction is relative to `from`: Parent means `to` is a recorded parent.
/// PEDI is the literal pedigree qualifier; no biological relationship is inferred.
pub struct Edge {
  from : String
  to : String
  relation : Relation
  family : String?
  pedigree : String?
} derive(Eq, @debug.Debug)

///|
pub extend Edge with Eq::{equal, not_equal}

///|
pub extend Edge with @debug.Debug::{to_repr}

///|
pub struct FamilyGraph {
  priv edges : Map[String, Array[Edge]]
}

///|
fn graph_add(edges : Map[String, Array[Edge]], edge : Edge) -> Unit {
  let list = edges.get_or_init(edge.from, fn() { [] })
  if !list.contains(edge) {
    list.push(edge)
  }
}

///|
/// Requires an unambiguous, structurally audited document. Reciprocal omissions
/// are reported separately; FAM records define edges, not inferred text claims.
pub fn graph(doc : Document) -> FamilyGraph raise GedError {
  if has_errors(audit(doc)) {
    raise Query("fix interchange errors before building a relationship graph")
  }
  let edges : Map[String, Array[Edge]] = Map([])
  let pedigrees : Map[String, String] = Map([])
  for p in people(doc) {
    if p.id is Some(id) {
      edges.set(id, [])
      for index in doc.select(p.record, "FAMC") {
        if doc.nodes[index].payload is Pointer(f) &&
          texts(doc, index, "PEDI").get(0) is Some(pedi) {
          pedigrees.set(id + "@" + f, pedi)
        }
      }
    }
  }
  for f in families(doc) {
    let fid = f.id.unwrap_or("")
    let parents = []
    if f.husband is Some(id) {
      parents.push(id)
    }
    if f.wife is Some(id) && !parents.contains(id) {
      parents.push(id)
    }
    for parent in parents {
      for child in f.children {
        let pedigree = pedigrees.get(child + "@" + fid)
        graph_add(edges, {
          from: child,
          to: parent,
          relation: Parent,
          family: f.id,
          pedigree,
        })
        graph_add(edges, {
          from: parent,
          to: child,
          relation: Child,
          family: f.id,
          pedigree,
        })
      }
    }
    if parents.length() == 2 {
      graph_add(edges, {
        from: parents[0],
        to: parents[1],
        relation: Partner,
        family: f.id,
        pedigree: None,
      })
      graph_add(edges, {
        from: parents[1],
        to: parents[0],
        relation: Partner,
        family: f.id,
        pedigree: None,
      })
    }
  }
  { edges, }
}

///|
pub fn FamilyGraph::neighbors(
  self : FamilyGraph,
  id : String,
) -> Array[Edge] raise GedError {
  match self.edges.get(id) {
    Some(list) => list.copy()
    None => raise Query("unknown person " + id)
  }
}

///|
pub struct Reachable {
  person : String
  generations : Int
}

///|
fn FamilyGraph::traverse(
  self : FamilyGraph,
  id : String,
  direction : Relation,
  max_depth : Int,
) -> Array[Reachable] raise GedError {
  if max_depth < 0 || max_depth > 10000 {
    raise Query("max depth must be in 0..10000")
  }
  self.neighbors(id) |> ignore
  let visited : Map[String, Bool] = Map([(id, true)])
  let queue = [(id, 0)]
  let out = []
  let mut head = 0
  while head < queue.length() {
    let (current, depth) = queue[head]
    head = head + 1
    if depth >= max_depth {
      continue
    }
    for edge in self.edges.get_or_default(current, []) {
      if edge.relation == direction && visited.get(edge.to) == None {
        visited.set(edge.to, true)
        queue.push((edge.to, depth + 1))
        out.push({ person: edge.to, generations: depth + 1, })
      }
    }
  }
  out
}

///|
pub fn FamilyGraph::ancestors(
  self : FamilyGraph,
  id : String,
  max_depth? : Int = 1000,
) -> Array[Reachable] raise GedError {
  self.traverse(id, Parent, max_depth)
}

///|
pub fn FamilyGraph::descendants(
  self : FamilyGraph,
  id : String,
  max_depth? : Int = 1000,
) -> Array[Reachable] raise GedError {
  self.traverse(id, Child, max_depth)
}

///|
/// BFS shortest path in recorded family links. None means disconnected or beyond
/// max_depth. Paths do not constitute genetic kinship or verified history.
pub fn FamilyGraph::shortest_path(
  self : FamilyGraph,
  from : String,
  to : String,
  max_depth? : Int = 1000,
) -> Array[Edge]? raise GedError {
  if max_depth < 0 || max_depth > 10000 {
    raise Query("max depth must be in 0..10000")
  }
  self.neighbors(from) |> ignore
  self.neighbors(to) |> ignore
  if from == to {
    return Some([])
  }
  let prior : Map[String, Edge] = Map([])
  let visited : Map[String, Bool] = Map([(from, true)])
  let queue = [(from, 0)]
  let mut head = 0
  while head < queue.length() {
    let (current, depth) = queue[head]
    head = head + 1
    if depth >= max_depth {
      continue
    }
    for edge in self.edges.get_or_default(current, []) {
      if visited.get(edge.to) != None {
        continue
      }
      visited.set(edge.to, true)
      prior.set(edge.to, edge)
      if edge.to == to {
        let path = []
        let mut back = to
        while back != from {
          let step = prior[back]
          path.push(step)
          back = step.from
        }
        path.rev_in_place()
        return Some(path)
      }
      queue.push((edge.to, depth + 1))
    }
  }
  None
}

///|
/// Extra quality warnings: missing reciprocal links and ancestry cycles.
/// They are separate from selected GEDCOM syntax/record validation.
pub fn audit_relationships(doc : Document) -> Array[Diagnostic] raise GedError {
  let g = graph(doc)
  let out = []
  let person_by_id : Map[String, Person] = Map([])
  let family_by_id : Map[String, Family] = Map([])
  for p in people(doc) {
    if p.id is Some(id) {
      person_by_id.set(id, p)
    }
  }
  for f in families(doc) {
    if f.id is Some(id) {
      family_by_id.set(id, f)
    }
  }
  for (fid, f) in family_by_id {
    for id in f.children {
      if person_by_id.get(id) is Some(p) && !p.child_families.contains(fid) {
        out.push(
          diagnostic(
            "missing-reciprocal-famc",
            doc.nodes[p.record].line,
            "FAM lists this child but INDI lacks reciprocal FAMC",
            severity=Warning,
            related_line=doc.nodes[f.record].line,
          ),
        )
      }
    }
    for id in [f.husband, f.wife] {
      if id is Some(pid) &&
        person_by_id.get(pid) is Some(p) &&
        !p.spouse_families.contains(fid) {
        out.push(
          diagnostic(
            "missing-reciprocal-fams",
            doc.nodes[p.record].line,
            "FAM lists this partner but INDI lacks reciprocal FAMS",
            severity=Warning,
            related_line=doc.nodes[f.record].line,
          ),
        )
      }
    }
  }
  for (id, p) in person_by_id {
    for fid in p.child_families {
      if family_by_id.get(fid) is Some(f) && !f.children.contains(id) {
        out.push(
          diagnostic(
            "missing-reciprocal-chil",
            doc.nodes[p.record].line,
            "INDI.FAMC has no reciprocal FAM.CHIL",
            severity=Warning,
            related_line=doc.nodes[f.record].line,
          ),
        )
      }
    }
    for fid in p.spouse_families {
      if family_by_id.get(fid) is Some(f) &&
        f.husband != Some(id) &&
        f.wife != Some(id) {
        out.push(
          diagnostic(
            "missing-reciprocal-partner",
            doc.nodes[p.record].line,
            "INDI.FAMS has no reciprocal FAM partner",
            severity=Warning,
            related_line=doc.nodes[f.record].line,
          ),
        )
      }
    }
  }
  // Iterative DFS with color states detects cycles once, without unbounded stack.
  let color : Map[String, Int] = Map([])
  for (id, _) in person_by_id {
    if color.get_or_default(id, 0) != 0 {
      continue
    }
    let stack = [(id, false)]
    while stack.length() > 0 {
      let (current, exit) = stack[stack.length() - 1]
      stack.remove(stack.length() - 1) |> ignore
      if exit {
        color.set(current, 2)
        continue
      }
      if color.get_or_default(current, 0) != 0 {
        continue
      }
      color.set(current, 1)
      stack.push((current, true))
      for edge in g.edges.get_or_default(current, []) {
        if edge.relation != Parent {
          continue
        }
        let c = color.get_or_default(edge.to, 0)
        if c == 1 {
          out.push(
            diagnostic(
              "ancestry-cycle",
              doc.nodes[person_by_id[current].record].line,
              "recorded parent links form a cycle; review non-biological relationships",
              severity=Warning,
            ),
          )
        } else if c == 0 {
          stack.push((edge.to, false))
        }
      }
    }
  }
  out
}
