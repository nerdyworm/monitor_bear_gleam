import bear/incidents/incident.{type Incident}
import bear/incidents/message as incidents_message
import bear/monitors/message.{type MessageRecord}
import bear/monitors/state.{type State}
import gleam/dynamic
import gleam/json

pub type PubsubMessage {
  MonitorMessageRecord(MessageRecord)
  IncidentMessageRecord(incidents_message.Record)
  Incident(Incident)
  MonitorState(State)
}

pub fn to_json(pubsub: PubsubMessage) {
  case pubsub {
    MonitorMessageRecord(record) ->
      json.object([#("message_record", message.record_to_json(record))])

    IncidentMessageRecord(record) ->
      json.object([
        #("incident_record", incidents_message.record_to_json(record)),
      ])
    Incident(incident) ->
      json.object([#("incident", incident.to_json(incident))])

    MonitorState(state) ->
      json.object([#("monitor_state", state.to_json(state))])
  }
}

pub fn decoder(dynamic) {
  dynamic.any([
    monitor_message_decoder,
    monitor_state_decoder,
    incident_message_decoder,
    incident_decoder,
  ])(dynamic)
}

fn monitor_message_decoder(dynamic) {
  dynamic.decode1(
    MonitorMessageRecord,
    dynamic.field("message_record", message.record_decoder),
  )(dynamic)
}

fn monitor_state_decoder(dynamic) {
  dynamic.decode1(MonitorState, dynamic.field("monitor_state", state.decoder))(
    dynamic,
  )
}

fn incident_message_decoder(dynamic) {
  dynamic.decode1(
    IncidentMessageRecord,
    dynamic.field("incident_record", incidents_message.record_decoder),
  )(dynamic)
}

fn incident_decoder(dynamic) {
  dynamic.decode1(Incident, dynamic.field("incident", incident.decoder))(
    dynamic,
  )
}
