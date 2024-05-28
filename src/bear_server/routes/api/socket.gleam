import bear/scope.{type Scope}
import bear/teams
import bear/users
import bear_server/lib/pubsub
import gleam/bytes_builder
import gleam/dynamic
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/int
import gleam/option.{Some}
import gleam/otp/actor
import gleam/uri
import mist.{type Connection}

@target(erlang)
pub fn handle(req: Request(Connection)) {
  case require_scope(req) {
    Error(Nil) -> {
      response.new(401)
      |> response.set_body(mist.Bytes(bytes_builder.new()))
    }

    Ok(scope) -> {
      mist.websocket(
        request: req,
        on_init: fn(_conn) {
          pubsub.subscribe("team:" <> int.to_string(scope.team.id))

          let state = scope
          let selector =
            process.new_selector()
            |> process.selecting_anything(fn(dynamic) {
              let assert Ok(s) = dynamic.string(dynamic)
              s
            })

          #(state, Some(selector))
        },
        on_close: fn(_state) { Nil },
        handler: handle_ws_message,
      )
    }
  }
}

@target(erlang)
fn require_scope(req: Request(Connection)) -> Result(Scope, Nil) {
  let assert Some(params) = req.query
  let assert Ok([#("token", token)]) = uri.parse_query(params)
  case users.get_user_by_session_token(token) {
    Ok(user) -> {
      let assert Ok(team) = teams.get_user_default_team(user)
      Ok(scope.new(user, team))
    }

    Error(_) -> {
      Error(Nil)
    }
  }
}

@target(erlang)
fn handle_ws_message(state, conn, message) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(state)
    }

    mist.Text(_) | mist.Binary(_) -> {
      actor.continue(state)
    }

    mist.Custom(custom) -> {
      let assert Ok(_) = mist.send_text_frame(conn, custom)
      actor.continue(state)
    }

    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}
