import bear/config
import bear/scope.{type Scope}
import bear/teams
import bear/users as u
import bear_server/routes/api/alerts
import bear_server/routes/api/checkout
import bear_server/routes/api/incidents
import bear_server/routes/api/memberships
import bear_server/routes/api/monitors
import bear_server/routes/api/teams as api_teams
import bear_server/routes/api/users
import bear_server/routes/assets
import bear_server/routes/index
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request
import gleam/io
import gleam/json
import lib/stripe
import wisp.{type Request, type Response}

@target(erlang)
pub fn handle_request(req: Request) -> Response {
  use <- wisp.rescue_crashes()
  use <- cors()
  use req <- wisp.handle_head(req)

  case req.method, wisp.path_segments(req) {
    // no logging middleware on these
    Get, ["healthcheck"] -> wisp.ok()
    http.Options, _ -> wisp.no_content()
    Get, ["assets", ..] -> assets.assets(req)
    _, ["api", "internal", ..] -> internal(req)

    // all middleware
    _, _ -> route(req)
  }
}

@target(erlang)
fn internal(req: Request) -> Response {
  use <- require_internal(req)

  case req.method, wisp.path_segments(req) {
    Post, ["api", "internal", "healthchecks", "pop"] ->
      monitors.pop_healthchecks(req)

    Post, ["api", "internal", "healthchecks", "report", id] ->
      monitors.report(id, req)

    _, _ -> wisp.not_found()
  }
}

@target(erlang)
fn route(req: Request) -> Response {
  use <- wisp.log_request(req)
  use req <- wisp.handle_head(req)

  case req.method, wisp.path_segments(req) {
    // public apis
    Post, ["api", "users", "register"] -> users.register(req)
    Post, ["api", "users", "session"] -> users.session(req)
    Post, ["api", "users", "reset_password"] -> users.reset_password(req)
    Post, ["api", "users", "reset_password_create"] ->
      users.reset_password_create(req)

    // authenticated api
    _, ["api", ..] -> required_user(req)

    // stripe webhook
    _, ["webhook"] -> webhook(req)

    // pages
    Get, [] -> index.index(req)

    // everything else goes to spa
    _, _ -> index.spa(req)
  }
}

@target(erlang)
fn required_user(req: Request) -> Response {
  use #(scope, req) <- require_user(req)

  case req.method, wisp.path_segments(req) {
    http.Options, _ -> wisp.no_content()
    Get, ["api", "alerts"] -> alerts.index(scope, req)
    Get, ["api", "alerts", id] -> alerts.show(scope, id, req)
    Put, ["api", "alerts", id] -> alerts.update(scope, id, req)
    Delete, ["api", "alerts", id] -> alerts.delete(scope, id, req)
    Post, ["api", "alerts"] -> alerts.create(scope, req)
    Post, ["api", "invitations"] -> memberships.create_invitation(scope, req)
    Get, ["api", "incidents", id, "messages"] ->
      incidents.messages(scope, id, req)
    Post, ["api", "incidents", id, "resolve"] ->
      incidents.resolve(scope, id, req)
    Get, ["api", "incidents", id] -> incidents.show(scope, id, req)
    Get, ["api", "incidents"] -> incidents.index(scope, req)
    Get, ["api", "memberships"] -> memberships.index(scope, req)
    Put, ["api", "memberships", _] -> memberships.update(scope, req)
    Delete, ["api", "memberships", _] -> memberships.delete(scope, req)
    Get, ["api", "monitors", "states"] -> monitors.index_states(scope, req)
    Get, ["api", "monitors", "flips"] -> monitors.index_flips(scope, req)
    Get, ["api", "monitors", id] -> monitors.show(scope, id, req)
    Put, ["api", "monitors", id] -> monitors.update(scope, id, req)
    Get, ["api", "monitors", id, "metrics"] ->
      monitors.metrics(scope, id, "all", req)

    Get, ["api", "monitors", id, "metrics", name] ->
      monitors.metrics_by_name(scope, id, name, req)
    Get, ["api", "monitors", id, "messages"] ->
      monitors.messages(scope, id, req)
    Post, ["api", "monitors", id, "check-now"] ->
      monitors.check_now(scope, id, req)
    Post, ["api", "monitors", id, "pause"] -> monitors.pause(scope, id, req)
    Post, ["api", "monitors", id, "resume"] -> monitors.resume(scope, id, req)
    Delete, ["api", "monitors", id] -> monitors.delete(scope, id, req)
    Get, ["api", "monitors"] -> monitors.index(scope, req)
    Post, ["api", "monitors"] -> monitors.create(scope, req)
    Get, ["api", "team"] -> api_teams.show(scope, req)
    Post, ["api", "checkout_session"] -> checkout.create_session(scope, req)
    _, _ -> wisp.not_found()
  }
}

fn require_user(req: Request, next: fn(#(Scope, Request)) -> Response) {
  case request.get_header(req, "authorization") {
    Error(Nil) -> wisp.not_found()
    Ok(token) -> {
      case u.get_user_by_session_token(token) {
        Ok(user) -> {
          let assert Ok(team) = teams.get_user_default_team(user)
          next(#(scope.new(user, team), req))
        }

        other -> {
          let _ = io.debug(#("other in require user", other))
          json.object([#("error", json.string("bad token"))])
          |> json.to_string_builder()
          |> wisp.json_response(401)
        }
      }
    }
  }
}

fn require_internal(req: Request, next: fn() -> Response) {
  case request.get_header(req, "authorization") {
    Error(Nil) -> wisp.not_found()
    Ok(token) -> {
      case token == config.internal_api_key() {
        True -> next()
        False -> wisp.not_found()
      }
    }
  }
}

fn cors(next: fn() -> Response) {
  next()
  |> wisp.set_header("access-control-allow-origin", "*")
  |> wisp.set_header("access-control-allow-methods", "GET, POST, PUT, DELETE")
  |> wisp.set_header(
    "access-control-allow-headers",
    "Content-Type, Authorization",
  )
  |> wisp.set_header("access-control-max-age", "86400")
}

@target(erlang)
fn webhook(req: Request) {
  use body <- wisp.require_string_body(req)
  let assert Ok(signature) = request.get_header(req, "Stripe-Signature")
  let assert Ok(Nil) = stripe.handle_webhook(body, signature)

  json.object([#("status", json.string("success"))])
  |> json.to_string_builder()
  |> wisp.json_response(200)
}
