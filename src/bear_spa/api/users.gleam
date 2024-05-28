import bear/session.{type Session}
import bear_spa/api.{type ApiError}
import bear_spa/app.{type App}
import gleam/dynamic
import gleam/json

pub fn register_user(
  email: String,
  password: String,
  app: App,
  response: fn(Result(Session, ApiError)) -> msg,
) {
  api.post(
    "/users/register",
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ]),
    api.expect(session.decoder, response),
    app,
  )
}

pub fn create_session(email, password, app, response) {
  api.post(
    "/users/session",
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ]),
    api.expect(session.decoder, response),
    app,
  )
}

pub fn reset_password(token, password, app, response) {
  api.post(
    "/users/reset_password",
    json.object([
      #("token", json.string(token)),
      #("password", json.string(password)),
    ]),
    api.expect(session.decoder, response),
    app,
  )
}

pub fn create_password_reset(email, app, response) {
  api.post(
    "/users/reset_password_create",
    json.object([#("email", json.string(email))]),
    api.expect(dynamic.string, response),
    app,
  )
}
