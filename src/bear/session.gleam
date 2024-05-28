import gleam/dynamic
import gleam/json

pub type Session {
  Session(token: String, email: String)
}

pub fn new(email: String) {
  Session(token: "TODO-uuid", email: email)
}

pub fn decoder(dynamic) {
  dynamic.decode2(
    Session,
    dynamic.field("token", dynamic.string),
    dynamic.field("email", dynamic.string),
  )(dynamic)
}

pub fn to_json(session: Session) {
  json.object([
    #("token", json.string(session.token)),
    #("email", json.string(session.email)),
  ])
}

pub fn from_string(string) {
  json.decode(string, decoder)
}
