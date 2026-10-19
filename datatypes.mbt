///|
fn ascii_digits(s : String) -> Bool {
  !s.is_empty() && s.code_units().all(fn(c) { c >= 48 && c <= 57 })
}

///|
fn ascii_letters(s : String) -> Bool {
  !s.is_empty() &&
  s.code_units().all(fn(c) { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) })
}

///|
fn ascii_alnum(s : String) -> Bool {
  !s.is_empty() &&
  s
  .code_units()
  .all(fn(c) {
    (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57)
  })
}

///|
fn trim_spaces(s : String) -> String {
  let mut a = 0
  let mut b = s.length()
  while a < b && s[a] == 32 {
    a = a + 1
  }
  while b > a && s[b - 1] == 32 {
    b = b - 1
  }
  s[a:b].to_owned()
}

///|
fn small_number(s : String, max : Int32) -> Bool {
  if !ascii_digits(s) {
    return false
  }
  let mut n = 0
  for c in s.code_units() {
    if n > max / 10 {
      return false
    }
    n = n * 10 + c.to_int() - 48
    if n > max {
      return false
    }
  }
  true
}

///|
fn valid_time(s : String) -> Bool {
  let s = if s.has_suffix("Z") { s[:s.length() - 1].to_owned() } else { s }
  let ts = s.split(":").map(fn(x) { x.to_owned() }).to_array()
  if ts.length() < 2 || ts.length() > 3 {
    return false
  }
  if ts[0].length() > 2 ||
    !small_number(ts[0], 23) ||
    ts[1].length() != 2 ||
    !small_number(ts[1], 59) {
    return false
  }
  if ts.length() == 3 {
    let ss = ts[2].split(".").map(fn(x) { x.to_owned() }).to_array()
    if ss.length() > 2 || ss[0].length() != 2 || !small_number(ss[0], 59) {
      return false
    }
    if ss.length() == 2 && !ascii_digits(ss[1]) {
      return false
    }
  }
  true
}

///|
fn valid_age(s : String) -> Bool {
  if s == "" {
    return true
  }
  let s = if s.has_prefix("<") || s.has_prefix(">") {
    s[1:].to_owned()
  } else {
    s
  }
  let mut previous = -1
  for part in s.split(" ") {
    if part.length() < 2 {
      return false
    }
    let n = part.length() - 1
    let unit = match part[n] {
      121 => 0
      109 => 1
      119 => 2
      100 => 3
      _ => -1
    }
    if unit <= previous || !ascii_digits(part[:n].to_owned()) {
      return false
    }
    previous = unit
  }
  previous >= 0
}

///|
/// RFC 5646 Language-Tag grammar, including grandfathered and private-use forms.
/// Registry membership and preferred spelling are distinct from well-formedness.
fn valid_language(s : String) -> Bool {
  let s = s.to_lower()
  if [
      "en-gb-oed", "i-ami", "i-bnn", "i-default", "i-enochian", "i-hak", "i-klingon",
      "i-lux", "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay", "i-tsu", "sgn-be-fr",
      "sgn-be-nl", "sgn-ch-de", "art-lojban", "cel-gaulish", "no-bok", "no-nyn",
      "zh-guoyu", "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang",
    ].contains(s) {
    return true
  }
  let t = s.split("-").map(fn(x) { x.to_owned() }).to_array()
  if t.any(fn(x) { x.length() < 1 || x.length() > 8 || !ascii_alnum(x) }) {
    return false
  }
  if t[0] == "x" {
    return t.length() > 1
  }
  if t[0].length() < 2 || !ascii_letters(t[0]) {
    return false
  }
  let mut i = 1
  if t[0].length() <= 3 {
    let mut n = 0
    while i < t.length() && t[i].length() == 3 && ascii_letters(t[i]) && n < 3 {
      i = i + 1
      n = n + 1
    }
  }
  if i < t.length() && t[i].length() == 4 && ascii_letters(t[i]) {
    i = i + 1
  }
  if i < t.length() &&
    (
      (t[i].length() == 2 && ascii_letters(t[i])) ||
      (t[i].length() == 3 && ascii_digits(t[i]))
    ) {
    i = i + 1
  }
  let variants : Map[String, Bool] = Map([])
  while i < t.length() &&
        (
          t[i].length() >= 5 ||
          (t[i].length() == 4 && t[i][0] >= 48 && t[i][0] <= 57)
        ) {
    if variants.contains(t[i]) {
      return false
    }
    variants.set(t[i], true)
    i = i + 1
  }
  let singletons : Map[String, Bool] = Map([])
  while i < t.length() {
    if t[i] == "x" {
      return i + 1 < t.length()
    }
    if t[i].length() != 1 || singletons.contains(t[i]) {
      return false
    }
    singletons.set(t[i], true)
    i = i + 1
    let start = i
    while i < t.length() && t[i].length() >= 2 {
      i = i + 1
    }
    if i == start {
      return false
    }
  }
  true
}

///|
fn mime_token(s : String) -> Bool {
  !s.is_empty() &&
  s
  .code_units()
  .all(fn(c) {
    c > 32 &&
    c < 127 &&
    ![40, 41, 60, 62, 64, 44, 59, 58, 92, 34, 47, 91, 93, 63, 61].contains(
      c.to_int(),
    )
  })
}

///|
fn valid_media_type(s : String) -> Bool {
  let mut i = 0
  while i < s.length() && s[i] != 59 && s[i] != 32 && s[i] != 9 {
    i = i + 1
  }
  let main = s[:i].split("/").map(fn(x) { x.to_owned() }).to_array()
  if main.length() != 2 || !media_name(main[0]) || !media_name(main[1]) {
    return false
  }
  while i < s.length() {
    while i < s.length() && (s[i] == 32 || s[i] == 9) {
      i = i + 1
    }
    if i == s.length() {
      return true
    }
    if s[i] != 59 {
      return false
    }
    i = i + 1
    while i < s.length() && (s[i] == 32 || s[i] == 9) {
      i = i + 1
    }
    let start = i
    while i < s.length() && s[i] != 61 {
      i = i + 1
    }
    if i == s.length() || !mime_token(s[start:i].to_owned()) {
      return false
    }
    i = i + 1
    if i < s.length() && s[i] == 34 {
      i = i + 1
      let mut closed = false
      while i < s.length() {
        if s[i] == 34 {
          i = i + 1
          closed = true
          break
        }
        if s[i] == 92 {
          i = i + 1
          if i == s.length() {
            return false
          }
        }
        if (s[i] < 32 && s[i] != 9) || s[i] == 127 || s[i] > 255 {
          return false
        }
        i = i + 1
      }
      if !closed {
        return false
      }
    } else {
      let start = i
      while i < s.length() && s[i] != 59 && s[i] != 32 && s[i] != 9 {
        i = i + 1
      }
      if !mime_token(s[start:i].to_owned()) {
        return false
      }
    }
  }
  true
}

///|
fn media_name(s : String) -> Bool {
  if !mime_token(s) {
    return false
  }
  if s.to_lower().has_prefix("x-") {
    return true
  }
  if s.length() > 127 || !ascii_alnum(s[:1].to_owned()) {
    return false
  }
  s
  .code_units()
  .all(fn(c) {
    (c >= 65 && c <= 90) ||
    (c >= 97 && c <= 122) ||
    (c >= 48 && c <= 57) ||
    "!#$&-^_.+".code_units().contains(c)
  })
}

///|
/// RFC media type names/parameter names ignore case; ordinary parameter values
/// do not. Normalize quoting and parameter order for translation identity.
fn media_identity(s : String) -> String {
  if !valid_media_type(s) {
    return s
  }
  let mut i = 0
  while i < s.length() && s[i] != 59 && s[i] != 32 && s[i] != 9 {
    i = i + 1
  }
  let base = s[:i].to_owned().to_lower()
  let parameters : Array[(String, String)] = []
  while i < s.length() {
    while i < s.length() && (s[i] == 32 || s[i] == 9 || s[i] == 59) {
      i = i + 1
    }
    if i == s.length() {
      break
    }
    let start = i
    while i < s.length() && s[i] != 61 {
      i = i + 1
    }
    let name = s[start:i].to_owned().to_lower()
    i = i + 1
    let value = StringBuilder()
    if s[i] == 34 {
      i = i + 1
      while s[i] != 34 {
        if s[i] == 92 {
          i = i + 1
        }
        let start = i
        i = i + 1
        value.write_string(s[start:i].to_owned())
      }
      i = i + 1
    } else {
      let start = i
      while i < s.length() && s[i] != 59 && s[i] != 32 && s[i] != 9 {
        i = i + 1
      }
      value.write_string(s[start:i].to_owned())
    }
    let value = value.to_string()
    parameters.push(
      (name, if name == "charset" { value.to_lower() } else { value }),
    )
  }
  parameters.sort_by(fn(a, b) {
    let n = a.0.compare(b.0)
    if n == 0 {
      a.1.compare(b.1)
    } else {
      n
    }
  })
  base +
  Json::array(
    parameters.map(fn(p) { Json::array([Json::string(p.0), Json::string(p.1)]) }),
  ).stringify()
}

///|
fn hex_digit(c : UInt16) -> Int32 {
  if c >= 48 && c <= 57 {
    c.to_int() - 48
  } else if c >= 65 && c <= 70 {
    c.to_int() - 55
  } else if c >= 97 && c <= 102 {
    c.to_int() - 87
  } else {
    -1
  }
}

///|
fn valid_uri_reference(s : String) -> Bool {
  let mut i = 0
  while i < s.length() {
    let c = s[i]
    if c == 37 {
      if i + 2 >= s.length() ||
        hex_digit(s[i + 1]) < 0 ||
        hex_digit(s[i + 2]) < 0 {
        return false
      }
      i = i + 3
    } else {
      if !((c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        "-._~:/?#[]@!$&'()*+,;=".code_units().contains(c)) {
        return false
      }
      i = i + 1
    }
  }
  let fragments = s.split("#").to_array()
  if fragments.length() > 2 {
    return false
  }
  if fragments.length() == 2 &&
    (fragments[1].contains("[") || fragments[1].contains("]")) {
    return false
  }
  let queries = fragments[0].split("?").to_array()
  for q = 1; q < queries.length(); q = q + 1 {
    if queries[q].contains("[") || queries[q].contains("]") {
      return false
    }
  }
  let pre = fragments[0].split("?").to_array()[0].to_owned()
  let mut rest = pre
  let first = pre.split("/").to_array()[0].to_owned()
  if first.split_once(":") is Some((scheme, _)) {
    if scheme.is_empty() ||
      !ascii_letters(scheme[:1].to_owned()) ||
      !scheme
      .code_units()
      .all(fn(c) {
        (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        c == 43 ||
        c == 45 ||
        c == 46
      }) {
      return false
    }
    rest = pre[scheme.length() + 1:].to_owned()
  }
  if rest.has_prefix("//") {
    let authority = rest[2:].split("/").to_array()[0].to_owned()
    let hostport = authority.split("@").to_array()
    if hostport.length() > 2 {
      return false
    }
    if hostport.length() == 2 &&
      (hostport[0].contains("[") || hostport[0].contains("]")) {
      return false
    }
    let host = hostport[hostport.length() - 1].to_owned()
    if host.has_prefix("[") {
      guard host.split_once("]") is Some((ip, port)) else { return false }
      if !(port == "" ||
        (
          port.has_prefix(":") &&
          (port.length() == 1 || ascii_digits(port[1:].to_owned()))
        )) {
        return false
      }
      if !valid_ip_literal(ip[1:].to_owned()) {
        return false
      }
    } else {
      if host.contains("[") || host.contains("]") {
        return false
      }
      let parts = host.split(":").to_array()
      if parts.length() > 2 ||
        (
          parts.length() == 2 &&
          parts[1] != "" &&
          !ascii_digits(parts[1].to_owned())
        ) {
        return false
      }
    }
  } else if rest.contains("[") || rest.contains("]") {
    return false
  }
  true
}

///|
fn valid_ip_literal(s : String) -> Bool {
  if s.has_prefix("v") || s.has_prefix("V") {
    guard s.split_once(".") is Some((version, tail)) else { return false }
    return version.length() > 1 &&
      version[1:].code_units().all(fn(c) { hex_digit(c) >= 0 }) &&
      !tail.is_empty() &&
      tail
      .code_units()
      .all(fn(c) {
        c != 37 &&
        c != 91 &&
        c != 93 &&
        c != 64 &&
        c != 47 &&
        c != 63 &&
        c != 35
      })
  }
  let parts = s.split(":").map(fn(x) { x.to_owned() }).to_array()
  if s.contains(":::") ||
    (s.has_prefix(":") && !s.has_prefix("::")) ||
    (s.has_suffix(":") && !s.has_suffix("::")) ||
    s.split("::").to_array().length() > 2 {
    return false
  }
  let mut n = 0
  for i, p in parts {
    if p == "" {
      continue
    }
    if p.contains(".") {
      if i != parts.length() - 1 {
        return false
      }
      let ipv4 = p.split(".").map(fn(x) { x.to_owned() }).to_array()
      if ipv4.length() != 4 ||
        ipv4.any(fn(x) {
          !small_number(x, 255) || (x.length() > 1 && x.has_prefix("0"))
        }) {
        return false
      }
      n = n + 2
    } else {
      if p.length() > 4 || !p.code_units().all(fn(c) { hex_digit(c) >= 0 }) {
        return false
      }
      n = n + 1
    }
  }
  if s.contains("::") {
    n < 8
  } else {
    n == 8
  }
}

///|
fn valid_file_path(s : String) -> Bool {
  if s == "" ||
    s
    .code_units()
    .any(fn(c) {
      c <= 32 ||
      c == 127 ||
      [92, 34, 60, 62, 94, 96, 123, 124, 125].contains(c.to_int())
    }) {
    return false
  }
  let decoded = StringBuilder()
  let mut i = 0
  while i < s.length() {
    if s[i] == 37 {
      if i + 2 >= s.length() ||
        hex_digit(s[i + 1]) < 0 ||
        hex_digit(s[i + 2]) < 0 {
        return false
      }
      let c = hex_digit(s[i + 1]) * 16 + hex_digit(s[i + 2])
      if c <= 8 ||
        c == 11 ||
        c == 12 ||
        (c >= 14 && c <= 31) ||
        c == 127 ||
        c == 92 {
        return false
      }
      if c == 194 && i + 5 < s.length() && s[i + 3] == 37 {
        let next = hex_digit(s[i + 4]) * 16 + hex_digit(s[i + 5])
        if next >= 128 && next <= 159 {
          return false
        }
      }
      decoded.write_string(if c == 46 { "." } else { "x" })
      i = i + 3
    } else {
      decoded.write_string(s[i:i + 1].to_owned())
      i = i + 1
    }
  }
  let first = s.split("/").to_array()[0]
  if first.contains(":") {
    guard s.split_once(":") is Some((scheme, rest)) else { return false }
    let scheme = scheme.to_owned().to_lower()
    if !["http", "https", "ftp", "file"].contains(scheme) ||
      !rest.has_prefix("//") {
      return false
    }
    let authority = rest[2:].split("/").to_array()[0]
    if scheme != "file" && authority == "" {
      return false
    }
    let host_and_query = authority.split("?").to_array()[0]
    .split("#")
    .to_array()[0].to_owned()
    let pieces = host_and_query.split("@").to_array()
    if pieces.length() > 2 {
      return false
    }
    let host = pieces[pieces.length() - 1].to_owned()
    if host.has_prefix("[") {
      guard host.split_once("]") is Some((ip, port)) else { return false }
      if !valid_ip_literal(ip[1:].to_owned()) {
        return false
      }
      if port != "" &&
        (!port.has_prefix(":") || !small_number(port[1:].to_owned(), 65535)) {
        return false
      }
    } else {
      if host.contains("[") || host.contains("]") {
        return false
      }
      let ps = host.split(":").to_array()
      if ps.length() > 2 ||
        (
          ps.length() == 2 &&
          ps[1] != "" &&
          !small_number(ps[1].to_owned(), 65535)
        ) {
        return false
      }
      if scheme != "file" && ps[0] == "" {
        return false
      }
    }
    return true
  }
  !s.has_prefix("/") &&
  !s.contains("?") &&
  !s.contains("#") &&
  !decoded.to_string().split("/").any(fn(x) { x == ".." })
}

///|
fn valid_coordinate(s : String, latitude : Bool) -> Bool {
  if s.length() < 2 {
    return false
  }
  let dir = s[0]
  if latitude && dir != 78 && dir != 83 && dir != 110 && dir != 115 {
    return false
  }
  if !latitude && dir != 69 && dir != 87 && dir != 101 && dir != 119 {
    return false
  }
  let p = s[1:].split(".").map(fn(x) { x.to_owned() }).to_array()
  let max = if latitude { 90 } else { 180 }
  if p.length() > 2 ||
    p[0].length() > (if latitude { 2 } else { 3 }) ||
    !small_number(p[0], max) {
    return false
  }
  if p.length() == 2 {
    if !ascii_digits(p[1]) {
      return false
    }
    let n = @string.parse_int(p[0][:]) catch { _ => return false }
    if n == max && p[1].code_units().any(fn(c) { c != 48 }) {
      return false
    }
  }
  true
}
