///|
fn write_payload_line(
  out : StringBuilder,
  prefix : String,
  text : StringView,
  eol : String,
) -> Unit {
  out.write_string(prefix)
  if !text.is_empty() {
    out.write_char(' ')
    if text.has_prefix("@") {
      out.write_char('@')
    }
    out.write_view(text)
  }
  out.write_string(eol)
}

///|
/// Canonical text round-trip preserves payloads and structure order, not bytes.
/// CONT is emitted before ordinary children. Original line endings normalize.
/// bom=true emits the initial UTF-8 signature recommended by GEDCOM 7 §1.1.
pub fn serialize(
  doc : Document,
  line_ending~ : String = "\n",
  bom~ : Bool = false,
) -> String raise GedError {
  if line_ending != "\n" && line_ending != "\r\n" && line_ending != "\r" {
    raise Query("line ending must be LF, CRLF or CR")
  }
  let out = StringBuilder()
  if bom {
    out.write_char('\u{FEFF}')
  }
  for node in doc.nodes {
    let label = match node.xref {
      Some(id) => "@" + id + "@ " + node.tag
      None => node.tag
    }
    let prefix = node.level.to_string() + " " + label
    match node.payload {
      Empty => {
        out.write_string(prefix)
        out.write_string(line_ending)
      }
      Pointer(id) => {
        out.write_string(prefix + " @" + id + "@")
        out.write_string(line_ending)
      }
      Void => {
        out.write_string(prefix + " @VOID@")
        out.write_string(line_ending)
      }
      Text(text) => {
        let mut first = true
        for part in text.split("\n") {
          let current = if first {
            prefix
          } else {
            (node.level + 1).to_string() + " CONT"
          }
          write_payload_line(out, current, part, line_ending)
          first = false
        }
      }
    }
  }
  out.to_string()
}

///|
pub fn serialize_bytes(
  doc : Document,
  line_ending~ : String = "\n",
  bom~ : Bool = false,
) -> Bytes raise GedError {
  @utf8.encode(serialize(doc, line_ending~, bom~))
}

///|
/// Equality ignores source line numbers and equivalent empty payload spellings.
pub fn equivalent(a : Document, b : Document) -> Bool {
  if a.nodes.length() != b.nodes.length() {
    return false
  }
  for i, x in a.nodes {
    let y = b.nodes[i]
    if x.level != y.level ||
      x.tag != y.tag ||
      x.xref != y.xref ||
      x.parent != y.parent ||
      x.payload != y.payload {
      return false
    }
  }
  true
}
