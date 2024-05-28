import bear/alerts/alert.{type Alert}
import bear_spa/api.{type ApiError}
import bear_spa/app.{type App}
import gleam/dynamic
import gleam/int

pub fn list_alerts(app: App, response: fn(Result(List(Alert), ApiError)) -> msg) {
  api.get("/alerts", api.expect(dynamic.list(alert.decoder), response), app)
}

pub fn get_alert(
  id: Int,
  app: App,
  response: fn(Result(Alert, ApiError)) -> msg,
) {
  api.get2("/alerts/" <> int.to_string(id), alert.decoder, response, app)
}

pub fn create_alert(
  alert: Alert,
  app: App,
  response: fn(Result(Alert, ApiError)) -> msg,
) {
  api.post(
    "/alerts",
    alert.to_json(alert),
    api.expect(alert.decoder, response),
    app,
  )
}

pub fn update_alert(
  alert: Alert,
  app: App,
  response: fn(Result(Alert, ApiError)) -> msg,
) {
  api.put(
    "/alerts/" <> int.to_string(alert.id),
    alert.to_json(alert),
    api.expect(alert.decoder, response),
    app,
  )
}

pub fn delete_alert(
  alert: Alert,
  app: App,
  response: fn(Result(Alert, ApiError)) -> msg,
) {
  api.delete(
    "/alerts/" <> int.to_string(alert.id),
    alert.to_json(alert),
    api.expect(alert.decoder, response),
    app,
  )
}
