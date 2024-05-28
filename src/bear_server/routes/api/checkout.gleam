import bear/scope.{type Scope}
import bear_server/render
import gleam/dynamic
import gleam/json
import lib/stripe
import wisp.{type Request, type Response}

@target(erlang)
pub fn create_session(scope: Scope, req: Request) -> Response {
  use params <- wisp.require_json(req)
  let assert Ok(name) = dynamic.field("name", dynamic.string)(params)
  let assert Ok(url) = stripe.create_checkout_session(scope.team, name)

  json.string(url)
  |> render.json(200)
}
