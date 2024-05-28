import bear/error.{type BearError}
import gleam/json
import gleam/string
import validates
import wisp.{type Response}

pub fn respond(result: Result(kind, BearError), to_json) -> Response {
  case result {
    Ok(thing) -> json(to_json(thing), 200)
    Error(err) -> error(err)
  }
}

pub fn json(json: json.Json, status: Int) -> Response {
  json
  |> json.to_string_builder()
  |> wisp.json_response(status)
}

pub fn error(error: BearError) -> Response {
  case error {
    error.Validation(errors) -> {
      validates.to_json(errors)
      |> json.to_string_builder()
      |> wisp.json_response(422)
    }

    error -> {
      json.object([#("message", json.string(string.inspect(error)))])
      |> json.to_string_builder()
      |> wisp.json_response(500)
    }
  }
}
