import bear/incidents/incident.{type Incident, Ongoing, Resolved}
import bear/incidents/message.{type Record}
import bear/monitors/assertion.{type Assertion, type AssertionResult}
import bear/monitors/monitor.{type Monitor}
import bear/monitors/report.{type Report}
import bear/monitors/state
import bear/pubsub_message.{type PubsubMessage, Incident, IncidentMessageRecord}
import bear/users/user.{type User}
import bear_spa/api.{type ApiError}
import bear_spa/api/incidents
import bear_spa/app.{type App}
import bear_spa/lib/time
import bear_spa/view/modal
import bear_spa/view/ui
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, button, div, h1, span, text}
import lustre/event
import lustre/sub
import lustre/sub/time as ticker

pub type Model {
  Model(
    incident: Incident,
    records: List(Record),
    modal: modal.Model,
    record: Option(Record),
  )
}

pub type Msg {
  ListResponse(Result(List(Record), ApiError))
  ModalMsg(modal.Msg(Msg))
  Resolve
  Response(Result(Incident, ApiError))
  ShowRecord(Record)
  Message(Record)
  Tick
  OnPubsubMessage(PubsubMessage)
}

pub fn init(app: App, id: Int) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      incident: incident.new(),
      records: [],
      modal: modal.init(),
      record: None,
    )

  #(
    model,
    effect.batch([
      incidents.get_incident(app, id, Response),
      incidents.list_incident_messages(app, id, ListResponse),
    ]),
  )
}

pub fn subscriptions(app: App, model: Model) -> sub.Sub(Msg) {
  sub.batch([
    app.subscribe(app, "incidents_show_websocket", OnPubsubMessage),
    ticker.every("incidents_show_ticker", 1000, Tick),
    modal.subscriptions(model.modal)
      |> sub.map(ModalMsg),
  ])
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick -> {
      #(model, effect.none())
    }

    Message(message) -> {
      #(Model(..model, records: [message, ..model.records]), effect.none())
    }

    Response(Ok(incident)) -> {
      #(Model(..model, incident: incident), effect.none())
    }

    Response(Error(message)) -> {
      io.debug(message)
      #(model, effect.none())
    }

    ListResponse(Ok(records)) -> {
      #(Model(..model, records: records), effect.none())
    }

    ListResponse(Error(message)) -> {
      io.debug(message)
      #(model, effect.none())
    }

    Resolve -> {
      #(model, incidents.resolve(model.incident, app, Response))
    }

    ShowRecord(record) -> {
      let #(modal, effects) = modal.open(model.modal)
      #(
        Model(..model, modal: modal, record: Some(record)),
        effect.map(effects, ModalMsg),
      )
    }

    ModalMsg(msg) -> {
      let #(modal, effects) = modal.update(model.modal, msg)
      #(Model(..model, modal: modal), effect.map(effects, ModalMsg))
    }

    OnPubsubMessage(IncidentMessageRecord(message)) -> {
      #(Model(..model, records: [message, ..model.records]), effect.none())
    }

    OnPubsubMessage(Incident(incident)) -> {
      #(Model(..model, incident: incident), effect.none())
    }

    OnPubsubMessage(_) -> {
      #(model, effect.none())
    }
  }
}

pub fn view(app: App, model: Model) -> Element(Msg) {
  div([class("alerts-index")], [
    div([class("page-header")], [
      h1([], [text("Incident Details")]),
      div([class("page-actions")], [
        a([href("/incidents"), class("btn")], [text("Back")]),
        case model.incident.status {
          Resolved ->
            button([class("btn"), event.on_click(Resolve)], [text("Resolve")])
          Ongoing ->
            button([class("btn"), event.on_click(Resolve)], [text("Resolve")])
        },
      ]),
    ]),
    div([class("mb-4")], [view_cards(app, model)]),
    div([class("mb-4")], [view_affected_monitors(app, model)]),
    div([class("mb-4")], [
      h1([class("font-bold mb-4 text-2xl")], [text("History")]),
      view_messages(app, model),
    ]),
    view_record_details_modal(model),
  ])
}

fn view_cards(_app: App, model: Model) {
  let incident = model.incident

  div([class("grid grid-cols-1 gap-2 md:grid-cols-3 md:gap-5")], [
    incident_status_card(incident),
    div([class("bg-mantle text-base status-card relative overflow-visible")], [
      div([class("text-subtext0 text-sm")], [text("Started At")]),
      div([class("text-text mt-1 text-2xl font-bold")], [
        text(time.since(incident.started_at)),
      ]),
    ]),
    div([class("bg-mantle text-base status-card relative overflow-visible")], [
      div([class("text-subtext0 text-sm")], [text("Duration")]),
      div([class("text-text mt-1 text-2xl font-bold")], [
        text(incident.duration_to_string(incident)),
      ]),
    ]),
  ])
}

fn view_affected_monitors(app: App, model: Model) {
  let incident = model.incident

  let monitors =
    list.map(incident.monitor_ids, fn(monitor_id) {
      case dict.get(app.store.monitors, monitor_id) {
        Error(Nil) -> monitor.new()
        Ok(state) -> state
      }
    })

  div([], [
    h1([class("text-2xl font-bold mb-2")], [text("Affected Monitors")]),
    div(
      [class("grid grid-cols-1 gap-2 md:grid-cols-2 md:gap-5")],
      list.map(monitors, fn(monitor) {
        let state = case dict.get(app.store.states, monitor.id) {
          Error(Nil) -> state.new()
          Ok(state) -> state
        }

        ui.card([], [
          div([class("flex")], [
            div([], [
              div([], [text(monitor.name)]),
              div([], [text(monitor.config.url)]),
            ]),
            div([class("ml-auto")], [ui.state(state)]),
          ]),
        ])
      }),
    ),
  ])
}

fn incident_status_card(incident: Incident) {
  case incident.status {
    Resolved ->
      div([class("status-card bg-teal text-base relative overflow-visible")], [
        div([class("text-base text-sm")], [html.text("Status:")]),
        div([class("mt-1 text-2xl font-bold")], [text("Resolved")]),
      ])

    Ongoing ->
      div([class("status-card bg-red text-base relative overflow-visible")], [
        div([class("text-base text-sm")], [html.text("Status:")]),
        div([class("mt-1 text-2xl font-bold")], [text("Ongoing")]),
      ])
  }
}

fn view_messages(app: App, model: Model) {
  div(
    [],
    list.map(model.records, fn(record) {
      case record.data {
        message.Started(monitor) -> view_started(monitor, record)
        message.Checked(report, monitor_id) ->
          view_report(report, monitor_id, record, app)
        message.Continued(monitor) -> view_continued(monitor, record)
        message.EmailedUser(user) -> view_emailed_user(user, record)
        message.EmailedEmail(user) -> view_emailed_email(user, record)
        message.Resolved(user) -> view_resolved(user, record)
        message.ResolvedOnUp -> view_resolved_on_up(record)
        message.Recovering(monitor) -> view_recovering(monitor, record)
        message.Recovered(monitor) -> view_recovered(monitor, record)
      }
    }),
  )
}

fn view_started(monitor: Monitor, record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Incident started by "),
      a(
        // TODO - check/healthcheck etc
        [href("/checks/" <> int.to_string(monitor.id)), class("underline")],
        [text(monitor.name)],
      ),
      text(" going down at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

fn view_continued(monitor: Monitor, record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Incident continued by "),
      a(
        // TODO - check/healthcheck etc
        [href("/checks/" <> int.to_string(monitor.id)), class("underline")],
        [text(monitor.name)],
      ),
      text(" going down at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

fn view_recovering(monitor: Monitor, record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Monitor "),
      a(
        // TODO - check/healthcheck etc
        [href("/checks/" <> int.to_string(monitor.id)), class("underline")],
        [text(monitor.name)],
      ),
      text(" has started to recover at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

fn view_recovered(monitor: Monitor, record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Monitor "),
      a(
        // TODO - check/healthcheck etc
        [href("/checks/" <> int.to_string(monitor.id)), class("underline")],
        [text(monitor.name)],
      ),
      text(" has recovered at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

fn view_emailed_user(user: User, record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Emailed user "),
      text(user.email),
      text(" at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

fn view_emailed_email(email: String, record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Emailed "),
      text(email),
      text(" at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

fn view_resolved(user: User, record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Resolved by "),
      text(user.email),
      text(" at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

fn view_resolved_on_up(record: Record) {
  ui.card([class("mb-4")], [
    div([class("p")], [
      text("Resolved because all monitors are up "),
      text(" at "),
      text(time.since(record.inserted_at)),
    ]),
  ])
}

// copy pasta from check_show...
fn view_report(report: Report, monitor_id: Int, record: Record, app: App) {
  let monitor = case dict.get(app.store.monitors, monitor_id) {
    Error(Nil) -> monitor.new()
    Ok(state) -> state
  }

  ui.card([class("mb-4")], [
    div([attribute.class("flex space-x-4")], [
      case report.healthy {
        False -> {
          div([class("history-record-icon bg-red")], [
            span([class("hero-exclamation-triangle w-5 h-5 inline-block")], []),
          ])
        }
        True -> {
          div([class("history-record-icon bg-teal")], [
            span([class("hero-shield-check w-5 h-5 inline-block")], []),
          ])
        }
      },
      div([class("history-record-data")], [
        div([class("history-record-kind")], [
          text("Checked"),
          text(" "),
          text(monitor.config.url),
          span([class("text-subtext0 text-xs ml-1")], [
            text(time.since(record.inserted_at)),
          ]),
        ]),
        div([], [
          div([class("mb-1")], [
            div([class("text-sm")], [
              button([class(""), event.on_click(ShowRecord(record))], [
                ui.icon("hero-magnifying-glass w-4 h-4 mr-1"),
                text("details"),
              ]),
              text(" "),
              text(report.region),
              text(" "),
              text(int.to_string(report.status)),
              text(" "),
              text(int.to_string(report.runtime) <> "ms"),
              text(" "),
            ]),
          ]),
          case report.message == "" {
            False -> {
              div([class("text-red")], [text("Error: " <> report.message)])
            }
            True -> div([], [])
          },
          div(
            [],
            list.map(report.assertions, fn(result: AssertionResult) {
              case result.result {
                True -> {
                  div([class("text-teal flex items-center")], [
                    span([class("hero-shield-check w-4 h-4 mr-2")], []),
                    view_assertion(result.assertion),
                  ])
                }

                False -> {
                  div([class("text-red flex items-center")], [
                    span([class("hero-x-mark w-4 h-4 mr-2")], []),
                    view_assertion(result.assertion),
                  ])
                }
              }
            }),
          ),
        ]),
      ]),
    ]),
  ])
}

fn view_assertion(assertion: Assertion) {
  div([class("flex space-x-2 text-sm")], [
    div([], [text(assertion.source_to_string(assertion.source))]),
    div([class("font-bold")], [text(assertion.op_to_string(assertion.op))]),
    div([], [text(assertion.value)]),
  ])
}

fn view_record_details_modal(model: Model) {
  modal.view(model.modal, [
    html.div([attribute.class("")], [
      case model.record {
        Some(record) -> view_record_details(record)
        None -> ui.null()
      },
    ]),
  ])
  |> element.map(ModalMsg)
}

fn view_record_details(record: Record) {
  case record.data {
    message.Checked(report, _) -> {
      div([], [
        ui.list([
          #("timestamp", time.since(record.inserted_at)),
          #("region", report.region),
          #("healthy", string.inspect(report.healthy)),
          #("status", string.inspect(report.status)),
          #("runtime", string.inspect(report.runtime) <> "ms"),
          #("message", report.message),
          #("body", report.body),
        ]),
      ])
    }
    _ -> ui.null()
  }
}
