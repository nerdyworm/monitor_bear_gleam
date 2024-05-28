import bear/monitors/status.{type Status}
import gleam/dynamic
import gleam/json

pub type Flip {
  Flip(id: Int, monitor_id: Int, from: Status, to: Status, inserted_at: String)
}

pub fn to_json(flip: Flip) {
  json.object([
    #("id", json.int(flip.id)),
    #("monitor_id", json.int(flip.monitor_id)),
    #("from", status.to_json(flip.from)),
    #("to", status.to_json(flip.to)),
    #("inserted_at", json.string(flip.inserted_at)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode5(
    Flip,
    dynamic.field("id", dynamic.int),
    dynamic.field("monitor_id", dynamic.int),
    dynamic.field("from", status.decoder),
    dynamic.field("to", status.decoder),
    dynamic.field("inserted_at", dynamic.string),
  )(dynamic)
}
