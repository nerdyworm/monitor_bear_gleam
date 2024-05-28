import bear_spa/app.{type App}
import bear_spa/lib/pubsub
import gleam/http.{Delete, Post, Put}
import gleam/http/request
import gleam/json
import gleam/option.{None, Some}
import lustre_http.{type HttpError, OtherError, Unauthorized}
import validates.{type Errors}

pub type RemoteData(value, error) {
  Loading
  Done(Result(value, error))
}

pub type ApiError {
  Http(HttpError)
  Validation(List(Errors))
}

pub fn post(path, payload, expect, app: App) {
  let assert Ok(request) = request.to(app.endpoint <> path)

  case app.session {
    None -> request
    Some(session) -> request.set_header(request, "authorization", session.token)
  }
  |> request.set_header("content-type", "application/json")
  |> request.set_method(Post)
  |> request.set_body(json.to_string(payload))
  |> lustre_http.send(expect)
}

pub fn put(path, payload, expect, app: App) {
  let assert Ok(request) = request.to(app.endpoint <> path)

  case app.session {
    None -> request
    Some(session) -> request.set_header(request, "authorization", session.token)
  }
  |> request.set_header("content-type", "application/json")
  |> request.set_method(Put)
  |> request.set_body(json.to_string(payload))
  |> lustre_http.send(expect)
}

pub fn delete(path, payload, expect, app: App) {
  let assert Ok(request) = request.to(app.endpoint <> path)

  case app.session {
    None -> request
    Some(session) -> request.set_header(request, "authorization", session.token)
  }
  |> request.set_header("content-type", "application/json")
  |> request.set_method(Delete)
  |> request.set_body(json.to_string(payload))
  |> lustre_http.send(expect)
}

pub fn get(path, expect, app: App) {
  let assert Ok(request) = request.to(app.endpoint <> path)

  case app.session {
    None -> request
    Some(session) -> request.set_header(request, "Authorization", session.token)
  }
  |> request.set_header("content-type", "application/json")
  |> lustre_http.send(expect)
}

pub fn get2(path, decoder, to_msg, app: App) {
  let assert Ok(request) = request.to(app.endpoint <> path)
  case app.session {
    None -> request
    Some(session) -> request.set_header(request, "Authorization", session.token)
  }
  |> request.set_header("content-type", "application/json")
  |> lustre_http.send(expect2(app, decoder, to_msg))
}

pub fn expect2(app: App, decoder, response) {
  lustre_http.expect_json(decoder, fn(result) {
    case result {
      Ok(good) -> response(Ok(good))

      Error(OtherError(422, body)) -> {
        let assert Ok(errors) = json.decode(body, validates.decoder)
        response(Error(Validation(errors)))
      }

      Error(Unauthorized) -> {
        pubsub.publish(app.pubsub, app.SessionInvalid)
        response(Error(Http(Unauthorized)))
      }

      Error(any) -> {
        response(Error(Http(any)))
      }
    }
  })
}

pub fn expect(decoder, response) {
  lustre_http.expect_json(decoder, fn(result) {
    case result {
      Ok(good) -> response(Ok(good))

      Error(OtherError(422, body)) -> {
        let assert Ok(errors) = json.decode(body, validates.decoder)
        response(Error(Validation(errors)))
      }

      Error(any) -> response(Error(Http(any)))
    }
  })
}
