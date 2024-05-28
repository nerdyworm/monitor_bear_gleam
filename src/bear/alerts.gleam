import bear/alerts/alert.{
  type Action, type Alert, type Trigger, Alert, MonitorFlipped, MonitorStatus,
  NotifyEmail, NotifyUsersByTag,
}
import bear/alerts/monitor_flipped_email
import bear/alerts/monitor_status_email
import bear/incidents
import bear/mailer
import bear/monitors/flip.{type Flip, Flip}
import bear/monitors/monitor.{type Monitor}
import bear/monitors/state.{type State}
import bear/monitors/status
import bear/scope.{type Scope}
import bear/tags
import bear/users
import bear_server/lib/db
import gleam/dynamic
import gleam/json
import gleam/list
import gleam/pgo
import gleam/result
import gleam/string
import lib/email

const alert_columns = "
  alerts.id,
  alerts.team_id,
  alerts.name,
  alerts.enabled,
  alerts.triggers,
  alerts.filters,
  alerts.actions,
  alerts.last_triggered_at::text
"

fn alert_decoder(dynamic) {
  dynamic.decode8(
    Alert,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, dynamic.string),
    dynamic.element(3, dynamic.bool),
    dynamic.element(4, json_decoder(dynamic.list(alert.trigger_decoder))),
    dynamic.element(5, json_decoder(dynamic.list(alert.filter_decoder))),
    dynamic.element(6, json_decoder(dynamic.list(alert.action_decoder))),
    dynamic.element(7, dynamic.optional(dynamic.string)),
  )(dynamic)
}

pub fn create_alert(scope: Scope, alert: Alert) {
  use alert <- result.try(alert.validate(alert))

  let assert Ok(alert) =
    db.one(
      "INSERT INTO alerts (team_id, name, enabled, triggers, filters, actions) VALUES ($1, $2, $3, $4, $5, $6) RETURNING "
        <> alert_columns,
      [
        pgo.int(scope.team.id),
        pgo.text(alert.name),
        pgo.bool(alert.enabled),
        pgo.text(
          json.array(alert.triggers, alert.trigger_to_json)
          |> json.to_string(),
        ),
        pgo.text(
          json.array(alert.filters, alert.filter_to_json)
          |> json.to_string(),
        ),
        pgo.text(
          json.array(alert.actions, alert.action_to_json)
          |> json.to_string(),
        ),
      ],
      alert_decoder,
    )

  Ok(alert)
}

pub fn update_alert(_scope: Scope, _alert: Alert, params: Alert) {
  use alert <- result.try(alert.validate(params))

  let assert Ok(alert) =
    db.one(
      "UPDATE alerts SET name = $2, enabled = $3, triggers = $4, filters = $5, actions = $6 WHERE id = $1 RETURNING "
        <> alert_columns,
      [
        pgo.int(alert.id),
        pgo.text(alert.name),
        pgo.bool(alert.enabled),
        pgo.text(
          json.array(alert.triggers, alert.trigger_to_json)
          |> json.to_string(),
        ),
        pgo.text(
          json.array(alert.filters, alert.filter_to_json)
          |> json.to_string(),
        ),
        pgo.text(
          json.array(alert.actions, alert.action_to_json)
          |> json.to_string(),
        ),
      ],
      alert_decoder,
    )

  Ok(alert)
}

pub fn list(scope: Scope) {
  list_by_team_id(scope.team.id)
}

pub fn list_by_team_id(team_id: Int) {
  db.all(
    "SELECT " <> alert_columns <> " FROM alerts WHERE team_id = $1",
    [pgo.int(team_id)],
    alert_decoder,
  )
}

pub fn get_alert(scope: Scope, id: Int) {
  db.one(
    "SELECT " <> alert_columns <> " FROM alerts WHERE team_id = $1 AND id = $2",
    [pgo.int(scope.team.id), pgo.int(id)],
    alert_decoder,
  )
}

pub fn delete_alert(alert: Alert) {
  db.one(
    "DELETE FROM alerts WHERE id = $1 RETURNING " <> alert_columns,
    [pgo.int(alert.id)],
    alert_decoder,
  )
}

fn json_decoder(decoder) {
  fn(dynamic) {
    case dynamic.string(dynamic) {
      Error(error) -> Error(error)
      Ok(string) -> {
        let assert Ok(json) = json.decode(string, dynamic.dynamic)
        decoder(json)
      }
    }
  }
}

pub fn maybe_trigger_still_down(monitor: Monitor, state: State) {
  // at some point we need to cache this because it gets ran on every incoming report.
  let assert Ok(alerts) = list_by_team_id(monitor.team_id)

  let triggered =
    alerts
    |> list.filter(fn(alert: Alert) { alert.enabled })
    |> list.filter(fn(alert: Alert) {
      list.any(alert.triggers, fn(trigger: Trigger) {
        case trigger {
          MonitorStatus(_, s, interval) -> {
            let ready = alert.is_ready(alert, interval)
            ready && s == status.to_string(state.status)
          }

          _ -> False
        }
      })
    })

  // if any triggers, queue job here...
  list.each(triggered, fn(alert: Alert) {
    let assert Ok(alert) = mark_triggered(alert)
    list.each(alert.actions, fn(action: Action) {
      trigger_moinitor_status_action(monitor, state, action, alert)
    })
  })
}

pub fn trigger_monitor_flipped(monitor: Monitor, flip: Flip) {
  let assert Ok(alerts) = list_by_team_id(monitor.team_id)

  let triggered =
    alerts
    |> list.filter(fn(alert: Alert) { alert.enabled })
    |> list.filter(fn(alert: Alert) {
      list.any(alert.triggers, fn(trigger: Trigger) {
        case trigger {
          MonitorFlipped(_, from, to) -> {
            from == status.to_string(flip.from)
            && to == status.to_string(flip.to)
          }

          _ -> False
        }
      })
    })

  list.each(triggered, fn(alert: Alert) {
    let assert Ok(alert) = mark_triggered(alert)
    list.each(alert.actions, fn(action: Action) {
      trigger_monitor_flipped_action(monitor, flip, alert, action)
    })
  })
}

fn mark_triggered(alert: Alert) {
  db.one(
    "UPDATE alerts SET last_triggered_at = now() at time zone 'utc' WHERE id = $1 RETURNING "
      <> alert_columns,
    [pgo.int(alert.id)],
    alert_decoder,
  )
}

fn trigger_monitor_flipped_action(
  monitor: Monitor,
  flip: Flip,
  alert: Alert,
  action: Action,
) {
  case action {
    NotifyEmail(_, email) ->
      notify_email_monitor_flipped(monitor, flip, alert, email)

    NotifyUsersByTag(_, tag) ->
      notify_users_by_tag_monitor_flipped(monitor, flip, alert, tag)
  }
}

fn trigger_moinitor_status_action(
  monitor: Monitor,
  state: State,
  action: Action,
  alert: Alert,
) {
  case action {
    NotifyEmail(_, email) ->
      notify_email_monitor_status(monitor, state, alert, email)

    NotifyUsersByTag(_, tag) ->
      notify_email_monitor_status_by_tag(monitor, state, alert, tag)
  }
}

fn notify_email_monitor_flipped(monitor: Monitor, flip: Flip, _alert, emails) {
  let incident = incidents.current_incident(monitor)
  let message = monitor_flipped_email.email(monitor, flip, incident)

  string.split(emails, ",")
  |> list.map(string.trim)
  |> list.fold(message, fn(e, to) { email.to(e, to) })
  |> mailer.deliver()
  |> result.then(fn(_) { Ok(Nil) })
}

fn notify_users_by_tag_monitor_flipped(monitor: Monitor, flip, _alert, tag) {
  let incident = incidents.current_incident(monitor)
  let message = monitor_flipped_email.email(monitor, flip, incident)
  let tags = tags.split(tag)
  let assert Ok(users) = users.list_users_by_tag(monitor.team_id, tags)
  let assert Ok(Nil) = incidents.emailed_users(monitor, users)

  users
  |> list.fold(message, fn(e, to) { email.to(e, to.email) })
  |> mailer.deliver()
  |> result.then(fn(_) { Ok(Nil) })
}

fn notify_email_monitor_status(monitor: Monitor, state: State, _alert, emails) {
  let incident = incidents.current_incident(monitor)
  let message = monitor_status_email.email(monitor, state, incident)

  let emails =
    string.split(emails, ",")
    |> list.map(string.trim)

  let assert Ok(Nil) = incidents.emailed_emails(monitor, emails)

  emails
  |> list.fold(message, fn(e, to) { email.to(e, to) })
  |> mailer.deliver()
  |> result.then(fn(_) { Ok(Nil) })
}

fn notify_email_monitor_status_by_tag(
  monitor: Monitor,
  state: State,
  _alert,
  tag,
) {
  let incident = incidents.current_incident(monitor)
  let message = monitor_status_email.email(monitor, state, incident)

  let tags = tags.split(tag)
  let assert Ok(users) = users.list_users_by_tag(monitor.team_id, tags)
  let assert Ok(Nil) = incidents.emailed_users(monitor, users)

  users
  |> list.fold(message, fn(e, to) { email.to(e, to.email) })
  |> mailer.deliver()
  |> result.then(fn(_) { Ok(Nil) })
}
