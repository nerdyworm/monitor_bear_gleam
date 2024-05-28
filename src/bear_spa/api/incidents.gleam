import bear/incidents/incident.{type Incident}
import bear/incidents/message.{type Record}
import bear_spa/api.{type ApiError}
import bear_spa/app.{type App}
import gleam/dynamic
import gleam/int

pub fn list_incidents(
  app: App,
  response: fn(Result(List(Incident), ApiError)) -> msg,
) {
  api.get(
    "/incidents",
    api.expect(dynamic.list(incident.decoder), response),
    app,
  )
}

pub fn list_incident_messages(
  app: App,
  id: Int,
  response: fn(Result(List(Record), ApiError)) -> msg,
) {
  api.get(
    "/incidents/" <> int.to_string(id) <> "/messages",
    api.expect(dynamic.list(message.record_decoder), response),
    app,
  )
}

pub fn get_incident(
  app: App,
  id: Int,
  response: fn(Result(Incident, ApiError)) -> msg,
) {
  api.get(
    "/incidents/" <> int.to_string(id),
    api.expect(incident.decoder, response),
    app,
  )
}

pub fn update_incident(
  incident: Incident,
  app: App,
  response: fn(Result(Incident, ApiError)) -> msg,
) {
  api.put(
    "/incidents/" <> int.to_string(incident.id),
    incident.to_json(incident),
    api.expect(incident.decoder, response),
    app,
  )
}

pub fn resolve(
  incident: Incident,
  app: App,
  response: fn(Result(Incident, ApiError)) -> msg,
) {
  api.post(
    "/incidents/" <> int.to_string(incident.id) <> "/resolve",
    incident.to_json(incident),
    api.expect(incident.decoder, response),
    app,
  )
}
