import bear/error.{Validation}
import bear/monitors/config.{type Config}
import gleam/dynamic
import gleam/json
import validates

pub type Status {
  Up
  Down
  Paused
  New
}

pub type Kind {
  Healthcheck
  Heartbeat
}

pub type Monitor {
  Monitor(
    id: Int,
    team_id: Int,
    name: String,
    kind: Kind,
    tags: List(String),
    config: Config,
  )
}

pub type State {
  State(id: Int, status: Status)
}

pub fn new() {
  Monitor(
    id: 0,
    team_id: 0,
    name: "",
    kind: Healthcheck,
    tags: [],
    config: config.new(),
  )
}

pub fn validate(monitor: Monitor) {
  validates.rules()
  |> validates.add(
    validates.string("name", monitor.name)
    |> validates.required(),
  )
  |> validates.add(
    validates.string("config.url", monitor.config.url)
    |> validates.required(),
  )
  |> validates.add(
    validates.string("config.url", monitor.config.url)
    |> validates.url(),
  )
  |> validates.result_map_error(monitor, Validation)
}

pub fn to_json(monitor: Monitor) {
  json.object([
    #("id", json.int(monitor.id)),
    #("team_id", json.int(monitor.team_id)),
    #("name", json.string(monitor.name)),
    #("kind", kind_to_json(monitor.kind)),
    #("tags", json.array(monitor.tags, json.string)),
    #("config", config.to_json(monitor.config)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode6(
    Monitor,
    dynamic.field("id", dynamic.int),
    dynamic.field("team_id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("kind", kind_decoder),
    dynamic.field("tags", dynamic.list(dynamic.string)),
    dynamic.field("config", config.decoder),
  )(dynamic)
}

pub fn kind_to_string(kind: Kind) {
  case kind {
    Healthcheck -> "healthcheck"
    Heartbeat -> "hearbeat"
  }
}

pub fn kind_to_json(kind: Kind) {
  json.string(kind_to_string(kind))
}

pub fn kind_decoder(dynamic) {
  case dynamic.string(dynamic) {
    Error(error) -> Error(error)
    Ok("hearbeat") -> Ok(Heartbeat)
    Ok(_) -> Ok(Healthcheck)
  }
}
