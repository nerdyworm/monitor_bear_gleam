import bear/incidents/incident.{type Incident, type Status, Ongoing, Resolved}
import bear/pubsub_message
import bear_spa/api.{type ApiError}
import bear_spa/api/incidents
import bear_spa/app.{type App}
import bear_spa/lib/time
import bear_spa/view/ui
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, div, h1, text}
import lustre/sub

pub type Model {
  Model(incidents: List(Incident), grumpy: Bool)
}

pub type Msg {
  Response(Result(List(Incident), ApiError))
  OnPubsubMessage(pubsub_message.PubsubMessage)
}

pub fn init(app: App) -> #(Model, Effect(Msg)) {
  let model = Model([], True)
  #(model, effect.batch([incidents.list_incidents(app, Response)]))
}

pub fn subscriptions(app: App, _model: Model) {
  sub.batch([app.subscribe(app, "incidents_index_websocket", OnPubsubMessage)])
}

pub fn update(_app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Response(Ok(incidents)) -> {
      #(Model(..model, incidents: incidents), effect.none())
    }

    Response(Error(message)) -> {
      io.debug(message)
      #(model, effect.none())
    }

    OnPubsubMessage(pubsub_message.Incident(incident)) -> {
      io.debug(incident)
      case list.find(model.incidents, fn(i) { i.id == incident.id }) {
        Error(Nil) -> #(
          Model(..model, incidents: [incident, ..model.incidents]),
          effect.none(),
        )

        Ok(_) -> #(
          Model(
            ..model,
            incidents: list.map(model.incidents, fn(i) {
              case i.id == incident.id {
                True -> incident
                False -> i
              }
            }),
          ),
          effect.none(),
        )
      }
    }

    OnPubsubMessage(_) -> {
      #(model, effect.none())
    }
  }
}

pub fn view(app: App, model: Model) -> Element(Msg) {
  div([class("alerts-index")], [
    div([class("page-header")], [
      h1([], [text("Listing Incidents")]),
      div([class("page-actions")], [
        a([href("/"), class("btn")], [text("Back")]),
      ]),
    ]),
    div([], [
      div(
        [],
        list.map(model.incidents, fn(incident) {
          view_incident(incident, app, model)
        }),
      ),
    ]),
  ])
}

fn view_incident(incident: Incident, app: App, _model: Model) {
  a([href("/incidents/" <> int.to_string(incident.id))], [
    ui.card([class("mb-4 flex space-x-4")], [
      div([class("w-48")], [view_affected_monitors(incident, app)]),
      div([class("flex-1 text-sm")], [
        text("Started at: "),
        html.br([]),
        text(time.since(incident.started_at)),
      ]),
      div([class("flex-1 text-sm")], [
        text("Duration:"),
        html.br([]),
        text(incident.duration_to_string(incident)),
      ]),
      div([class("ml-auto")], [view_status(incident.status)]),
    ]),
  ])
}

fn view_affected_monitors(incident: Incident, app: App) {
  div(
    [class("space-y-1")],
    list.map(incident.monitor_ids, fn(monitor_id) {
      case dict.get(app.store.monitors, monitor_id) {
        Error(Nil) -> ui.null()
        Ok(monitor) -> {
          div([class("monitor-left")], [
            div([class("name")], [text(monitor.name)]),
            div([class("url text-subtext0 text-xs")], [text(monitor.config.url)]),
          ])
        }
      }
    }),
  )
}

fn view_status(status: Status) {
  case status {
    Ongoing -> ui.pill("bg-red", incident.status_to_string(status))
    Resolved -> ui.pill("bg-teal", incident.status_to_string(status))
  }
}
