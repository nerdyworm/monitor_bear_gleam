import gleam/dynamic
import gleam/json

pub type Limits {
  Limits(monitors: Int, interval: String, messages: Int)
}

pub type Team {
  Team(id: Int, name: String, plan: String, limits: Limits)
}

pub fn new() {
  Team(
    id: 0,
    name: "",
    plan: "free",
    limits: Limits(monitors: 3, interval: "5 minutes", messages: 20),
  )
}

pub fn to_json(team: Team) {
  json.object([
    #("id", json.int(team.id)),
    #("name", json.string(team.name)),
    #("plan", json.string(team.plan)),
    #(
      "limits",
      json.object([
        #("monitors", json.int(team.limits.monitors)),
        #("interval", json.string(team.limits.interval)),
        #("messages", json.int(team.limits.messages)),
      ]),
    ),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode4(
    Team,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("plan", dynamic.string),
    dynamic.field(
      "limits",
      dynamic.decode3(
        Limits,
        dynamic.field("monitors", dynamic.int),
        dynamic.field("interval", dynamic.string),
        dynamic.field("messages", dynamic.int),
      ),
    ),
  )(dynamic)
}
