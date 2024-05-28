import bear/monitors/assertion.{type AssertionResult}
import gleam/dynamic
import gleam/json
import gleam/option.{Some}
import gleam/string

pub type Report {
  Report(
    region: String,
    status: Int,
    healthy: Bool,
    runtime: Int,
    message: String,
    body: String,
    assertions: List(AssertionResult),
  )
}

pub fn new() -> Report {
  Report(
    region: "",
    status: 0,
    healthy: True,
    runtime: 0,
    message: "",
    body: "",
    assertions: [],
  )
}

pub fn region(report: Report, region: String) -> Report {
  Report(..report, region: region)
}

pub fn healthy(report: Report, healthy: Bool) -> Report {
  Report(..report, healthy: healthy)
}

pub fn status(report: Report, code: Int) -> Report {
  Report(..report, status: code)
}

pub fn runtime(report: Report, ms: Int) -> Report {
  Report(..report, runtime: ms)
}

pub fn message(report: Report, message: String) -> Report {
  Report(..report, message: message)
}

pub fn body(report: Report, body: String) -> Report {
  Report(..report, body: string.slice(body, 0, 500))
}

pub fn assertions(report: Report, assertions: List(AssertionResult)) -> Report {
  Report(..report, assertions: assertions)
}

pub fn to_json(report: Report) {
  json.object([
    #("region", json.string(report.region)),
    #("status", json.int(report.status)),
    #("healthy", json.bool(report.healthy)),
    #("runtime", json.int(report.runtime)),
    #("message", json.string(report.message)),
    #("body", json.string(report.body)),
    #(
      "assertions",
      json.array(report.assertions, assertion.assertion_result_to_json),
    ),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode7(
    Report,
    dynamic.field("region", dynamic.string),
    dynamic.field("status", dynamic.int),
    dynamic.field("healthy", dynamic.bool),
    dynamic_default("runtime", dynamic.int, 0),
    dynamic_default("message", dynamic.string, ""),
    dynamic_default("body", dynamic.string, ""),
    dynamic_default(
      "assertions",
      dynamic.list(assertion.assertion_result_decoder),
      [],
    ),
  )(dynamic)
}

fn dynamic_default(name, decoder, default) {
  fn(dynamic) {
    case dynamic.optional_field(name, decoder)(dynamic) {
      Ok(Some(i)) -> Ok(i)
      _ -> Ok(default)
    }
  }
}
