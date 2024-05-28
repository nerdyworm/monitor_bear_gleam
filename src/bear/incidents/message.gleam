import bear/monitors/monitor.{type Monitor}
import bear/monitors/report.{type Report, Report}
import bear/users/user.{type User}
import gleam/dynamic
import gleam/json

pub type Record {
  Record(id: Int, incident_id: Int, data: Message, inserted_at: String)
}

pub type Message {
  Checked(report: Report, monitor_id: Int)
  EmailedUser(user: User)
  EmailedEmail(email: String)
  Resolved(by: User)
  ResolvedOnUp
  Started(monitor: Monitor)
  Continued(monitor: Monitor)
  Recovering(monitor: Monitor)
  Recovered(monitor: Monitor)
}

pub fn record_to_json(record: Record) {
  json.object([
    #("id", json.int(record.id)),
    #("incident_id", json.int(record.incident_id)),
    #("data", to_json(record.data)),
    #("inserted_at", json.string(record.inserted_at)),
  ])
}

pub fn record_decoder(dynamic) {
  dynamic.decode4(
    Record,
    dynamic.field("id", dynamic.int),
    dynamic.field("incident_id", dynamic.int),
    dynamic.field("data", decoder),
    dynamic.field("inserted_at", dynamic.string),
  )(dynamic)
}

pub fn to_json(message: Message) {
  case message {
    // same as monitor messsage...
    Checked(report: report, monitor_id: monitor_id) -> {
      json.object([
        #(
          "checked",
          json.object([
            #("report", report.to_json(report)),
            #("monitor_id", json.int(monitor_id)),
          ]),
        ),
      ])
    }

    Started(monitor) -> {
      json.object([
        #("started", json.object([#("monitor", monitor.to_json(monitor))])),
      ])
    }

    Continued(monitor) -> {
      json.object([
        #("continued", json.object([#("monitor", monitor.to_json(monitor))])),
      ])
    }

    Resolved(user) -> {
      json.object([#("resolved", json.object([#("by", user.to_json(user))]))])
    }

    ResolvedOnUp -> {
      json.object([#("resolved_on_up", json.object([]))])
    }

    EmailedUser(user) -> {
      json.object([#("emailed", json.object([#("user", user.to_json(user))]))])
    }

    EmailedEmail(email) -> {
      json.object([#("emailed", json.object([#("email", json.string(email))]))])
    }

    Recovering(monitor) -> {
      json.object([
        #("recovering", json.object([#("monitor", monitor.to_json(monitor))])),
      ])
    }

    Recovered(monitor) -> {
      json.object([
        #("recovered", json.object([#("monitor", monitor.to_json(monitor))])),
      ])
    }
  }
}

pub fn decoder(dynamic) {
  dynamic.any([
    started_decoder,
    checked_decoder,
    resolved_decoder,
    resolved_on_up_decoder,
    emailed_user_decoder,
    emailed_email_decoder,
    recovering_decoder,
    recovered_decoder,
    continued_decoder,
  ])(dynamic)
}

fn started_decoder(dynamic) {
  dynamic.field(
    "started",
    dynamic.decode1(Started, dynamic.field("monitor", monitor.decoder)),
  )(dynamic)
}

fn checked_decoder(dynamic) {
  dynamic.field(
    "checked",
    dynamic.decode2(
      Checked,
      dynamic.field("report", report.decoder),
      dynamic.field("monitor_id", dynamic.int),
    ),
  )(dynamic)
}

fn resolved_decoder(dynamic) {
  dynamic.field(
    "resolved",
    dynamic.decode1(Resolved, dynamic.field("by", user.decoder)),
  )(dynamic)
}

fn resolved_on_up_decoder(dynamic) {
  dynamic.field("resolved_on_up", fn(_) { Ok(ResolvedOnUp) })(dynamic)
}

fn emailed_user_decoder(dynamic) {
  dynamic.field(
    "emailed",
    dynamic.decode1(EmailedUser, dynamic.field("user", user.decoder)),
  )(dynamic)
}

fn emailed_email_decoder(dynamic) {
  dynamic.field(
    "emailed",
    dynamic.decode1(EmailedEmail, dynamic.field("email", dynamic.string)),
  )(dynamic)
}

fn recovering_decoder(dynamic) {
  dynamic.field(
    "recovering",
    dynamic.decode1(Recovering, dynamic.field("monitor", monitor.decoder)),
  )(dynamic)
}

fn recovered_decoder(dynamic) {
  dynamic.field(
    "recovered",
    dynamic.decode1(Recovered, dynamic.field("monitor", monitor.decoder)),
  )(dynamic)
}

fn continued_decoder(dynamic) {
  dynamic.field(
    "continued",
    dynamic.decode1(Continued, dynamic.field("monitor", monitor.decoder)),
  )(dynamic)
}
