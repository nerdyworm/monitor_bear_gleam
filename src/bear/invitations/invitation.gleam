import gleam/dynamic
import gleam/json

pub type Invitation {
  Invitation(emails: String, role: String, tags: String)
}

pub fn new() {
  Invitation(emails: "", role: "user", tags: "")
}

pub fn decoder(dynamic) {
  dynamic.decode3(
    Invitation,
    dynamic.field("emails", dynamic.string),
    dynamic.field("role", dynamic.string),
    dynamic.field("tags", dynamic.string),
  )(dynamic)
}

pub fn to_json(invitation: Invitation) {
  json.object([
    #("emails", json.string(invitation.emails)),
    #("role", json.string(invitation.role)),
    #("tags", json.string(invitation.tags)),
  ])
}
