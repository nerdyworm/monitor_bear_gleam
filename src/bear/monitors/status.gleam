import gleam/dynamic
import gleam/json

pub type Status {
  Up
  Down
  Paused
  New
}

pub fn to_json(status: Status) {
  to_string(status)
  |> json.string()
}

pub fn to_string(status: Status) {
  case status {
    Up -> "up"
    Down -> "down"
    Paused -> "paused"
    New -> "new"
  }
}

pub fn decoder(dynamic) {
  case dynamic.string(dynamic) {
    Ok("up") -> Up
    Ok("down") -> Down
    Ok("paused") -> Paused
    Ok("new") -> New
    _ -> Up
  }
  |> Ok
}

pub fn from_string(status: String) -> Status {
  case status {
    "up" -> Up
    "down" -> Down
    "paused" -> Paused
    "new" -> New
    _ -> Up
  }
}
