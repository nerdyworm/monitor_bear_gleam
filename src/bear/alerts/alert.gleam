import bear/error.{Validation}
import bear/utils
import birl
import birl/duration
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import validates

pub type Trigger {
  MonitorFlipped(id: String, from: String, to: String)
  MonitorStatus(id: String, status: String, interval: String)
}

pub type Filter {
  // MonitorFilter(id: String, monitor_id: Int)
  MonitorTag(id: String, tag: String)
  MonitorNotTag(id: String, tag: String)
}

pub type Action {
  NotifyEmail(id: String, email: String)
  NotifyUsersByTag(id: String, tag: String)
}

pub type Alert {
  Alert(
    id: Int,
    team_id: Int,
    name: String,
    enabled: Bool,
    triggers: List(Trigger),
    filters: List(Filter),
    actions: List(Action),
    last_triggered_at: Option(String),
  )
}

pub fn new() {
  Alert(
    id: 0,
    team_id: 0,
    name: "",
    enabled: True,
    triggers: [],
    filters: [],
    actions: [],
    last_triggered_at: None,
  )
  |> new_trigger()
  |> new_action()
}

pub fn default() {
  Alert(..new(), name: "default")
}

pub fn new_action(alert: Alert) {
  Alert(
    ..alert,
    actions: list.append(alert.actions, [
      NotifyUsersByTag(id: utils.make_id(), tag: "all"),
    ]),
  )
}

pub fn new_notify_email_action(alert: Alert) {
  Alert(
    ..alert,
    actions: list.append(alert.actions, [
      NotifyEmail(id: utils.make_id(), email: ""),
    ]),
  )
}

pub fn new_trigger(alert: Alert) {
  Alert(
    ..alert,
    triggers: list.append(alert.triggers, [
      MonitorFlipped(id: utils.make_id(), from: "up", to: "down"),
    ]),
  )
}

pub fn new_trigger_monitor_status(alert: Alert) {
  Alert(
    ..alert,
    triggers: list.append(alert.triggers, [
      MonitorStatus(id: utils.make_id(), status: "down", interval: "1 hour"),
    ]),
  )
}

pub fn new_filter(alert: Alert) {
  Alert(
    ..alert,
    filters: list.append(alert.filters, [
      MonitorTag(id: utils.make_id(), tag: ""),
    ]),
  )
}

pub fn new_monitor_not_tag(alert: Alert) {
  Alert(
    ..alert,
    filters: list.append(alert.filters, [
      MonitorNotTag(id: utils.make_id(), tag: ""),
    ]),
  )
}

pub fn replace_action(alert: Alert, action: Action) {
  Alert(
    ..alert,
    actions: list.map(alert.actions, fn(t) {
      case t.id == action.id {
        True -> action
        False -> t
      }
    }),
  )
}

pub fn remove_action(alert: Alert, action: Action) {
  Alert(
    ..alert,
    actions: list.filter(alert.actions, fn(t) { t.id != action.id }),
  )
}

pub fn replace_trigger(alert: Alert, trigger: Trigger) {
  Alert(
    ..alert,
    triggers: list.map(alert.triggers, fn(t) {
      case t.id == trigger.id {
        True -> trigger
        False -> t
      }
    }),
  )
}

pub fn remove_trigger(alert: Alert, trigger: Trigger) {
  Alert(
    ..alert,
    triggers: list.filter(alert.triggers, fn(t) { t.id != trigger.id }),
  )
}

pub fn replace_filter(alert: Alert, filter: Filter) {
  Alert(
    ..alert,
    filters: list.map(alert.filters, fn(t) {
      case t.id == filter.id {
        True -> filter
        False -> t
      }
    }),
  )
}

pub fn remove_filter(alert: Alert, filter: Filter) {
  Alert(
    ..alert,
    filters: list.filter(alert.filters, fn(t) { t.id != filter.id }),
  )
}

pub fn validate(alert: Alert) {
  validates.rules()
  |> validates.add(
    validates.string("name", alert.name)
    |> validates.required(),
  )
  |> validates.result_map_error(alert, Validation)
}

pub fn to_json(alert: Alert) {
  json.object([
    #("id", json.int(alert.id)),
    #("team_id", json.int(alert.team_id)),
    #("name", json.string(alert.name)),
    #("enabled", json.bool(alert.enabled)),
    #("triggers", json.array(alert.triggers, trigger_to_json)),
    #("filters", json.array(alert.filters, filter_to_json)),
    #("actions", json.array(alert.actions, action_to_json)),
    #("last_triggered_at", json.nullable(alert.last_triggered_at, json.string)),
  ])
}

pub fn trigger_to_json(trigger: Trigger) {
  case trigger {
    MonitorFlipped(id, from, to) -> {
      json.object([
        #(
          "monitor_flipped",
          json.object([
            #("id", json.string(id)),
            #("from", json.string(from)),
            #("to", json.string(to)),
          ]),
        ),
      ])
    }

    MonitorStatus(id, status, interval) -> {
      json.object([
        #(
          "monitor_status",
          json.object([
            #("id", json.string(id)),
            #("status", json.string(status)),
            #("interval", json.string(interval)),
          ]),
        ),
      ])
    }
  }
}

pub fn filter_to_json(filter: Filter) {
  case filter {
    MonitorTag(id, tag) -> {
      json.object([
        #(
          "monitor_tag",
          json.object([#("id", json.string(id)), #("tag", json.string(tag))]),
        ),
      ])
    }

    MonitorNotTag(id, tag) -> {
      json.object([
        #(
          "monitor_not_tag",
          json.object([#("id", json.string(id)), #("tag", json.string(tag))]),
        ),
      ])
    }
  }
}

pub fn decoder(dynamic) {
  dynamic.decode8(
    Alert,
    dynamic.field("id", dynamic.int),
    dynamic.field("team_id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("enabled", dynamic.bool),
    dynamic.field("triggers", dynamic.list(trigger_decoder)),
    dynamic.field("filters", dynamic.list(filter_decoder)),
    dynamic.field("actions", dynamic.list(action_decoder)),
    dynamic.field("last_triggered_at", dynamic.optional(dynamic.string)),
  )(dynamic)
}

pub fn trigger_decoder(dynamic) {
  dynamic.any([monitor_flipped_decoder, monitor_status_decoder])(dynamic)
}

pub fn monitor_flipped_decoder(dynamic) {
  dynamic.field(
    "monitor_flipped",
    dynamic.decode3(
      MonitorFlipped,
      dynamic.field("id", dynamic.string),
      dynamic.field("from", dynamic.string),
      dynamic.field("to", dynamic.string),
    ),
  )(dynamic)
}

pub fn monitor_status_decoder(dynamic) {
  dynamic.field(
    "monitor_status",
    dynamic.decode3(
      MonitorStatus,
      dynamic.field("id", dynamic.string),
      dynamic.field("status", dynamic.string),
      dynamic.field("interval", dynamic.string),
    ),
  )(dynamic)
}

pub fn filter_decoder(dynamic) {
  dynamic.any([monitor_tag_decoder, monitor_not_tag_decoder])(dynamic)
}

pub fn monitor_tag_decoder(dynamic) {
  dynamic.field(
    "monitor_tag",
    dynamic.decode2(
      MonitorTag,
      dynamic.field("id", dynamic.string),
      dynamic.field("tag", dynamic.string),
    ),
  )(dynamic)
}

pub fn monitor_not_tag_decoder(dynamic) {
  dynamic.field(
    "monitor_not_tag",
    dynamic.decode2(
      MonitorNotTag,
      dynamic.field("id", dynamic.string),
      dynamic.field("tag", dynamic.string),
    ),
  )(dynamic)
}

pub fn action_to_json(action: Action) {
  case action {
    NotifyEmail(id, email) -> {
      json.object([
        #(
          "notify_email",
          json.object([#("id", json.string(id)), #("email", json.string(email))]),
        ),
      ])
    }

    NotifyUsersByTag(id, tag) -> {
      json.object([
        #(
          "notify_user_by_tag",
          json.object([#("id", json.string(id)), #("tag", json.string(tag))]),
        ),
      ])
    }
  }
}

pub fn action_decoder(dynamic) {
  dynamic.any([notify_email, notify_user_by_tag_decoder])(dynamic)
}

pub fn notify_user_by_tag_decoder(dynamic) {
  dynamic.field(
    "notify_user_by_tag",
    dynamic.decode2(
      NotifyUsersByTag,
      dynamic.field("id", dynamic.string),
      dynamic.field("tag", dynamic.string),
    ),
  )(dynamic)
}

pub fn notify_email(dynamic) {
  dynamic.field(
    "notify_email",
    dynamic.decode2(
      NotifyEmail,
      dynamic.field("id", dynamic.string),
      dynamic.field("email", dynamic.string),
    ),
  )(dynamic)
}

pub fn sort(alerts: List(Alert)) -> List(Alert) {
  list.sort(alerts, compare)
}

pub fn compare(a: Alert, b: Alert) {
  string.compare(string.lowercase(a.name), string.lowercase(b.name))
}

pub fn interval_to_seconds(interval: String) -> Int {
  case interval {
    "2 hours" -> 60 * 60 * 2
    "1 hour" -> 60 * 60
    "30 minutes" -> 60 * 30
    "10 minutes" -> 60 * 10
    "5 minutes" -> 60 * 5
    _ -> 60 * 5
  }
}

pub fn is_ready(alert: Alert, interval: String) {
  case alert.last_triggered_at {
    Some(t) -> {
      let assert Ok(time) = birl.from_naive(t)
      let delta = birl.difference(birl.utc_now(), time)

      let delta = duration.blur_to(delta, duration.Second)
      delta > interval_to_seconds(interval)
    }

    None -> {
      True
    }
  }
}
