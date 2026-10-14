///|
/// Limits are local resource policies, not restrictions imposed by GEDCOM 7.
pub struct Limits {
  max_nodes : Int32
  max_depth : Int32
  max_line_units : Int32
  max_total_units : Int32
}

///|
pub fn Limits::new(
  max_nodes~ : Int32 = 100000,
  max_depth~ : Int32 = 128,
  max_line_units~ : Int32 = 1048576,
  max_total_units~ : Int32 = 16777216,
) -> Limits raise GedError {
  if max_nodes < 1 ||
    max_nodes > 1000000 ||
    max_depth < 1 ||
    max_depth > 1024 ||
    max_line_units < 1 ||
    max_total_units < 1 {
    raise Limit("limits must be positive; nodes <= 1000000 and depth <= 1024")
  }
  { max_nodes, max_depth, max_line_units, max_total_units, }
}

///|
/// Incremental Unicode string chunks. Chunk boundaries must not split a character.
pub struct Parser {
  priv limits : Limits
  priv nodes : Array[Node]
  priv stack : Array[Int32]
  priv has_children : Array[Bool]
  priv continuations : Map[Int32, Array[String]]
  priv mut pending : String
  priv mut total : Int32
  priv mut line : Int32
  priv mut after_cr : Bool
  priv mut closed : Bool
  priv mut failed : Bool
}

///|
pub fn Parser::new(limits? : Limits) -> Parser raise GedError {
  let limits = match limits {
    Some(l) => l
    None => Limits::new()
  }
  {
    limits,
    nodes: [],
    stack: [],
    has_children: [],
    continuations: Map([]),
    pending: "",
    total: 0,
    line: 0,
    after_cr: false,
    closed: false,
    failed: false,
  }
}

///|
fn valid_tag_char(c : UInt16) -> Bool {
  (c >= 65 && c <= 90) || (c >= 48 && c <= 57) || c == 95
}

///|
fn valid_id(s : String) -> Bool {
  s.length() > 0 && s != "VOID" && s.code_units().all(valid_tag_char)
}

///|
fn valid_tag(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  let first = s[0]
  ((first >= 65 && first <= 90) || (first == 95 && s.length() > 1)) &&
  s.code_units().all(valid_tag_char)
}

///|
fn check_chars(s : String, line : Int32) -> Unit raise GedError {
  let units = s.code_units()
  let mut i = 0
  while i < units.length() {
    let c = units[i]
    if (c < 32 && c != 9) || (c >= 127 && c <= 159) || c == 65534 || c == 65535 {
      raise Syntax(line, "forbidden control or noncharacter")
    }
    if c >= 55296 && c <= 56319 {
      if i + 1 >= units.length() || units[i + 1] < 56320 || units[i + 1] > 57343 {
        raise Syntax(line, "unpaired high surrogate")
      }
      i = i + 2
    } else if c >= 56320 && c <= 57343 {
      raise Syntax(line, "unpaired low surrogate")
    } else {
      i = i + 1
    }
  }
}

///|
fn read_token(
  s : String,
  start : Int32,
  line : Int32,
) -> (String, Int32) raise GedError {
  let mut end = start
  while end < s.length() && s[end] != 32 {
    end = end + 1
  }
  if end == start {
    raise Syntax(line, "expected token separated by one space")
  }
  (s[start:end].to_owned(), if end < s.length() { end + 1 } else { end })
}

///|
fn parse_line(s : String, line : Int32, depth : Int32) -> Node raise GedError {
  check_chars(s, line)
  let (level_text, after_level) = read_token(s, 0, line)
  if after_level == s.length() ||
    !level_text.code_units().all(fn(c) { c >= 48 && c <= 57 }) ||
    (level_text.length() > 1 && level_text[0] == 48) {
    raise Syntax(line, "invalid level or missing tag")
  }
  let level = @string.parse_int(level_text) catch {
    _ => raise Syntax(line, "level is outside integer range")
  }
  if level > depth {
    raise Limit("nesting depth exceeded")
  }
  let (token, after_token) = read_token(s, after_level, line)
  let (xref, tag, value_start) = if token.has_prefix("@") {
    if token.length() < 3 || !token.has_suffix("@") {
      raise Syntax(line, "invalid cross-reference identifier")
    }
    let id = token[1:token.length() - 1].to_owned()
    if !valid_id(id) {
      raise Syntax(line, "invalid or reserved identifier")
    }
    let (tag, after_tag) = read_token(s, after_token, line)
    (Some(id), tag, after_tag)
  } else {
    (None, token, after_token)
  }
  if !valid_tag(tag) {
    raise Syntax(line, "invalid tag")
  }
  // A delimiter with no line value is not a GEDCOM 7 line.
  if s.has_suffix(" ") && value_start == s.length() {
    raise Syntax(line, "empty line value must omit its delimiter")
  }
  let value = s[value_start:].to_owned()
  let payload = if value == "" {
    Empty
  } else if value == "@VOID@" {
    Void
  } else if value.has_prefix("@@") {
    Text(value[1:].to_owned())
  } else if value.has_prefix("@") {
    if !value.has_suffix("@") || value.length() < 3 {
      raise Syntax(line, "leading @ text must be escaped as @@")
    }
    let id = value[1:value.length() - 1].to_owned()
    if !valid_id(id) {
      raise Syntax(line, "invalid pointer")
    }
    Pointer(id)
  } else {
    Text(value)
  }
  { line, level, xref, tag, payload, parent: None, }
}

///|
fn Parser::take_line(self : Parser, value : String) -> Unit raise GedError {
  self.line = self.line + 1
  let value = if self.line == 1 && value.has_prefix("\u{FEFF}") {
    value[1:].to_owned()
  } else {
    value
  }
  if value.length() == 0 {
    raise Syntax(self.line, "blank lines are not GEDCOM 7")
  }
  let node = parse_line(value, self.line, self.limits.max_depth)
  if node.level > self.stack.length() {
    raise Syntax(self.line, "level jump or child of CONT")
  }
  while self.stack.length() > node.level {
    self.stack.remove(self.stack.length() - 1) |> ignore
  }
  let parent = if node.level > 0 {
    Some(self.stack[node.level - 1])
  } else {
    None
  }
  if node.tag == "CONT" {
    let parent = match parent {
      Some(p) => p
      None => raise Syntax(self.line, "CONT cannot be a record")
    }
    if node.xref != None || self.has_children[parent] {
      raise Syntax(
        self.line,
        "CONT must precede ordinary substructures and cannot have an id",
      )
    }
    let base = self.nodes[parent]
    let first = match base.payload {
      Empty => ""
      Text(t) => t
      _ => raise Syntax(self.line, "pointer cannot have CONT")
    }
    let next = match node.payload {
      Empty => ""
      Text(t) => t
      _ => raise Syntax(self.line, "CONT cannot be a pointer")
    }
    self.continuations.get_or_init(parent, fn() { [first] }).push(next)
  } else {
    if self.nodes.length() >= self.limits.max_nodes {
      raise Limit("node count exceeded")
    }
    if parent is Some(p) {
      self.has_children[p] = true
    }
    let index = self.nodes.length()
    self.nodes.push({
      line: node.line,
      level: node.level,
      xref: node.xref,
      tag: node.tag,
      payload: node.payload,
      parent,
    })
    self.has_children.push(false)
    self.stack.push(index)
  }
}

///|
fn Parser::feed_impl(self : Parser, chunk : String) -> Unit raise GedError {
  if self.closed || self.failed {
    raise InvalidState("parser is closed or failed")
  }
  // StringView slices clamp split surrogate pairs. Reject invalid strings before
  // slicing rather than silently losing a character supplied by a JS host.
  let mut u = 0
  while u < chunk.length() {
    let c = chunk[u]
    if c >= 55296 && c <= 56319 {
      if u + 1 >= chunk.length() || chunk[u + 1] < 56320 || chunk[u + 1] > 57343 {
        raise Syntax(self.line + 1, "string chunk splits a Unicode character")
      }
      u = u + 2
    } else if c >= 56320 && c <= 57343 {
      raise Syntax(self.line + 1, "unpaired low surrogate in string chunk")
    } else {
      u = u + 1
    }
  }
  if chunk.length() > self.limits.max_total_units - self.total {
    raise Limit("input size exceeded")
  }
  self.total = self.total + chunk.length()
  let mut start = 0
  for i = 0; i < chunk.length(); i = i + 1 {
    let c = chunk[i]
    if self.after_cr {
      self.after_cr = false
      if c == 10 {
        start = i + 1
        continue
      }
    }
    if c == 10 || c == 13 {
      if i - start > self.limits.max_line_units - self.pending.length() {
        raise Limit("line size exceeded")
      }
      let line = self.pending + chunk[start:i].to_owned()
      self.pending = ""
      self.take_line(line)
      self.after_cr = c == 13
      start = i + 1
    }
  }
  if chunk.length() - start > self.limits.max_line_units - self.pending.length() {
    raise Limit("line size exceeded")
  }
  self.pending = self.pending + chunk[start:].to_owned()
}

///|
pub fn Parser::feed(self : Parser, chunk : String) -> Unit raise GedError {
  errdefer {
    self.failed = true
  }
  self.feed_impl(chunk)
}

///|
pub fn Parser::finish(self : Parser) -> Document raise GedError {
  if self.closed || self.failed {
    raise InvalidState("parser is closed or failed")
  }
  self.closed = true
  if self.pending != "" {
    self.take_line(self.pending)
  }
  if self.nodes.length() == 0 {
    raise Syntax(1, "empty document")
  }
  let records = []
  let ids : Map[String, Int32] = Map([])
  for i, node in self.nodes {
    if node.level == 0 {
      records.push(i)
    }
    // First definition is indexed; duplicates remain available to the auditor.
    if node.xref is Some(id) && ids.get(id) == None {
      ids.set(id, i)
    }
  }
  let nodes = self.nodes.copy()
  for (index, parts) in self.continuations {
    let base = nodes[index]
    nodes[index] = {
      line: base.line,
      level: base.level,
      xref: base.xref,
      tag: base.tag,
      payload: Text(parts.join("\n")),
      parent: base.parent,
    }
  }
  { nodes, records, ids, }
}

///|
pub fn parse(text : String, limits? : Limits) -> Document raise GedError {
  let parser = Parser::new(limits?)
  parser.feed(text)
  parser.finish()
}

///|
/// Decode strictly; malformed UTF-8 is rejected instead of silently replaced.
pub fn parse_bytes(bytes : Bytes, limits? : Limits) -> Document raise GedError {
  let text = @utf8.decode(bytes) catch { _ => raise Syntax(1, "invalid UTF-8") }
  parse(text, limits?)
}
