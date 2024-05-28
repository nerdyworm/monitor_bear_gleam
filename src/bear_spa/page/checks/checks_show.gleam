import bear/monitors/assertion.{type Assertion, type AssertionResult}
import bear/monitors/message.{type Message, type MessageRecord, MessageRecord}
import bear/monitors/metric.{type Metric, Metric}
import bear/monitors/metrics
import bear/monitors/monitor.{type Monitor}
import bear/monitors/report.{type Report}
import bear/monitors/state.{type State}
import bear/monitors/status
import bear/pubsub_message.{type PubsubMessage, MonitorMessageRecord}
import bear_spa/api.{type ApiError}
import bear_spa/api/monitors
import bear_spa/app.{type App}
import bear_spa/lib/browser
import bear_spa/lib/time
import bear_spa/route
import bear_spa/view/charts
import bear_spa/view/dropdown
import bear_spa/view/modal
import bear_spa/view/ui
import gleam/dict
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, h1, h2, span, text}
import lustre/event
import lustre/sub
import lustre/sub/resize
import lustre/sub/time as ticker

pub type Model {
  Model(
    check_id: Int,
    records: List(MessageRecord),
    actions: dropdown.Model,
    confirming: Bool,
    modal: modal.Model,
    record: Option(MessageRecord),
    metrics: charts.Model,
    period: String,
  )
}

pub type Msg {
  DropdownMsg(dropdown.Msg(Msg))
  DeletedMonitor(Result(Monitor, ApiError))
  LoadedState(Result(State, ApiError))
  LoadedMessages(Result(List(MessageRecord), ApiError))
  LoadedMetrics(Result(List(Metric), ApiError))
  Message(MessageRecord)
  CheckNow
  Pause
  Resume
  Checked(Result(State, ApiError))
  Tick
  Confirm
  ConfirmedDelete
  ShowRecord(MessageRecord)
  ShowPeriod(String)
  ModalMsg(modal.Msg(Msg))
  MouseOver(String, Int, Int)
  MouseLeft
  SetWidth(Int)
  WindowResized(resize.Size)
  OnPubsubMessage(PubsubMessage)
}

pub fn title(app: App, model: Model) -> String {
  let monitor = case dict.get(app.store.monitors, model.check_id) {
    Error(Nil) -> monitor.new()
    Ok(state) -> state
  }

  monitor.name
}

pub fn init(app: App, check_id: Int) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      check_id: check_id,
      records: [],
      actions: dropdown.init(),
      confirming: False,
      modal: modal.init(),
      record: None,
      metrics: charts.Model(..charts.new(), width: 704, height: 150, padding: 5),
      period: "1min",
    )

  #(
    model,
    effect.batch([
      monitors.list_monitor_messages(check_id, app, LoadedMessages),
      monitors.list_monitor_metrics_by_name(
        check_id,
        "1min",
        app,
        LoadedMetrics,
      ),
    ]),
  )
}

pub fn subscriptions(app: App, model: Model) -> sub.Sub(Msg) {
  sub.batch([
    ticker.every("check_show_ticker", 1000, Tick),
    resize.resized("check_show_resized", WindowResized),
    dropdown.subscriptions(model.actions)
      |> sub.map(DropdownMsg),
    modal.subscriptions(model.modal)
      |> sub.map(ModalMsg),
    app.subscribe(app, "checks_show_websocket", OnPubsubMessage),
  ])
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    MouseOver(_name, x, y) -> {
      let metrics = charts.Model(..model.metrics, mouse: Some(#(x, y)))
      #(Model(..model, metrics: metrics), effect.none())
    }

    MouseLeft -> {
      let metrics = charts.Model(..model.metrics, mouse: None)
      #(Model(..model, metrics: metrics), effect.none())
    }

    Confirm -> {
      #(Model(..model, confirming: True), effect.none())
    }

    SetWidth(width) -> {
      #(
        Model(..model, metrics: charts.set_width(model.metrics, width)),
        effect.none(),
      )
    }

    WindowResized(_) -> {
      #(model, get_width_effect())
    }

    ShowPeriod(name) -> {
      #(
        Model(..model, period: name),
        monitors.list_monitor_metrics_by_name(
          model.check_id,
          name,
          app,
          LoadedMetrics,
        ),
      )
    }

    ConfirmedDelete -> {
      #(
        Model(..model, confirming: False),
        monitors.delete_monitor(model.check_id, app, DeletedMonitor),
      )
    }

    DeletedMonitor(_result) -> {
      #(
        model,
        effect.batch([
          app.flash(app, "Check was deleted"),
          app.monitor_deleted(app, model.check_id),
          route.push("/checks"),
        ]),
      )
    }

    DropdownMsg(dropdown.Custom(Confirm)) -> {
      update(app, model, Confirm)
    }

    DropdownMsg(dropdown.Custom(msg)) -> {
      let #(model, effects0) = update(app, model, msg)
      let #(actions, effects1) = dropdown.update(model.actions, dropdown.Close)
      #(
        Model(..model, actions: actions),
        effect.batch([effects0, effect.map(effects1, DropdownMsg)]),
      )
    }

    DropdownMsg(submsg) -> {
      let #(actions, effects) = dropdown.update(model.actions, submsg)
      #(Model(..model, actions: actions), effect.map(effects, DropdownMsg))
    }

    Tick -> {
      #(model, effect.none())
    }

    LoadedMetrics(Ok(metrics)) -> {
      let metrics = charts.build(model.metrics, metrics)
      #(Model(..model, metrics: metrics), get_width_effect())
    }

    LoadedMetrics(Error(error)) -> {
      io.debug(error)
      #(model, effect.none())
    }

    LoadedMessages(Ok(records)) -> {
      #(Model(..model, records: records), effect.none())
    }

    LoadedMessages(Error(error)) -> {
      io.debug(error)
      #(model, effect.none())
    }

    Message(record) -> {
      #(Model(..model, records: [record, ..model.records]), effect.none())
    }

    CheckNow -> {
      #(model, monitors.check_monitor_now(model.check_id, app, Checked))
    }

    Pause -> {
      #(model, monitors.pause(model.check_id, app, LoadedState))
    }

    LoadedState(_) -> {
      #(model, effect.none())
    }

    Resume -> {
      #(model, monitors.resume(model.check_id, app, LoadedState))
    }

    Checked(Ok(state)) -> {
      #(model, app.replace_state(app, state))
    }

    Checked(Error(_)) -> {
      #(model, effect.none())
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

    OnPubsubMessage(MonitorMessageRecord(record))
      if record.monitor_id == model.check_id
    -> {
      #(Model(..model, records: [record, ..model.records]), effect.none())
    }

    OnPubsubMessage(_) -> {
      #(model, effect.none())
    }
  }
}

fn get_state(app: App, model: Model) {
  case dict.get(app.store.states, model.check_id) {
    Error(Nil) -> state.new()
    Ok(state) -> state
  }
}

pub fn view(app: App, model: Model) -> Element(Msg) {
  let state = get_state(app, model)

  let monitor = case dict.get(app.store.monitors, model.check_id) {
    Error(Nil) -> monitor.new()
    Ok(state) -> state
  }

  div([class("checks-show")], [
    div([class("page-header")], [
      div([], [
        h1([], [text(monitor.name)]),
        h2([class("text-subtext0 text-sm")], [text(monitor.config.url)]),
      ]),
      view_page_actions(app, model),
    ]),
    view_cards(state, model),
    view_metrics(model),
    view_records(model),
    view_record_details_modal(model),
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

fn view_record_details(record: MessageRecord) {
  case record.data {
    message.Checked(report) -> {
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

fn view_page_actions(app: App, model: Model) {
  html.div([attribute.class("page-actions flex space-x-4 items-center")], [
    view_actions_dropdown(app, model),
  ])
}

fn view_actions_dropdown(app: App, model: Model) {
  let state = get_state(app, model)

  dropdown.view(
    model: model.actions,
    trigger: html.button([attribute.class("btn-primary flex items-center")], [
      html.span([attribute.class("hero-bolt w-4 h-4 mr-1")], []),
      html.text("Actions"),
    ]),
    items: [
      html.a(
        [
          attribute.href("/checks/" <> int.to_string(model.check_id) <> "/edit"),
          attribute.class(
            "text-text block px-4 py-2 text-sm hover:bg-mantle cursor-pointer",
          ),
        ],
        [html.text("Edit")],
      ),
      case state.status {
        status.Paused ->
          html.div(
            [
              attribute.class(
                "text-text block px-4 py-2 text-sm hover:bg-mantle cursor-pointer",
              ),
              dropdown.on_click(Resume),
            ],
            [html.text("Resume")],
          )
        _ ->
          html.div(
            [
              attribute.class(
                "text-text block px-4 py-2 text-sm hover:bg-mantle cursor-pointer",
              ),
              dropdown.on_click(Pause),
            ],
            [html.text("Pause")],
          )
      },
      html.div(
        [
          attribute.class(
            "text-text block px-4 py-2 text-sm hover:bg-mantle cursor-pointer",
          ),
          dropdown.on_click(CheckNow),
        ],
        [html.text("Check now")],
      ),
      case model.confirming {
        True ->
          html.div(
            [
              attribute.class(
                "text-text block px-4 py-2 text-sm hover:bg-mantl cursor-pointer",
              ),
              dropdown.on_click(ConfirmedDelete),
            ],
            [html.text("Confirm, delete check?")],
          )
        False ->
          html.div(
            [
              attribute.class(
                "text-text block px-4 py-2 text-sm hover:bg-mantle cursor-pointer",
              ),
              dropdown.on_click(Confirm),
            ],
            [html.text("Delete")],
          )
      },
    ],
  )
  |> element.map(DropdownMsg)
}

fn view_cards(state: State, _model: Model) {
  div([class("grid grid-cols-1 gap-2 md:grid-cols-3 md:gap-5")], [
    ui.state_card(state),
    div([class("bg-mantle text-base status-card relative overflow-visible")], [
      div([class("text-subtext0 text-sm")], [
        span([], [text("Next check ")]),
        case state.next_region {
          Some(region) -> span([class("font-bold")], [text(region)])
          None -> span([], [])
        },
      ]),
      div([class("text-text mt-1 text-2xl font-bold")], [
        case state.checking, state.next_check_at {
          False, Some(time) -> text(time.since(time))
          _, _ -> span([class("text-text/10")], [text("-")])
        },
      ]),
    ]),
    div([class("bg-mantle text-base status-card relative overflow-visible")], [
      div([class("text-subtext0 text-sm")], [text("Last Success")]),
      div([class("text-text mt-1 text-2xl font-bold")], [
        case state.metrics.last_success_at {
          Some(time) -> text(time.since(time))
          None -> span([class("text-text/10")], [text("never")])
        },
      ]),
    ]),
    div([class("bg-mantle text-base status-card relative overflow-visible")], [
      div([class("text-subtext0 text-sm")], [text("Last Error")]),
      div([class("text-text mt-1 text-2xl font-bold")], [
        case state.metrics.last_error_at {
          Some(time) -> text(time.since(time))
          None -> span([class("text-text/10")], [text("never")])
        },
      ]),
    ]),
    div([class("bg-mantle text-base status-card relative overflow-visible")], [
      div([class("text-subtext0 text-sm")], [text("Last Runtime")]),
      div([class("text-text mt-1 text-2xl font-bold")], [
        case state.metrics.last_runtime_ms {
          Some(ms) -> text(int.to_string(ms) <> "ms")
          None -> span([class("text-text/10")], [text("-")])
        },
      ]),
    ]),
    div([class("bg-mantle text-base status-card relative overflow-visible")], [
      div([class("text-subtext0 text-sm")], [text("Average Laency")]),
      div([class("text-text mt-1 text-2xl font-bold")], [
        case metrics.average_runtime(state.metrics) {
          0 -> span([class("text-text/10")], [text("-")])
          ms -> text(int.to_string(ms) <> "ms")
        },
      ]),
    ]),
  ])
}

fn view_metrics(model: Model) {
  div([], [view_timeseries(model.period, model.metrics)])
}

fn view_timeseries(name: String, metrics) {
  div([class("mt-5 bg-mantle rounded-md px-4 py-5")], [
    view_chart_header(name),
    div(
      [
        attribute.id("timeseries"),
        event.on("mousemove", fn(event) {
          let #(x, y) = get_position(event, "timeseries")
          Ok(MouseOver(name, x, y))
        }),
        event.on_mouse_leave(MouseLeft),
      ],
      [charts.line(metrics)],
    ),
  ])
}

fn view_chart_header(period: String) {
  div([class("flex mb-4")], [
    div([class("")], [
      case period {
        "1hour" -> text("Time: 1 hour, last year")
        "5min" -> text("Time: 5 minute, last 5 days")
        _ -> text("Time: 1 minute, last 3 hours")
      },
    ]),
    div([class("ml-auto flex space-x-2")], [
      button(
        [
          event.on_click(ShowPeriod("1min")),
          ui.class_list([
            #("btn small", True),
            #("btn-primary", period == "1min"),
          ]),
        ],
        [text("1 min")],
      ),
      button(
        [
          event.on_click(ShowPeriod("5min")),
          ui.class_list([
            #("btn small", True),
            #("btn-primary", period == "5min"),
          ]),
        ],
        [text("5 min")],
      ),
      button(
        [
          event.on_click(ShowPeriod("1hour")),
          ui.class_list([
            #("btn small", True),
            #("btn-primary", period == "1hour"),
          ]),
        ],
        [text("1 hour")],
      ),
    ]),
  ])
}

fn get_width_effect() {
  effect.from(fn(dispatch) { dispatch(SetWidth(get_width("timeseries"))) })
}

fn get_width(id: String) {
  case browser.get_element_by_id(id) {
    Error(Nil) -> 500
    Ok(element) -> {
      let rect = browser.bounding_client_rect(element)
      rect.width
    }
  }
}

fn get_position(event, id: String) {
  let assert Ok(x) = dynamic.field("pageX", dynamic.int)(event)
  let assert Ok(y) = dynamic.field("pageY", dynamic.int)(event)
  let assert Ok(element) = browser.get_element_by_id(id)
  let rect = browser.bounding_client_rect(element)
  #(x - rect.left, y - rect.top)
}

fn view_records(model: Model) {
  div([], [
    div([class("my-4")], [h1([class("font-bold")], [text("Check History")])]),
    div(
      [class("space-y-4")],
      model.records
        |> list.take(100)
        |> list.map(fn(record) {
        div([class("history-record space-y-4")], [
          ui.card([], [view_record_data(record, model)]),
        ])
      }),
    ),
  ])
}

fn view_record_data(record: MessageRecord, _model: Model) {
  case record.data {
    message.Flipped(from, to) -> {
      div([class("flex space-x-4")], [
        div([class("history-record-icon " <> ui.status_color(to))], [
          span([class("hero-bell w-5 h-5 inline-block")], []),
        ]),
        div([class("history-record-data")], [
          div([class("history-record-kind")], [
            text("Flipped"),
            span([class("text-subtext0 text-xs ml-1")], [
              text(time.since(record.inserted_at)),
            ]),
          ]),
          div([], [
            text("From: "),
            text(status.to_string(from)),
            text(" To: "),
            text(status.to_string(to)),
          ]),
        ]),
      ])
    }

    message.Checked(report) -> {
      view_report(report, record)
    }

    message.Configured(from, to, _, user_email) -> {
      div([class("flex space-x-4")], [
        div([class("history-record-icon bg-rosewater")], [
          span([class("hero-cog-6-tooth w-5 h-5 inline-block")], []),
        ]),
        div([class("history-record-data flex-1")], [
          div([class("history-record-kind")], [
            text("Configured"),
            span([class("text-subtext0 text-xs ml-1")], [
              text(time.since(record.inserted_at)),
            ]),
          ]),
          div([], [
            text(user_email),
            div([class("mb-2 font-mono text-xs")], [text(string.inspect(from))]),
            div([class("mb-2 font-mono text-xs")], [text(string.inspect(to))]),
          ]),
        ]),
      ])
    }
  }
}

fn view_report(report: Report, record: MessageRecord) {
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
  ])
}

fn view_assertion(assertion: Assertion) {
  div([class("flex space-x-2 text-sm")], [
    div([], [text(assertion.source_to_string(assertion.source))]),
    div([class("font-bold")], [text(assertion.op_to_string(assertion.op))]),
    div([], [text(assertion.value)]),
  ])
}
