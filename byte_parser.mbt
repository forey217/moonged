///|
/// Feed arbitrary byte chunks, including splits inside a UTF-8 sequence or BOM.
/// Only the unfinished physical line is buffered, within configured limits.
pub struct ByteParser {
  priv parser : Parser
  priv pending : @buffer.Buffer
  priv mut after_cr : Bool
  priv mut closed : Bool
  priv mut failed : Bool
  priv mut total_bytes : Int64
}

///|
pub fn ByteParser::new(limits? : Limits) -> ByteParser raise GedError {
  {
    parser: Parser::new(limits?),
    pending: @buffer.Buffer(),
    after_cr: false,
    closed: false,
    failed: false,
    total_bytes: 0L,
  }
}

///|
fn ByteParser::line(self : ByteParser, eol_units : Int) -> Unit raise GedError {
  let line = @utf8.decode(self.pending.to_bytes(), ignore_bom=false) catch {
    _ => raise Syntax(self.parser.line + 1, "invalid UTF-8")
  }
  if line.length().to_int64() + eol_units.to_int64() >
    (self.parser.limits.max_total_units - self.parser.total).to_int64() {
    raise Limit("decoded input size exceeded")
  }
  self.parser.total = self.parser.total + line.length() + eol_units
  self.pending.reset()
  if line.length() > self.parser.limits.max_line_units {
    raise Limit("line size exceeded")
  }
  self.parser.take_line(line)
}

///|
pub fn ByteParser::feed(
  self : ByteParser,
  chunk : BytesView,
) -> Unit raise GedError {
  if self.closed || self.failed {
    raise InvalidState("byte parser is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  self.total_bytes = self.total_bytes + chunk.length().to_int64()
  if self.total_bytes > self.parser.limits.max_total_units.to_int64() * 4L {
    raise Limit("byte input size exceeded")
  }
  for b in chunk {
    if self.after_cr {
      self.after_cr = false
      if b == b'\n' {
        if self.parser.total >= self.parser.limits.max_total_units {
          raise Limit("decoded input size exceeded")
        }
        self.parser.total = self.parser.total + 1
        continue
      }
    }
    if b == b'\n' || b == b'\r' {
      self.line(1)
      self.after_cr = b == b'\r'
    } else {
      if self.pending.length().to_int64() >=
        self.parser.limits.max_line_units.to_int64() * 4L {
        raise Limit("unfinished UTF-8 line size exceeded")
      }
      self.pending.write_byte(b)
    }
  }
}

///|
pub fn ByteParser::finish(self : ByteParser) -> Document raise GedError {
  if self.closed || self.failed {
    raise InvalidState("byte parser is closed or failed")
  }
  self.closed = true
  if self.pending.length() > 0 {
    self.line(0)
  }
  self.parser.finish()
}
