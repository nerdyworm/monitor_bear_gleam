import gleam/dynamic
import gleam/json

pub type Membership {
  Membership(user_id: Int, team_id: Int, role: String, tags: List(String))
}

pub fn new() {
  Membership(user_id: 0, team_id: 0, role: "user", tags: [])
}

pub fn to_json(membership: Membership) {
  json.object([
    #("user_id", json.int(membership.user_id)),
    #("team_id", json.int(membership.team_id)),
    #("role", json.string(membership.role)),
    #("tags", json.array(membership.tags, json.string)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode4(
    Membership,
    dynamic.field("user_id", dynamic.int),
    dynamic.field("team_id", dynamic.int),
    dynamic.field("role", dynamic.string),
    dynamic.field("tags", dynamic.list(dynamic.string)),
  )(dynamic)
}
