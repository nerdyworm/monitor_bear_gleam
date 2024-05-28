import bear/config
import bear/mailer
import bear/registration
import bear/session
import bear/users
import bear/users/user.{type User}
import bear_server/render
import gleam/dynamic
import gleam/json
import lib/email
import lustre/attribute
import lustre/element
import lustre/element/html
import wisp.{type Request, type Response}

pub fn register(req: Request) -> Response {
  use params <- wisp.require_json(req)
  let assert Ok(email) = dynamic.field("email", dynamic.string)(params)
  let assert Ok(password) = dynamic.field("password", dynamic.string)(params)

  case registration.register_user(email, password) {
    Ok(user) -> {
      let assert Ok(token) = users.create_session_token(user)

      session.Session(token: token, email: user.email)
      |> session.to_json()
      |> render.json(201)
    }

    Error(error) -> {
      render.error(error)
    }
  }
}

@target(erlang)
pub fn session(req: Request) -> Response {
  use params <- wisp.require_json(req)

  let assert Ok(email) = dynamic.field("email", dynamic.string)(params)
  let assert Ok(password) = dynamic.field("password", dynamic.string)(params)

  case users.get_user_by_email(email) {
    Error(Nil) ->
      json.object([
        #("message", json.string("There is no user by that email address")),
      ])
      |> render.json(422)

    Ok(user) -> {
      case users.verify_password(user, password) {
        False -> {
          json.object([
            #("message", json.string("Your password is not correct")),
          ])
          |> render.json(422)
        }

        True -> {
          let assert Ok(token) = users.create_session_token(user)

          session.Session(token: token, email: user.email)
          |> session.to_json()
          |> render.json(201)
        }
      }
    }
  }
}

@target(erlang)
pub fn reset_password(req: Request) -> Response {
  use params <- wisp.require_json(req)

  let assert Ok(token) = dynamic.field("token", dynamic.string)(params)
  let assert Ok(password) = dynamic.field("password", dynamic.string)(params)

  case users.get_user_by_reset_password_token(token) {
    Error(Nil) ->
      json.object([
        #(
          "message",
          json.string(
            "Hmm, it looks like this token is no longer valid, please try to reset your password again.",
          ),
        ),
      ])
      |> render.json(422)

    Ok(user) -> {
      case users.update_user_password(user, password) {
        Error(error) -> {
          render.error(error)
        }

        Ok(user) -> {
          let assert Ok(token) = users.create_session_token(user)

          session.Session(token: token, email: user.email)
          |> session.to_json()
          |> render.json(201)
        }
      }
    }
  }
}

@target(erlang)
pub fn reset_password_create(req: Request) -> Response {
  use params <- wisp.require_json(req)
  let assert Ok(email) = dynamic.field("email", dynamic.string)(params)

  case users.get_user_by_email(email) {
    Error(Nil) -> {
      Nil
    }

    Ok(user) -> {
      let assert Ok(_) = deliver_password_email(user)
      Nil
    }
  }

  json.string("OK")
  |> render.json(201)
}

fn deliver_password_email(user: User) {
  let assert Ok(token) = users.create_reset_password_token(user)
  let link = config.endpoint() <> "/users/reset_password/" <> token

  email.new()
  |> email.from(config.system_email())
  |> email.to(user.email)
  |> email.subject("Reset your password to monitor bear")
  |> email.html_body(
    html.div([], [
      html.p([], [
        html.text(
          "Here is your password reset link.  If you didn't request it, just ignore this email.",
        ),
      ]),
      html.p([], [html.a([attribute.href(link)], [html.text(link)])]),
    ])
    |> element.to_string(),
  )
  |> mailer.deliver()
}
