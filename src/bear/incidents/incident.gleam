import bear/error.{Validation}
import birl
import birl/duration
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import validates

pub type Status {
  Ongoing
  Resolved
}

pub type Incident {
  Incident(
    id: Int,
    team_id: Int,
    status: Status,
    started_at: String,
    resolved_at: Option(String),
    description: String,
    tags: List(String),
    monitor_ids: List(Int),
  )
}

pub fn new() {
  Incident(
    id: 0,
    team_id: 0,
    status: Ongoing,
    started_at: "NOw",
    resolved_at: None,
    description: "",
    tags: [],
    monitor_ids: [],
  )
}

pub fn validate(incident: Incident) {
  validates.rules()
  |> validates.result_map_error(incident, Validation)
}

pub fn to_json(incident: Incident) {
  json.object([
    #("id", json.int(incident.id)),
    #("team_id", json.int(incident.team_id)),
    #("status", json.string(status_to_string(incident.status))),
    #("started_at", json.string(incident.started_at)),
    #("resolved_at", json.nullable(incident.resolved_at, json.string)),
    #("description", json.string(incident.description)),
    #("tags", json.array(incident.tags, json.string)),
    #("monitor_ids", json.array(incident.monitor_ids, json.int)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode8(
    Incident,
    dynamic.field("id", dynamic.int),
    dynamic.field("team_id", dynamic.int),
    dynamic.field("status", status_decoder),
    dynamic.field("started_at", dynamic.string),
    dynamic.field("resolved_at", dynamic.optional(dynamic.string)),
    dynamic.field("description", dynamic.string),
    dynamic.field("tags", dynamic.list(dynamic.string)),
    dynamic.field("monitor_ids", dynamic.list(dynamic.int)),
  )(dynamic)
}

pub fn status_to_string(status: Status) {
  case status {
    Ongoing -> "ongoing"
    Resolved -> "resolved"
  }
}

pub fn status_decoder(dynamic) {
  case dynamic.string(dynamic) {
    Ok("resolved") -> Ok(Resolved)
    Ok(_) -> Ok(Ongoing)
    Error(error) -> Error(error)
  }
}

pub fn duration_to_string(incident: Incident) {
  case incident.resolved_at {
    None -> "Ongoing"
    Some(resolved_at) -> {
      let assert Ok(start) = birl.parse(incident.started_at <> "Z")
      let assert Ok(end) = birl.parse(resolved_at <> "Z")

      let seconds =
        birl.difference(end, start)
        |> duration.blur_to(duration.Second)

      seconds_to_human(seconds)
    }
  }
}

fn seconds_to_human(seconds: Int) -> String {
  case seconds {
    seconds if seconds < 60 -> int.to_string(seconds) <> " seconds"
    seconds -> int.to_string(seconds / 60) <> " minutes"
  }
}
