import bear/monitors/monitor.{type Monitor}
import bear/monitors/state.{type State}
import bear/pubsub_message
import bear/session.{type Session}
import bear_spa/lib/localstorage
import bear_spa/lib/pubsub.{type PubSub}
import bear_spa/route.{type Route}
import bear_spa/store.{type Store}
import gleam/json
import gleam/option.{type Option, None}
import lustre/effect
import lustre/sub

pub type AppEvents {
  SessionStarted(Session)
  SessionInvalid
  LoadedMonitors(List(Monitor))
  LoadedMonitorStates(List(State))
  DeletedMonitor(Int)
  FlashMessage(String)
}

pub type App {
  App(
    session: Option(Session),
    endpoint: String,
    endpoint_socket: String,
    store: Store,
    route: Route,
    pubsub: PubSub(AppEvents),
    pubsub2: PubSub(pubsub_message.PubsubMessage),
  )
}

pub fn empty() {
  App(
    endpoint: "http://localhost:8080/api",
    endpoint_socket: "ws://localhost:8080/api/socket",
    session: None,
    store: store.new(),
    route: route.Private(route.Checks(route.ChecksIndex)),
    pubsub: pubsub.new(),
    pubsub2: pubsub.new(),
  )
}

pub fn new(endpoint: String, endpoint_socket: String) {
  App(..empty(), endpoint: endpoint, endpoint_socket: endpoint_socket)
}

pub fn begin_session(app: App, session: Session) {
  effect.from(fn(_) {
    localstorage.write("session", json.to_string(session.to_json(session)))
    pubsub.publish(app.pubsub, SessionStarted(session))
  })
}

pub fn monitor_deleted(app: App, monitor_id: Int) {
  effect.from(fn(_) { pubsub.publish(app.pubsub, DeletedMonitor(monitor_id)) })
}

pub fn end_session(app: App) {
  App(..app, session: None, store: store.new())
}

pub fn replace_state(app: App, state: State) {
  replace_states(app, [state])
}

pub fn replace_states(app: App, states: List(State)) {
  effect.from(fn(_) { pubsub.publish(app.pubsub, LoadedMonitorStates(states)) })
}

pub fn replace_monitor(app: App, monitor: Monitor) {
  replace_monitors(app, [monitor])
}

pub fn replace_monitors(app: App, monitors: List(Monitor)) {
  effect.from(fn(_) { pubsub.publish(app.pubsub, LoadedMonitors(monitors)) })
}

pub fn flash(app: App, message: String) {
  effect.from(fn(_) { pubsub.publish(app.pubsub, FlashMessage(message)) })
}

pub fn subscribe(app: App, key, tagger) {
  sub.new(key, fn(dispatch) {
    let callback = fn(message) { dispatch(tagger(message)) }
    pubsub.subscribe(app.pubsub2, callback)
    fn() { pubsub.unsubscribe(app.pubsub2, callback) }
  })
}
