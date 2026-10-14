///|
pub(all) suberror GedError {
  Syntax(Int32, String)
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
  line : Int32
  level : Int32
  xref : String?
  tag : String
  payload : Payload
  parent : Int32?
} derive(Eq, @debug.Debug)

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub struct Document {
  priv nodes : Array[Node]
  priv records : Array[Int32]
  priv ids : Map[String, Int32]
}

///|
/// Return a copy so callers cannot corrupt indices by editing an array.
pub fn Document::nodes(self : Document) -> Array[Node] {
  self.nodes.copy()
}

///|
pub fn Document::record_indices(self : Document) -> Array[Int32] {
  self.records.copy()
}

///|
pub fn Document::length(self : Document) -> Int32 {
  self.nodes.length()
}

///|
pub fn Document::node(self : Document, index : Int32) -> Node? {
  if index < 0 || index >= self.nodes.length() {
    None
  } else {
    Some(self.nodes[index])
  }
}

///|
/// Identifiers omit their surrounding @ delimiters.
pub fn Document::lookup(self : Document, id : String) -> Int32? {
  self.ids.get(id)
}

///|
pub fn Document::children(self : Document, index : Int32) -> Array[Int32] {
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
  parent : Int32,
  tag : String,
) -> Array[Int32] {
  self.children(parent).filter(fn(i) { self.nodes[i].tag == tag })
}

///|
pub fn Document::first(self : Document, parent : Int32, tag : String) -> Int32? {
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
