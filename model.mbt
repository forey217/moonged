///|
pub(all) suberror GedError {
  Syntax(Int, String)
  Limit(String)
  InvalidState(String)
  Query(String)
} derive(@debug.Debug)

///|
/// Empty and a void pointer are distinct. Text beginning with @ is unescaped.
pub(all) enum Payload {
  Empty
  Text(String)
  Pointer(String)
  Void
} derive(Eq, @debug.Debug)

///|
pub extend GedError with @debug.Debug::{to_repr}

///|
pub extend Payload with @debug.Debug::{to_repr}

///|
pub extend Payload with Eq::{equal, not_equal}

///|
/// A preorder node. parent is an index in the owning Document.
pub struct Node {
  line : Int
  level : Int
  xref : String?
  tag : String
  payload : Payload
  parent : Int?
} derive(Eq, @debug.Debug)

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub struct Document {
  priv nodes : Array[Node]
  priv records : Array[Int]
  priv ids : Map[String, Int]
}

///|
/// Return a copy so callers cannot corrupt indices by editing an array.
pub fn Document::nodes(self : Document) -> Array[Node] {
  self.nodes.copy()
}

///|
pub fn Document::record_indices(self : Document) -> Array[Int] {
  self.records.copy()
}

///|
pub fn Document::length(self : Document) -> Int {
  self.nodes.length()
}

///|
pub fn Document::node(self : Document, index : Int) -> Node? {
  if index < 0 || index >= self.nodes.length() {
    None
  } else {
    Some(self.nodes[index])
  }
}

///|
/// Identifiers omit their surrounding @ delimiters.
pub fn Document::lookup(self : Document, id : String) -> Int? {
  self.ids.get(id)
}

///|
pub fn Document::children(self : Document, index : Int) -> Array[Int] {
  let out = []
  if index < 0 || index >= self.nodes.length() {
    return out
  }
  let level = self.nodes[index].level
  for i = index + 1; i < self.nodes.length(); i = i + 1 {
    if self.nodes[i].level <= level {
      break
    }
    if self.nodes[i].parent == Some(index) {
      out.push(i)
    }
  }
  out
}

///|
pub fn Document::select(
  self : Document,
  parent : Int,
  tag : String,
) -> Array[Int] {
  self.children(parent).filter(fn(i) { self.nodes[i].tag == tag })
}

///|
pub fn Document::first(self : Document, parent : Int, tag : String) -> Int? {
  self.select(parent, tag).get(0)
}

///|
pub fn Payload::text(self : Payload) -> String? {
  match self {
    Text(s) => Some(s)
    _ => None
  }
}

///|
pub fn Payload::target(self : Payload) -> String? {
  match self {
    Pointer(s) => Some(s)
    _ => None
  }
}
