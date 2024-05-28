import bear/utils
import gleam/dynamic.{type Dynamic}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/string

// checks will check against the reponse of the http request
// heartbeats will check against the input of the httprequ
pub type Source {
  Response(String)
  MetricsRuntime
}

pub type HealthcheckResponse {
  HealthcheckResponse(response: Response(String), time: Int)
}

pub type AssertionResult {
  AssertionResult(assertion: Assertion, result: Bool)
}

pub type Op {
  LTE
  LT
  EQ
  NEQ
  GT
  GTE
  Contains
  DoesNotContain
}

pub type Assertion {
  Assertion(id: String, source: Source, op: Op, value: String)
}

pub fn new() {
  new_assertion_with_id(utils.make_id())
}

pub fn new_check_defaults() -> List(Assertion) {
  [
    Assertion(id: "1", source: Response("status"), op: EQ, value: "200"),
    Assertion(id: "2", source: Response("time"), op: LT, value: "2000"),
    Assertion(id: "3", source: Response("body"), op: Contains, value: ""),
  ]
}

pub fn new_assertion_with_id(id) {
  Assertion(id: id, source: Response("status"), op: EQ, value: "")
}

pub fn source_from_string(string: String) {
  case string {
    "metrics_runtime" -> MetricsRuntime
    "response." <> rest -> Response(rest)
    _ -> Response("status")
  }
}

pub fn source_to_string(source: Source) {
  case source {
    Response(name) -> "response." <> name
    MetricsRuntime -> "metric_runtime"
  }
}

pub fn op_from_string(string: String) {
  case string {
    "contains" -> Contains
    "!contains" -> DoesNotContain
    "==" -> EQ
    "!=" -> NEQ
    ">" -> GT
    ">=" -> GTE
    "<" -> LT
    "<=" -> LTE
    _ -> EQ
  }
}

pub fn op_to_string(op: Op) {
  case op {
    LTE -> "<="
    LT -> "<"
    EQ -> "=="
    NEQ -> "!="
    GT -> ">"
    GTE -> ">="
    Contains -> "contains"
    DoesNotContain -> "!contains"
  }
}

pub fn add(to: List(Assertion), new: Assertion) -> List(Assertion) {
  list.append(to, [new])
}

pub fn remove(from: List(Assertion), remove: Assertion) -> List(Assertion) {
  list.filter(from, fn(r: Assertion) { r.id != remove.id })
}

pub fn replace(assertions: List(Assertion), updated: Assertion) {
  list.map(assertions, fn(assertion) {
    case assertion {
      _ if assertion.id == updated.id -> updated
      _ -> assertion
    }
  })
}

fn compare_int(op: Op, left: Int, right: Int) -> Bool {
  case op {
    LTE -> left <= right
    LT -> left < right
    EQ -> left == right
    NEQ -> left != right
    GT -> left > right
    GTE -> left >= right
    Contains -> False
    DoesNotContain -> False
  }
}

pub fn to_json(assertion: Assertion) {
  json.object([
    #("id", json.string(assertion.id)),
    #("source", json.string(source_to_string(assertion.source))),
    #("op", json.string(op_to_string(assertion.op))),
    #("value", json.string(assertion.value)),
  ])
}

pub fn decoder(dynamic: Dynamic) {
  dynamic.decode4(
    Assertion,
    dynamic.field("id", dynamic.string),
    dynamic.field("source", fn(dynamic) {
      case dynamic.string(dynamic) {
        Ok(source) -> Ok(source_from_string(source))
        Error(error) -> Error(error)
      }
    }),
    dynamic.field("op", fn(dynamic) {
      case dynamic.string(dynamic) {
        Ok(source) -> Ok(op_from_string(source))
        Error(error) -> Error(error)
      }
    }),
    dynamic.field("value", dynamic.string),
  )(dynamic)
}

pub fn assertion_result_decoder(dynamic: Dynamic) {
  dynamic.decode2(
    AssertionResult,
    dynamic.field("assertion", decoder),
    dynamic.field("result", dynamic.bool),
  )(dynamic)
}

pub fn assertion_result_to_json(assertion: AssertionResult) {
  json.object([
    #("assertion", to_json(assertion.assertion)),
    #("result", json.bool(assertion.result)),
  ])
}

pub fn assert_response(
  response: HealthcheckResponse,
  assertions: List(Assertion),
) -> List(AssertionResult) {
  list.map(assertions, fn(assertion) { assert_response0(response, assertion) })
}

fn assert_response0(response: HealthcheckResponse, assertion: Assertion) {
  let result = case assertion {
    Assertion(id: _, source: Response("body"), op: Contains, value: value) -> {
      string.contains(response.response.body, value)
    }

    Assertion(id: _, source: Response("body"), op: DoesNotContain, value: value) -> {
      !string.contains(response.response.body, value)
    }

    Assertion(id: _, source: Response("status"), op: op, value: value) -> {
      case int.parse(value) {
        Ok(value) -> compare_int(op, response.response.status, value)
        _ -> False
      }
    }

    Assertion(id: _, source: Response("time"), op: op, value: value) -> {
      case int.parse(value) {
        Ok(value) -> compare_int(op, response.time, value)
        _ -> False
      }
    }

    Assertion(id: _, source: Response(_), op: _, value: _) -> {
      False
    }

    Assertion(id: _, source: _, op: _, value: _) -> {
      False
    }
  }

  AssertionResult(assertion, result)
}
