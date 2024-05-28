import bear/monitors/flip.{type Flip}
import bear/monitors/message.{type MessageRecord}
import bear/monitors/metric.{type Metric, Metric}
import bear/monitors/monitor.{type Monitor}
import bear/monitors/state.{type State}
import bear_spa/api.{type ApiError}
import bear_spa/app.{type App}
import gleam/dynamic
import gleam/int
import gleam/json

pub fn list_monitors(
  app: App,
  response: fn(Result(List(Monitor), ApiError)) -> msg,
) {
  api.get("/monitors", api.expect(dynamic.list(monitor.decoder), response), app)
}

pub fn list_monitor_states(
  app: App,
  response: fn(Result(List(State), ApiError)) -> msg,
) {
  api.get2("/monitors/states", dynamic.list(state.decoder), response, app)
}

pub fn list_monitor_flips(
  app: App,
  response: fn(Result(List(Flip), ApiError)) -> msg,
) {
  api.get2("/monitors/flips", dynamic.list(flip.decoder), response, app)
}

pub fn list_monitor_messages(
  monitor_id: Int,
  app: App,
  response: fn(Result(List(MessageRecord), ApiError)) -> msg,
) {
  api.get2(
    "/monitors/" <> int.to_string(monitor_id) <> "/messages",
    dynamic.list(message.record_decoder),
    response,
    app,
  )
}

pub fn list_monitor_metrics(
  monitor_id: Int,
  app: App,
  response: fn(Result(List(Metric), ApiError)) -> msg,
) {
  api.get2(
    "/monitors/" <> int.to_string(monitor_id) <> "/metrics",
    dynamic.list(metric.decoder),
    response,
    app,
  )
}

pub fn list_monitor_metrics_by_name(
  monitor_id: Int,
  name: String,
  app: App,
  response: fn(Result(List(Metric), ApiError)) -> msg,
) {
  api.get2(
    "/monitors/" <> int.to_string(monitor_id) <> "/metrics/" <> name,
    dynamic.list(metric.decoder),
    response,
    app,
  )
}

pub fn get_monitor(
  monitor_id: Int,
  app: App,
  response: fn(Result(Monitor, ApiError)) -> msg,
) {
  api.get2(
    "/monitors/" <> int.to_string(monitor_id),
    monitor.decoder,
    response,
    app,
  )
}

pub fn create_monitor(
  monitor: Monitor,
  app: App,
  response: fn(Result(Monitor, ApiError)) -> msg,
) {
  api.post(
    "/monitors",
    monitor.to_json(monitor),
    api.expect(monitor.decoder, response),
    app,
  )
}

pub fn update_monitor(
  monitor: Monitor,
  app: App,
  response: fn(Result(Monitor, ApiError)) -> msg,
) {
  api.put(
    "/monitors/" <> int.to_string(monitor.id),
    monitor.to_json(monitor),
    api.expect(monitor.decoder, response),
    app,
  )
}

pub fn check_monitor_now(
  monitor_id: Int,
  app: App,
  response: fn(Result(State, ApiError)) -> msg,
) {
  api.post(
    "/monitors/" <> int.to_string(monitor_id) <> "/check-now",
    json.object([]),
    api.expect(state.decoder, response),
    app,
  )
}

pub fn delete_monitor(
  monitor_id: Int,
  app: App,
  response: fn(Result(Monitor, ApiError)) -> msg,
) {
  api.delete(
    "/monitors/" <> int.to_string(monitor_id),
    json.object([]),
    api.expect(monitor.decoder, response),
    app,
  )
}

pub fn pause(
  monitor_id: Int,
  app: App,
  response: fn(Result(State, ApiError)) -> msg,
) {
  api.post(
    "/monitors/" <> int.to_string(monitor_id) <> "/pause",
    json.object([]),
    api.expect(state.decoder, response),
    app,
  )
}

pub fn resume(
  monitor_id: Int,
  app: App,
  response: fn(Result(State, ApiError)) -> msg,
) {
  api.post(
    "/monitors/" <> int.to_string(monitor_id) <> "/resume",
    json.object([]),
    api.expect(state.decoder, response),
    app,
  )
}
