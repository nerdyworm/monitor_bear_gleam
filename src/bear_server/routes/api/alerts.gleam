import bear/alerts
import bear/alerts/alert
import bear/scope.{type Scope}
import bear_server/render
import gleam/int
import gleam/json
import wisp.{type Request, type Response}

pub fn index(scope: Scope, _req: Request) -> Response {
  let assert Ok(alerts) = alerts.list(scope)

  alerts
  |> json.array(alert.to_json)
  |> render.json(200)
}

pub fn create(scope: Scope, req: Request) -> Response {
  use params <- wisp.require_json(req)

  let assert Ok(alert) = alert.decoder(params)

  alerts.create_alert(scope, alert)
  |> render.respond(alert.to_json)
}

pub fn update(scope: Scope, id: String, req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(alert) = alerts.get_alert(scope, id)

  use params <- wisp.require_json(req)
  let assert Ok(params) = alert.decoder(params)

  alerts.update_alert(scope, alert, params)
  |> render.respond(alert.to_json)
}

pub fn show(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(alert) = alerts.get_alert(scope, id)

  alert
  |> alert.to_json()
  |> render.json(200)
}

pub fn delete(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(alert) = alerts.get_alert(scope, id)

  alerts.delete_alert(alert)
  |> render.respond(alert.to_json)
}
