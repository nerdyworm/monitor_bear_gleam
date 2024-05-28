import bear/alerts/alert.{type Action, type Alert, type Filter, type Trigger}
import bear/monitors/status
import bear_spa/api.{type ApiError}
import bear_spa/api/alerts
import bear_spa/app.{type App}
import bear_spa/view/ui
import gleam/int
import gleam/list
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{div, text}

pub type Model {
  Model(alerts: List(Alert), no_warn: Bool)
}

pub type Msg {
  Response(Result(List(Alert), ApiError))
}

pub fn init(app: App) -> #(Model, Effect(Msg)) {
  let model = Model(alerts: [], no_warn: True)
  #(model, effect.batch([alerts.list_alerts(app, Response)]))
}

pub fn update(_app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Response(Ok(alerts)) -> {
      #(Model(..model, alerts: alert.sort(alerts)), effect.none())
    }

    Response(Error(_)) -> {
      #(model, effect.none())
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.id("alerts-index"), attribute.class("alerts-index")], [
    html.div([attribute.class("page-header")], [
      html.h1([], [html.text("Listing Alerts")]),
      html.div([attribute.class("page-actions")], [
        html.a([attribute.href("/admin"), attribute.class("btn")], [
          html.text("Back"),
        ]),
        html.a(
          [attribute.href("/admin/alerts/new"), attribute.class("btn-primary")],
          [html.text("Create alert")],
        ),
      ]),
    ]),
    html.div([], [
      html.div(
        [],
        list.map(model.alerts, fn(alert) { view_alert(alert, model) }),
      ),
    ]),
  ])
}

fn view_alert(alert: Alert, _model: Model) {
  html.div([attribute.class("rounded p-4 mb-4 bg-mantle")], [
    html.a(
      [
        attribute.href("/admin/alerts/" <> int.to_string(alert.id) <> "/edit"),
        attribute.class("block"),
      ],
      [
        div([class("flex mb-2")], [
          html.div([attribute.class("font-bold text-xl")], [
            html.text(alert.name),
          ]),
          html.div([attribute.class("ml-auto")], [
            case alert.enabled {
              True ->
                ui.pill2("bg-teal", [
                  ui.icon("hero-shield-check w-4 h-4 mr-1"),
                  text("enabled"),
                ])
              False ->
                ui.pill2("bg-red", [
                  ui.icon("hero-exclamation-triangle w-4 h-4 mr-1"),
                  text("enabled"),
                ])
            },
          ]),
        ]),
        html.div([], [
          html.div([attribute.class("text-subtext0 text-xs font-bold")], [
            html.text("When"),
          ]),
          html.div(
            [attribute.class("mb-4")],
            list.map(alert.triggers, fn(trigger) { view_alert_trigger(trigger) }),
          ),
        ]),
        case alert.filters {
          [] -> html.div([], [])
          _ -> {
            html.div([attribute.class("mb-4")], [
              html.div([attribute.class("text-subtext0 text-xs font-bold")], [
                html.text("If"),
              ]),
              html.div(
                [attribute.class("mb-2")],
                list.map(alert.filters, fn(filter) { view_alert_filter(filter) }),
              ),
            ])
          }
        },
        html.div([], [
          html.div([attribute.class("text-subtext0 text-xs font-bold")], [
            html.text("Then"),
          ]),
          html.div(
            [attribute.class("mb-2")],
            list.map(alert.actions, fn(action) { view_alert_action(action) }),
          ),
        ]),
      ],
    ),
  ])
}

fn view_alert_trigger(trigger: Trigger) {
  case trigger {
    alert.MonitorFlipped(_, from, to) -> {
      view_monitor_flipped(from, to)
    }

    alert.MonitorStatus(_, status, interval) -> {
      view_monitor_status(status, interval)
    }
  }
}

fn view_monitor_flipped(from, to) {
  let from_color = ui.status_color(status.from_string(from))
  let to_color = ui.status_color(status.from_string(to))
  html.div([attribute.class("")], [
    html.text("A monitor flips "),
    ui.pill(from_color, from),
    html.text(" to "),
    ui.pill(to_color, to),
  ])
}

fn view_monitor_status(status, interval) {
  let color = ui.status_color(status.from_string(status))
  html.div([attribute.class("")], [
    html.text("A monitor has been in status "),
    ui.pill(color, status),
    html.text(" for "),
    ui.pill("bg-base text-subtext0", interval),
  ])
}

fn view_alert_filter(filter: Filter) {
  case filter {
    alert.MonitorTag(_, tag) -> {
      view_monitor_tag(tag)
    }

    alert.MonitorNotTag(_, tag) -> {
      view_monitor_not_tag(tag)
    }
  }
}

fn view_monitor_tag(tag) {
  html.div([attribute.class("")], [
    html.text("the monitor is tagged with "),
    ui.tags(tag),
  ])
}

fn view_monitor_not_tag(tag) {
  html.div([attribute.class("")], [
    html.text("the monitor is not tagged with "),
    ui.tags(tag),
  ])
}

fn view_alert_action(action: Action) {
  case action {
    alert.NotifyEmail(_, email: email) -> {
      view_notify_email(email)
    }

    alert.NotifyUsersByTag(_, tag: tag) -> {
      view_notify_users_by_tag(tag)
    }
  }
}

fn view_notify_email(email: String) {
  html.div([], [
    html.text("Send an email to "),
    ui.pill("bg-base text-subtext0", email),
  ])
}

fn view_notify_users_by_tag(tag: String) {
  html.div([], [
    html.text("Notify all users that are tagged with "),
    ui.tags(tag),
  ])
}
