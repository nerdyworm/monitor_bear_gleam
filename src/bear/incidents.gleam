import bear/incidents/incident.{type Incident, Incident}
import bear/incidents/message.{type Message, EmailedEmail, EmailedUser}
import bear/monitors
import bear/monitors/message as monitor_message
import bear/monitors/monitor.{type Monitor, Monitor}
import bear/monitors/status.{Up}
import bear/pubsub_message
import bear/scope.{type Scope}
import bear/users/user.{type User}
import bear_server/lib/db
import bear_server/lib/pubsub
import gleam/dynamic
import gleam/int
import gleam/json
import gleam/list
import gleam/pgo

const incident_columns = "
  incidents.id,
  incidents.team_id,
  incidents.status,
  incidents.started_at::text,
  incidents.resolved_at::text,
  incidents.description,
  incidents.tags,
  COALESCE((
    SELECT array_agg(incident_monitors.monitor_id)
    FROM incident_monitors
    WHERE incident_monitors.incident_id = incidents.id
  ), '{}') AS monitor_ids
"

pub fn incident_decoder(dynamic) {
  dynamic.decode8(
    Incident,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, incident.status_decoder),
    dynamic.element(3, dynamic.string),
    dynamic.element(4, dynamic.optional(dynamic.string)),
    dynamic.element(5, dynamic.string),
    dynamic.element(6, dynamic.list(dynamic.string)),
    dynamic.element(7, dynamic.list(dynamic.int)),
  )(dynamic)
}

pub fn list_incidents(scope: Scope) {
  db.all(
    "SELECT "
      <> incident_columns
      <> " FROM incidents WHERE team_id = $1 ORDER BY started_at desc LIMIT 100",
    [pgo.int(scope.team.id)],
    incident_decoder,
  )
}

pub fn list_incident_messages(incident: Incident) {
  db.all(
    "SELECT id, incident_id, data, inserted_at::text from incident_messages WHERE incident_id = $1 ORDER BY id desc",
    [pgo.int(incident.id)],
    message_record_decoder,
  )
}

pub fn current_incident(monitor: Monitor) {
  db.get(
    "SELECT "
      <> incident_columns
      <> " FROM incidents WHERE team_id = $1 AND status = 'ongoing' ORDER BY started_at desc LIMIT 1",
    [pgo.int(monitor.team_id)],
    incident_decoder,
  )
}

pub fn emailed_users(monitor: Monitor, users: List(User)) {
  case current_incident(monitor) {
    Error(_) -> Ok(Nil)
    Ok(incident) -> {
      list.each(users, fn(user) { create_message(incident, EmailedUser(user)) })
      Ok(Nil)
    }
  }
}

pub fn emailed_emails(monitor: Monitor, users: List(String)) {
  case current_incident(monitor) {
    Error(_) -> Ok(Nil)
    Ok(incident) -> {
      list.each(users, fn(user) { create_message(incident, EmailedEmail(user)) })
      Ok(Nil)
    }
  }
}

fn message_record_decoder(dynamic) {
  dynamic.decode4(
    message.Record,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, fn(dynamic) {
      case dynamic.string(dynamic) {
        Error(error) -> Error(error)
        Ok(json) ->
          case json.decode(json, message.decoder) {
            Ok(m) -> Ok(m)
            Error(_) -> Error([])
          }
      }
    }),
    dynamic.element(3, dynamic.string),
  )(dynamic)
}

pub fn get_incident(scope: Scope, id: Int) {
  db.one(
    "SELECT "
      <> incident_columns
      <> " FROM incidents WHERE team_id = $1 AND id = $2",
    [pgo.int(scope.team.id), pgo.int(id)],
    incident_decoder,
  )
}

pub fn start_incident(
  monitor: Monitor,
  history: List(monitor_message.MessageRecord),
) {
  use <- db.transaction()

  let i = case current_incident(monitor) {
    Ok(i) -> {
      copy_history(i, monitor, history)
      let assert Ok(_) = create_message(i, message.Continued(monitor))
      i
    }

    Error(_) -> {
      let assert Ok(i) =
        db.one(
          "INSERT INTO incidents (team_id) VALUES ($1) RETURNING "
            <> incident_columns,
          [pgo.int(monitor.team_id)],
          incident_decoder,
        )

      copy_history(i, monitor, history)
      let assert Ok(_) = create_message(i, message.Started(monitor))
      i
    }
  }

  let assert Ok(_) =
    db.execute(
      "INSERT INTO incident_monitors (incident_id, monitor_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      [pgo.int(i.id), pgo.int(monitor.id)],
      dynamic.dynamic,
    )

  let i = Incident(..i, monitor_ids: [monitor.id])

  i
  |> pubsub_message.Incident()
  |> broadcast(i)

  Ok(i)
}

fn copy_history(
  incident: Incident,
  monitor: Monitor,
  history: List(monitor_message.MessageRecord),
) {
  history
  |> list.reverse()
  |> filter_most_recent_unhealth_checks()
  |> list.each(fn(item) {
    case item.data {
      monitor_message.Checked(report) -> {
        let assert Ok(_) =
          create_message_with_timestamp(
            incident,
            message.Checked(report, monitor.id),
            item.inserted_at,
          )
        Nil
      }

      _ -> {
        Nil
      }
    }
  })
}

fn filter_most_recent_unhealth_checks(
  history: List(monitor_message.MessageRecord),
) {
  list.filter(history, fn(record) {
    case record.data {
      monitor_message.Checked(report) -> report.healthy == False
      _ -> False
    }
  })
}

pub fn create_message_with_timestamp(
  incident: Incident,
  message: Message,
  timestamp: String,
) {
  let assert Ok(_) =
    db.one(
      "INSERT INTO incident_messages (incident_id, data, inserted_at) VALUES ($1, $2, to_timestamp($3, 'YYYY-MM-DD HH24:MI:SS')) RETURNING id, incident_id, data, inserted_at::text",
      [
        pgo.int(incident.id),
        pgo.text(
          message.to_json(message)
          |> json.to_string,
        ),
        pgo.text(timestamp),
      ],
      dynamic.dynamic,
    )

  // pubsub_message.MonitorMessageRecord(record)
  // |> pubsub_message.to_json()
  // |> json.to_string()
  // |> broadcast(monitor)

  Ok(message)
}

pub fn create_message(incident: Incident, message: Message) {
  let assert Ok(record) =
    db.one(
      "INSERT INTO incident_messages (incident_id, data) VALUES ($1, $2) RETURNING id, incident_id, data, inserted_at::text",
      [
        pgo.int(incident.id),
        pgo.text(
          message.to_json(message)
          |> json.to_string,
        ),
      ],
      message_record_decoder,
    )

  record
  |> pubsub_message.IncidentMessageRecord()
  |> broadcast(incident)

  Ok(message)
}

pub fn resolve(incident: Incident, scope: Scope) {
  let assert Ok(_) = create_message(incident, message.Resolved(scope.user))

  let assert Ok(incident) =
    db.one(
      "UPDATE incidents SET status = 'resolved', resolved_at = now() at time zone 'utc' WHERE id = $1 RETURNING "
        <> incident_columns,
      [pgo.int(incident.id)],
      incident_decoder,
    )

  incident
  |> pubsub_message.Incident()
  |> broadcast(incident)

  Ok(incident)
}

pub fn auto_resolve(incident: Incident) {
  let assert Ok(_) = create_message(incident, message.ResolvedOnUp)

  db.one(
    "UPDATE incidents SET status = 'resolved', resolved_at = now() at time zone 'utc' WHERE id = $1 RETURNING "
      <> incident_columns,
    [pgo.int(incident.id)],
    incident_decoder,
  )
}

pub fn recovering(monitor: Monitor) {
  case current_incident(monitor) {
    Error(_) -> Ok(Nil)
    Ok(incident) -> {
      let assert Ok(_) = create_message(incident, message.Recovering(monitor))
      Ok(Nil)
    }
  }
}

pub fn recovered(monitor: Monitor) {
  case current_incident(monitor) {
    Error(_) -> Ok(Nil)
    Ok(incident) -> {
      let assert Ok(_) = create_message(incident, message.Recovered(monitor))
      let assert Ok(states) = monitors.list_states_by_ids(incident.monitor_ids)
      let recovered = list.all(states, fn(state) { state.status == Up })
      // TODO - make this a setting
      case recovered {
        True -> {
          let assert Ok(incident) = auto_resolve(incident)

          incident
          |> pubsub_message.Incident()
          |> broadcast(incident)

          Ok(Nil)
        }

        False -> {
          Ok(Nil)
        }
      }
    }
  }
}

pub fn broadcast(message, incident: Incident) {
  pubsub.broadcast(
    "team:" <> int.to_string(incident.team_id),
    message
      |> pubsub_message.to_json()
      |> json.to_string(),
  )
}
