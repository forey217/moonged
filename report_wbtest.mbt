///|
test "CSV quotes commas quotes newlines and guards spreadsheet formulas" {
  let doc = parse(
    "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 NAME =1+1,\"x\"\n2 CONT second line\n0 TRLR\n",
  )
  let safe = people_csv(doc)
  assert_true(safe.contains("\"'=1+1,\"\"x\"\"\nsecond line\""))
  assert_true(people_csv(doc, spreadsheet_safe=false).contains("\"=1+1,"))
}

///|
test "host protocol reports malformed syntax without injection or abort" {
  let result = @json.parse(
    run_json("{\"command\":\"inspect\",\"text\":\"bad\"}"),
  )
  guard result is Object(o) else { fail("expected JSON object") }
  assert_eq(o.get("ok"), Some(Json::boolean(false)))
  assert_eq(o.get("line"), Some(Json::number(1)))
  assert_true(run_json("not-json").contains("invalid_request"))
}

///|
test "host inspection distinguishes selected validation from parse success" {
  let request = Json::object(
    Map([
      ("command", Json::string("inspect")),
      (
        "text",
        Json::string(
          "0 HEAD\n1 GEDC\n2 VERS 7.0\n0 @I1@ INDI\n1 FAMC @MISSING@\n0 TRLR\n",
        ),
      ),
    ]),
  ).stringify()
  let response = run_json(request)
  assert_true(response.contains("\"ok\":true"))
  assert_true(response.contains("\"valid\":false"))
  assert_true(response.contains("dangling-pointer"))
}
