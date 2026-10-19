///|
/// GEDCOM 7 §MIME's specified HTML-to-text algorithm. Never evaluates markup,
/// follows links, fetches styles, or interprets it as active browser content.
pub fn html_to_plain(text : String) -> String {
  let collapsed = StringBuilder()
  let mut cursor = 0
  while cursor < text.length() {
    let space = text[cursor] == 32 ||
      text[cursor] == 9 ||
      text[cursor] == 10 ||
      text[cursor] == 13
    let start = cursor
    cursor = cursor + 1
    while cursor < text.length() &&
          (
            text[cursor] == 32 ||
            text[cursor] == 9 ||
            text[cursor] == 10 ||
            text[cursor] == 13
          ) ==
          space {
      cursor = cursor + 1
    }
    if space {
      collapsed.write_string(" ")
    } else {
      collapsed.write_string(text[start:cursor].to_owned())
    }
  }
  let s = collapsed.to_string()
  let out = StringBuilder()
  let mut i = 0
  while i < s.length() {
    if s[i] == 60 {
      let mut end = i + 1
      while end < s.length() && s[end] != 62 {
        end = end + 1
      }
      if end < s.length() {
        let tag = s[i + 1:end].to_owned().to_lower()
        if tag == "p" ||
          tag.has_prefix("p ") ||
          tag == "/p" ||
          tag.has_prefix("/p ") ||
          tag == "br" ||
          tag == "br/" ||
          tag.has_prefix("br ") {
          out.write_string("\n")
        }
        i = end + 1
        continue
      }
    }
    // Copy complete UTF-16 spans, including both halves of supplementary chars.
    let start = i
    i = i + 1
    while i < s.length() && s[i] != 60 {
      i = i + 1
    }
    out.write_string(s[start:i].to_owned())
  }
  out
  .to_string()
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&amp;", new="&")
}

///|
fn noncore_html_entity(s : String) -> Bool {
  let mut i = 0
  while i < s.length() {
    if s[i] != 38 {
      i = i + 1
      continue
    }
    let start = i + 1
    let mut end = start
    while end < s.length() &&
          (
            (s[end] >= 65 && s[end] <= 90) ||
            (s[end] >= 97 && s[end] <= 122) ||
            (s[end] >= 48 && s[end] <= 57)
          ) {
      end = end + 1
    }
    if end > start && end < s.length() && s[end] == 59 {
      if !["amp", "lt", "gt", "quot", "apos"].contains(s[start:end].to_owned()) {
        return true
      }
      i = end + 1
    } else {
      i = i + 1
    }
  }
  false
}
