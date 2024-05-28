import bear/alerts/alert.{type Alert, Alert}
import bear/utils
import bear_spa/api.{type ApiError, Validation}
import bear_spa/api/alerts
import bear_spa/app.{type App}
import bear_spa/view/ui
import gleam/io
import gleam/list
import lustre/attribute.{class, name, placeholder, type_, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, h1, input, select, span, text}
import lustre/event
import validates.{type Errors}

pub type Model {
  Model(alert: Alert, errors: List(Errors), button_text: String)
}

pub type Msg {
  Submit
  Change(Alert)
  AddAction
  AddActionNotifyEmail
  AddTrigger
  AddTriggerMonitorStatus
  AddFilter
  AddMonitorNotTag
  Response(Result(Alert, ApiError))
}

pub fn init(
  _app: App,
  alert: Alert,
  button_text: String,
) -> #(Model, Effect(Msg)) {
  let model = Model(alert: alert, errors: [], button_text: button_text)
  #(model, effect.from(fn(_) { utils.focus(".focus") }))
}

pub fn update(app: App, model: Model, msg: Msg) {
  case msg {
    Change(alert) -> {
      #(Model(..model, alert: alert), effect.none())
    }

    AddAction -> {
      #(Model(..model, alert: alert.new_action(model.alert)), effect.none())
    }

    AddActionNotifyEmail -> {
      #(
        Model(..model, alert: alert.new_notify_email_action(model.alert)),
        effect.none(),
      )
    }

    AddTrigger -> {
      #(Model(..model, alert: alert.new_trigger(model.alert)), effect.none())
    }

    AddTriggerMonitorStatus -> {
      #(
        Model(..model, alert: alert.new_trigger_monitor_status(model.alert)),
        effect.none(),
      )
    }

    AddFilter -> {
      #(Model(..model, alert: alert.new_filter(model.alert)), effect.none())
    }

    AddMonitorNotTag -> {
      #(
        Model(..model, alert: alert.new_monitor_not_tag(model.alert)),
        effect.none(),
      )
    }

    Submit -> {
      case model.alert.id == 0 {
        True -> #(model, alerts.create_alert(model.alert, app, Response))
        False -> #(model, alerts.update_alert(model.alert, app, Response))
      }
    }

    Response(Error(Validation(errors))) -> {
      #(Model(..model, errors: errors), effect.none())
    }

    Response(Error(other)) -> {
      io.debug(other)
      #(model, effect.none())
    }

    Response(result) -> {
      let _ = io.debug(result)
      #(model, effect.none())
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  view_form(model)
}

pub fn view_form(model: Model) {
  div([class("alert-form")], [
    form([event.on_submit(Submit)], [
      div([class("bg-mantle rounded p-4 mb-4")], [
        ui.group(
          ui.Group(
            ..ui.new_group(),
            class: "form-group mb-2",
            name: "name",
            label: "Name",
            errors: model.errors,
            hint: "Give this alert a name so you can keep track of it in the system.",
          ),
          input([
            type_("text"),
            name("name"),
            value(model.alert.name),
            class("form-input focus"),
            placeholder("Alert the devops team"),
            event.on_input(fn(input) {
              Change(Alert(..model.alert, name: input))
            }),
          ]),
        ),
        ui.checkbox("enabled", "Enabled", model.alert.enabled, fn(input) {
          Change(Alert(..model.alert, enabled: input))
        }),
      ]),
      view_trigger_form(model),
      view_filters_form(model),
      view_actions_form(model),
      // repeat interval until...
      button([class("btn-primary"), type_("submit")], [text(model.button_text)]),
    ]),
  ])
}

pub fn view_trigger_form(model: Model) {
  div([class("bg-mantle rounded p-4 mb-4")], [
    div([], [
      h1([class("font-bold text-xl mb-2")], [text("Triggers for this alert")]),
    ]),
    div(
      [],
      list.map(model.alert.triggers, fn(trigger) {
        case trigger {
          alert.MonitorFlipped(id, from, to) ->
            view_trigger_monitor_flips(id, from, to, model)

          alert.MonitorStatus(id, status, interval) ->
            view_trigger_monitor_status(id, status, interval, model)
        }
      }),
    ),
    div([class("flex space-x-2")], [
      button([class("btn"), type_("button"), event.on_click(AddTrigger)], [
        ui.icon("hero-plus w-4 h-4 mr-1"),
        text("When a monitor flips"),
      ]),
      button(
        [class("btn"), type_("button"), event.on_click(AddTriggerMonitorStatus)],
        [ui.icon("hero-plus w-4 h-4 mr-1"), text("When a is in status")],
      ),
    ]),
  ])
}

pub fn view_trigger_monitor_flips(id, from, to, model: Model) {
  div([class("mb-4")], [
    div([class("flex items-center space-x-4")], [
      div([], [text("When a monitor flips from: ")]),
      select(
        [
          class("form-input !w-32"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_trigger(alert.MonitorFlipped(id, value, to))
            |> Change
          }),
        ],
        ui.options_for_select(["up", "down", "new", "paused"], from),
      ),
      div([], [text(" to ")]),
      select(
        [
          class("form-input !w-32"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_trigger(alert.MonitorFlipped(id, from, value))
            |> Change
          }),
        ],
        ui.options_for_select(["up", "down", "new", "paused"], to),
      ),
      button(
        [
          class("btn"),
          type_("button"),
          event.on("click", fn(_) {
            model.alert
            |> alert.remove_trigger(alert.MonitorFlipped(id, from, to))
            |> Change
            |> Ok
          }),
        ],
        [span([class("hero-trash w-4 h-4")], [])],
      ),
    ]),
  ])
}

pub fn view_trigger_monitor_status(id, status, interval, model: Model) {
  div([class("mb-4")], [
    div([class("flex items-center space-x-4")], [
      div([], [text("When a monitor has been in status: ")]),
      select(
        [
          class("form-input !w-32"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_trigger(alert.MonitorStatus(id, value, interval))
            |> Change
          }),
        ],
        ui.options_for_select(["up", "down", "new", "paused"], status),
      ),
      div([], [text(" every ")]),
      select(
        [
          class("form-input !w-32"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_trigger(alert.MonitorStatus(id, status, value))
            |> Change
          }),
        ],
        ui.options_for_select(
          ["5 minutes", "10 minutes", "30 minutes", "1 hour", "2 hours"],
          interval,
        ),
      ),
      button(
        [
          class("btn"),
          type_("button"),
          event.on("click", fn(_) {
            model.alert
            |> alert.remove_trigger(alert.MonitorStatus(id, status, interval))
            |> Change
            |> Ok
          }),
        ],
        [span([class("hero-trash w-4 h-4")], [])],
      ),
    ]),
  ])
}

pub fn view_filters_form(model: Model) {
  div([class("bg-mantle rounded p-4 mb-4")], [
    div([], [h1([class("font-bold text-xl mb-2")], [text("Filters")])]),
    div(
      [],
      list.map(model.alert.filters, fn(filter) {
        case filter {
          alert.MonitorTag(id, tag) -> view_monitor_tag_filter(id, tag, model)
          alert.MonitorNotTag(id, tag) ->
            view_monitor_not_tag_filter(id, tag, model)
        }
      }),
    ),
    div([class("mt-4 space-x-2")], [
      button([class("btn"), type_("button"), event.on_click(AddFilter)], [
        ui.icon("hero-plus w-4 h-4 mr-1"),
        text("Filter by monitor tag filter"),
      ]),
      button([class("btn"), type_("button"), event.on_click(AddMonitorNotTag)], [
        ui.icon("hero-plus w-4 h-4 mr-1"),
        text("Filter by monitor not tag filter"),
      ]),
    ]),
  ])
}

pub fn view_monitor_tag_filter(id, tag, model: Model) {
  div([class("mb-4")], [
    div([class("flex space-x-2 items-center")], [
      div([], [text("If a monitor is tagged with ")]),
      div([class("flex-1")], [
        input([
          value(tag),
          type_("text"),
          class("form-input"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_filter(alert.MonitorTag(id, value))
            |> Change
          }),
        ]),
      ]),
      div([], [
        button(
          [
            class("btn"),
            type_("button"),
            event.on("click", fn(_) {
              model.alert
              |> alert.remove_filter(alert.MonitorTag(id, tag))
              |> Change
              |> Ok
            }),
          ],
          [span([class("hero-trash w-4 h-4")], [])],
        ),
      ]),
    ]),
  ])
}

pub fn view_monitor_not_tag_filter(id, tag, model: Model) {
  div([class("mb-4")], [
    div([class("flex space-x-2 items-center")], [
      div([], [text("If a monitor is not tagged with ")]),
      div([class("flex-1")], [
        input([
          value(tag),
          type_("text"),
          class("form-input"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_filter(alert.MonitorNotTag(id, value))
            |> Change
          }),
        ]),
      ]),
      div([], [
        button(
          [
            class("btn"),
            type_("button"),
            event.on("click", fn(_) {
              model.alert
              |> alert.remove_filter(alert.MonitorNotTag(id, tag))
              |> Change
              |> Ok
            }),
          ],
          [span([class("hero-trash w-4 h-4")], [])],
        ),
      ]),
    ]),
  ])
}

pub fn view_actions_form(model: Model) {
  div([class("bg-mantle rounded p-4 mb-4")], [
    div([], [h1([class("font-bold text-xl mb-2")], [text("Actions")])]),
    div(
      [],
      list.map(model.alert.actions, fn(action) {
        case action {
          alert.NotifyEmail(id, email) -> view_notify_email(id, email, model)

          alert.NotifyUsersByTag(id, tag) ->
            view_notify_user_by_tag(id, tag, model)
        }
      }),
    ),
    div([class("mt-2 space-x-2")], [
      button([class("btn"), type_("button"), event.on_click(AddAction)], [
        ui.icon("hero-plus w-4 h-4 mr-1"),
        text("Notify by users by tag"),
      ]),
      button(
        [class("btn"), type_("button"), event.on_click(AddActionNotifyEmail)],
        [ui.icon("hero-plus w-4 h-4 mr-1"), text("Notify by email")],
      ),
    ]),
  ])
}

pub fn view_notify_email(id, email, model: Model) {
  div([class("mb-4")], [
    div([class("flex space-x-2 items-center")], [
      div([], [text("Notify by email")]),
      div([class("flex-1")], [
        input([
          value(email),
          type_("text"),
          class("form-input"),
          placeholder("bob@inc.com, alice@inc.com"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_action(alert.NotifyEmail(id, value))
            |> Change
          }),
        ]),
      ]),
      div([], [
        button(
          [
            class("btn"),
            type_("button"),
            event.on("click", fn(_) {
              model.alert
              |> alert.remove_action(alert.NotifyEmail(id, email))
              |> Change
              |> Ok
            }),
          ],
          [span([class("hero-trash w-4 h-4")], [])],
        ),
      ]),
    ]),
  ])
}

pub fn view_notify_user_by_tag(id, tag, model: Model) {
  div([class("mb-4")], [
    div([class("flex space-x-2 items-center")], [
      div([], [text("Notify all user with any of these tags")]),
      div([class("flex-1")], [
        input([
          value(tag),
          type_("text"),
          class("form-input"),
          event.on_input(fn(value) {
            model.alert
            |> alert.replace_action(alert.NotifyUsersByTag(id, value))
            |> Change
          }),
        ]),
      ]),
      div([], [
        button(
          [
            class("btn"),
            type_("button"),
            event.on("click", fn(_) {
              model.alert
              |> alert.remove_action(alert.NotifyUsersByTag(id, tag))
              |> Change
              |> Ok
            }),
          ],
          [span([class("hero-trash w-4 h-4")], [])],
        ),
      ]),
    ]),
  ])
}
