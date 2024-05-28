import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option.{type Option, None}

pub type Metrics {
  Metrics(
    last_success_at: Option(String),
    last_error_at: Option(String),
    last_runtime_ms: Option(Int),
    runtimes: List(Int),
  )
}

pub fn new() {
  Metrics(
    last_success_at: None,
    last_error_at: None,
    last_runtime_ms: None,
    runtimes: [],
  )
}

pub fn to_json(metrics: Metrics) {
  json.object([
    #("last_success_at", json.nullable(metrics.last_success_at, json.string)),
    #("last_error_at", json.nullable(metrics.last_error_at, json.string)),
    #("last_runtime_ms", json.nullable(metrics.last_runtime_ms, json.int)),
    #("runtimes", json.array(metrics.runtimes, json.int)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode4(
    Metrics,
    dynamic.field("last_success_at", dynamic.optional(dynamic.string)),
    dynamic.field("last_error_at", dynamic.optional(dynamic.string)),
    dynamic.field("last_runtime_ms", dynamic.optional(dynamic.int)),
    dynamic.field("runtimes", dynamic.list(dynamic.int)),
  )(dynamic)
}

pub fn average_runtime(metrics: Metrics) {
  let not_zero = list.filter(metrics.runtimes, fn(n) { n > 0 })
  let count = list.length(not_zero)

  case count {
    count if count == 0 -> 0
    _ -> {
      let total = list.fold(not_zero, 0, fn(acc, ms) { ms + acc })
      total / count
    }
  }
}
