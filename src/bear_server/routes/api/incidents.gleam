import bear/incidents
import bear/incidents/incident
import bear/incidents/message
import bear/scope.{type Scope}
import bear_server/render
import gleam/int
import gleam/json
import wisp.{type Request, type Response}

pub fn index(scope: Scope, _req: Request) -> Response {
  let assert Ok(incidents) = incidents.list_incidents(scope)

  incidents
  |> json.array(incident.to_json)
  |> render.json(200)
}

pub fn show(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(incident) = incidents.get_incident(scope, id)

  incident
  |> incident.to_json()
  |> render.json(200)
}

pub fn messages(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(incident) = incidents.get_incident(scope, id)
  let assert Ok(messages) = incidents.list_incident_messages(incident)

  messages
  |> json.array(message.record_to_json)
  |> render.json(200)
}

pub fn resolve(scope: Scope, id: String, _req: Request) -> Response {
  let assert Ok(id) = int.parse(id)
  let assert Ok(incident) = incidents.get_incident(scope, id)
  let assert Ok(incident) = incidents.resolve(incident, scope)

  incident
  |> incident.to_json()
  |> render.json(200)
}
