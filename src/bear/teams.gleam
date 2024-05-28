import bear/teams/team.{type Team, Limits, Team}
import bear/users/user.{type User}
import bear_server/lib/db
import gleam/dynamic
import gleam/int
import gleam/pgo

pub fn create_team(name: String) {
  db.one(
    "INSERT INTO teams (name) VALUES ($1) RETURNING " <> team_columns,
    [pgo.text(name)],
    team_decoder,
  )
}

pub fn update_team(team: Team) {
  db.one("UPDATE teams SET
    name = $2,
    plan = $3,
    limits_monitors_count = $4,
    limits_monitors_interval = $5,
    limits_monitors_messages = $6
    WHERE id = $1 RETURNING " <> team_columns, [
    pgo.int(team.id),
    pgo.text(team.name),
    pgo.text(team.plan),
    pgo.int(team.limits.monitors),
    pgo.text(team.limits.interval),
    pgo.int(team.limits.messages),
  ], team_decoder)
}

pub fn get_team(id: Int) {
  db.one(
    "SELECT " <> team_columns <> " FROM teams WHERE id = $1",
    [pgo.int(id)],
    team_decoder,
  )
}

pub fn get_user_default_team(user: User) {
  db.one("SELECT " <> team_columns <> " FROM memberships
     JOIN teams on memberships.team_id = teams.id
     WHERE memberships.user_id = $1 LIMIT 1", [pgo.int(user.id)], team_decoder)
}

const team_columns = "
    teams.id,
    teams.name,
    teams.plan,
    teams.limits_monitors_count,
    teams.limits_monitors_interval,
    teams.limits_monitors_messages
  "

fn team_decoder(dynamic) {
  dynamic.decode4(
    Team,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, dynamic.string),
    dynamic.decode3(
      Limits,
      dynamic.element(3, dynamic.int),
      dynamic.element(4, dynamic.string),
      dynamic.element(5, dynamic.int),
    ),
  )(dynamic)
}

pub fn update_plan(team_id: String, name: String) {
  let assert Ok(id) = int.parse(team_id)
  let assert Ok(team) = get_team(id)

  let limits = case name {
    "business" -> Limits(monitors: 50, interval: "10 seconds", messages: 200)
    "startup" -> Limits(monitors: 25, interval: "30 seconds", messages: 100)
    "indie" -> Limits(monitors: 10, interval: "1 minute", messages: 100)
    _ -> Limits(monitors: 3, interval: "3 minutes", messages: 50)
  }

  update_team(Team(..team, plan: name, limits: limits))
}
