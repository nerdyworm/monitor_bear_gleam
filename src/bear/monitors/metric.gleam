import gleam/dynamic
import gleam/json

pub type Metric {
  Metric(monitor_id: Int, name: String, t: String, value: Int)
}

pub fn to_json(flip: Metric) {
  json.object([
    #("monitor_id", json.int(flip.monitor_id)),
    #("name", json.string(flip.name)),
    #("t", json.string(flip.t)),
    #("value", json.int(flip.value)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode4(
    Metric,
    dynamic.field("monitor_id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("t", dynamic.string),
    dynamic.field("value", dynamic.int),
  )(dynamic)
}
