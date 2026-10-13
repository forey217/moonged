///|
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, @debug.Debug)

///|
pub extend Severity with Eq::{equal, not_equal}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
pub struct Diagnostic {
  severity : Severity
  code : String
  line : Int
  related_line : Int?
  message : String
} derive(Eq, @debug.Debug)

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
fn diagnostic(
  code : String,
  line : Int,
  message : String,
  severity? : Severity = Error,
  related_line? : Int,
) -> Diagnostic {
  { severity, code, line, related_line, message, }
}

///|
fn target_record(tag : String) -> String? {
  match tag {
    "FAMC" | "FAMS" => Some("FAM")
    "HUSB" | "WIFE" | "CHIL" | "ASSO" | "ALIA" => Some("INDI")
    "SUBM" => Some("SUBM")
    "SOUR" => Some("SOUR")
    "SNOTE" => Some("SNOTE")
    "REPO" => Some("REPO")
    "OBJE" => Some("OBJE")
    _ => None
  }
}

///|
fn pointer_required(tag : String) -> Bool {
  ["FAMC", "FAMS", "HUSB", "WIFE", "CHIL", "ASSO", "ALIA", "SUBM", "SNOTE"].contains(
    tag,
  )
}

///|
/// Selected interchange checks, not a complete GEDCOM schema validator.
/// Unknown structures remain in the document and are never discarded here.
pub fn audit(doc : Document) -> Array[Diagnostic] {
  let out = []
  let first = doc.nodes[doc.records[0]]
  let last = doc.nodes[doc.records[doc.records.length() - 1]]
  if first.tag != "HEAD" {
    out.push(
      diagnostic("missing-header", first.line, "first record must be HEAD"),
    )
  }
  if last.tag != "TRLR" {
    out.push(
      diagnostic("missing-trailer", last.line, "last record must be TRLR"),
    )
  }
  let seen : Map[String, Int] = Map([])
  let declared : Map[String, Bool] = Map([])
  if first.tag == "HEAD" {
    let gedc = doc.select(0, "GEDC")
    if gedc.length() != 1 {
      out.push(
        diagnostic(
          "header-version",
          first.line,
          "HEAD requires exactly one GEDC",
        ),
      )
    } else {
      let vers = doc.select(gedc[0], "VERS")
      if vers.length() != 1 || doc.nodes[vers[0]].payload != Text("7.0") {
        out.push(
          diagnostic(
            "unsupported-version",
            doc.nodes[gedc[0]].line,
            "only GEDCOM 7.0 UTF-8 text is supported",
          ),
        )
      }
    }
    for schma in doc.select(0, "SCHMA") {
      for index in doc.select(schma, "TAG") {
        match doc.nodes[index].payload {
          Text(s) => {
            let parts = s.split(" ").to_array()
            if parts.length() == 2 &&
              valid_tag(parts[0].to_owned()) &&
              parts[0].has_prefix("_") &&
              (
                parts[1].has_prefix("https://") ||
                parts[1].has_prefix("http://")
              ) {
              let tag = parts[0].to_owned()
              if declared.get(tag) != None {
                out.push(
                  diagnostic(
                    "duplicate-schema-tag",
                    doc.nodes[index].line,
                    "extension tag is declared more than once",
                  ),
                )
              }
              declared.set(tag, true)
            } else {
              out.push(
                diagnostic(
                  "schema-tag",
                  doc.nodes[index].line,
                  "SCHMA.TAG requires an extension tag and a documented URI",
                ),
              )
            }
          }
          _ =>
            out.push(
              diagnostic(
                "schema-tag",
                doc.nodes[index].line,
                "SCHMA.TAG requires text",
              ),
            )
        }
      }
    }
  }
  let mut headers = 0
  let mut trailers = 0
  for i, node in doc.nodes {
    if node.level == 0 {
      if node.tag == "HEAD" {
        headers = headers + 1
      }
      if node.tag == "TRLR" {
        trailers = trailers + 1
      }
      if node.tag == "HEAD" && i != 0 {
        out.push(diagnostic("header-order", node.line, "HEAD must be first"))
      }
      if node.tag == "TRLR" && i != doc.nodes.length() - 1 {
        out.push(
          diagnostic(
            "trailer-order",
            node.line,
            "TRLR must be last and have no children",
          ),
        )
      }
      if [
          "HEAD", "TRLR", "INDI", "FAM", "OBJE", "REPO", "SNOTE", "SOUR", "SUBM",
        ].contains(node.tag) ==
        false &&
        !node.tag.has_prefix("_") {
        out.push(
          diagnostic(
            "unknown-record",
            node.line,
            "unrecognized standard record tag " + node.tag,
            severity=Warning,
          ),
        )
      }
    } else if node.tag == "HEAD" || node.tag == "TRLR" {
      out.push(
        diagnostic(
          "pseudo-structure-level",
          node.line,
          "HEAD and TRLR must be records",
        ),
      )
    }
    if node.tag == "HEAD" || node.tag == "TRLR" {
      if node.payload != Empty || node.xref != None {
        out.push(
          diagnostic(
            "pseudo-structure-payload",
            node.line,
            "HEAD/TRLR cannot have payloads or ids",
          ),
        )
      }
    } else if node.payload == Empty && doc.children(i).length() == 0 {
      out.push(
        diagnostic(
          "empty-structure",
          node.line,
          "structure requires a payload or substructure",
        ),
      )
    }
    if node.tag == "CONC" {
      out.push(
        diagnostic("legacy-conc", node.line, "CONC is not part of GEDCOM 7"),
      )
    }
    if node.tag.has_prefix("_") && declared.get(node.tag) == None {
      out.push(
        diagnostic(
          "undeclared-extension",
          node.line,
          "extension retained without HEAD.SCHMA declaration",
          severity=Warning,
        ),
      )
    }
    if node.xref is Some(id) {
      match seen.get(id) {
        Some(previous) =>
          out.push(
            diagnostic(
              "duplicate-id",
              node.line,
              "duplicate identifier @" + id + "@",
              related_line=doc.nodes[previous].line,
            ),
          )
        None => seen.set(id, i)
      }
    }
    if pointer_required(node.tag) &&
      !(node.payload is Pointer(_)) &&
      node.payload != Void {
      out.push(
        diagnostic(
          "pointer-payload",
          node.line,
          node.tag + " requires a pointer or @VOID@",
        ),
      )
    }
    if node.payload is Pointer(id) {
      match doc.ids.get(id) {
        None =>
          out.push(
            diagnostic(
              "dangling-pointer",
              node.line,
              "no target for @" + id + "@",
            ),
          )
        Some(target) =>
          if target_record(node.tag) is Some(expected) &&
            (doc.nodes[target].tag != expected || doc.nodes[target].level != 0) {
            out.push(
              diagnostic(
                "pointer-type",
                node.line,
                node.tag + " must point to a " + expected + " record",
                related_line=doc.nodes[target].line,
              ),
            )
          }
      }
    }
    if node.tag == "FAM" && node.level == 0 {
      for tag in ["HUSB", "WIFE"] {
        let links = doc.select(i, tag)
        if links.length() > 1 {
          out.push(
            diagnostic(
              "family-cardinality",
              doc.nodes[links[1]].line,
              "FAM may have at most one " + tag,
            ),
          )
        }
      }
      let links : Map[String, Int] = Map([])
      for index in doc.children(i) {
        let child = doc.nodes[index]
        if ["HUSB", "WIFE", "CHIL"].contains(child.tag) &&
          child.payload is Pointer(id) {
          let key = child.tag + "@" + id
          if links.get(key) is Some(prior) {
            out.push(
              diagnostic(
                "duplicate-family-link",
                child.line,
                "duplicate " + child.tag + " link",
                related_line=doc.nodes[prior].line,
              ),
            )
          } else {
            links.set(key, index)
          }
        }
      }
    }
  }
  if headers != 1 {
    out.push(
      diagnostic(
        "header-count",
        first.line,
        "document must contain exactly one HEAD",
      ),
    )
  }
  if trailers != 1 {
    out.push(
      diagnostic(
        "trailer-count",
        last.line,
        "document must contain exactly one TRLR",
      ),
    )
  }
  out
}

///|
pub fn has_errors(diagnostics : Array[Diagnostic]) -> Bool {
  diagnostics.any(fn(d) { d.severity == Error })
}
