import bear/monitors/metrics.{type Metrics}
import bear/monitors/status.{type Status, New}
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option.{type Option, None}

pub type State {
  State(
    id: Int,
    status: Status,
    missed: Int,
    recovered: Int,
    events: Int,
    checking: Bool,
    next_check_at: Option(String),
    next_region: Option(String),
    metrics: Metrics,
  )
}

pub fn new() -> State {
  State(
    id: 0,
    status: New,
    missed: 0,
    recovered: 0,
    events: 0,
    checking: False,
    next_check_at: None,
    next_region: None,
    metrics: metrics.new(),
  )
}

pub fn to_json(state: State) {
  json.object([
    #("id", json.int(state.id)),
    #("status", status.to_json(state.status)),
    #("missed", json.int(state.missed)),
    #("recovered", json.int(state.recovered)),
    #("events", json.int(state.events)),
    #("checking", json.bool(state.checking)),
    #("next_check_at", json.nullable(state.next_check_at, json.string)),
    #("next_region", json.nullable(state.next_region, json.string)),
    #("metrics", metrics.to_json(state.metrics)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode9(
    State,
    dynamic.field("id", dynamic.int),
    dynamic.field("status", status.decoder),
    dynamic.field("missed", dynamic.int),
    dynamic.field("recovered", dynamic.int),
    dynamic.field("events", dynamic.int),
    dynamic.field("checking", dynamic.bool),
    dynamic.field("next_check_at", dynamic.optional(dynamic.string)),
    dynamic.field("next_region", dynamic.optional(dynamic.string)),
    dynamic.field("metrics", metrics.decoder),
  )(dynamic)
}

pub fn state_name(state: State) {
  case state.status, state.missed, state.recovered {
    status.Up, missed, _ if missed > 0 -> "missed"
    status.Down, _, recovered if recovered > 0 -> "recovering"
    _, _, _ -> status.to_string(state.status)
  }
}

pub fn overall_state_name(states: List(State)) {
  list.fold(states, "up", fn(status: String, state: State) {
    case status, state_name(state) {
      _, "down" -> "down"
      _, "missed" -> "missed"
      _, "recovering" -> "recovering"
      acc, _ -> acc
    }
  })
}
