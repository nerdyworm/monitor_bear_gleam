import bear/monitors/config.{type Config, Config}
import bear/monitors/report.{type Report, Report}
import bear/monitors/status.{type Status}
import gleam/dynamic
import gleam/json

pub type MessageRecord {
  MessageRecord(id: Int, monitor_id: Int, data: Message, inserted_at: String)
}

pub type Message {
  Checked(report: Report)
  Flipped(from: Status, to: Status)
  Configured(from: Config, to: Config, user_id: Int, user_email: String)
}

pub fn record_to_json(record: MessageRecord) {
  json.object([
    #("id", json.int(record.id)),
    #("monitor_id", json.int(record.monitor_id)),
    #("data", to_json(record.data)),
    #("inserted_at", json.string(record.inserted_at)),
  ])
}

pub fn record_decoder(dynamic) {
  dynamic.decode4(
    MessageRecord,
    dynamic.field("id", dynamic.int),
    dynamic.field("monitor_id", dynamic.int),
    dynamic.field("data", decoder),
    dynamic.field("inserted_at", dynamic.string),
  )(dynamic)
}

pub fn to_json(message: Message) {
  case message {
    Checked(report: report) -> {
      json.object([
        #("checked", json.object([#("report", report.to_json(report))])),
      ])
    }

    Configured(from: from, to: to, user_id: user_id, user_email: user_email) -> {
      json.object([
        #(
          "configured",
          json.object([
            #("from", config.to_json(from)),
            #("to", config.to_json(to)),
            #("user_id", json.int(user_id)),
            #("user_email", json.string(user_email)),
          ]),
        ),
      ])
    }

    Flipped(from: from, to: to) -> {
      json.object([
        #(
          "flipped",
          json.object([
            #("from", status.to_json(from)),
            #("to", status.to_json(to)),
          ]),
        ),
      ])
    }
  }
}

pub fn decoder(dynamic) {
  dynamic.any([checked_decoder, configured_decoder, flipped_decoder])(dynamic)
}

fn checked_decoder(dynamic) {
  dynamic.field(
    "checked",
    dynamic.decode1(Checked, dynamic.field("report", report.decoder)),
  )(dynamic)
}

fn configured_decoder(dynamic) {
  dynamic.field(
    "configured",
    dynamic.decode4(
      Configured,
      dynamic.field("from", config.decoder),
      dynamic.field("to", config.decoder),
      dynamic.field("user_id", dynamic.int),
      dynamic.field("user_email", dynamic.string),
    ),
  )(dynamic)
}

fn flipped_decoder(dynamic) {
  dynamic.field(
    "flipped",
    dynamic.decode2(
      Flipped,
      dynamic.field("from", status.decoder),
      dynamic.field("to", status.decoder),
    ),
  )(dynamic)
}
