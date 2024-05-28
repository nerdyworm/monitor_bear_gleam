import bear/alerts
import bear/alerts/alert.{Alert}
import bear/memberships
import bear/monitors
import bear/monitors/config.{Config}
import bear/monitors/flip.{Flip}
import bear/monitors/monitor.{Monitor}
import bear/monitors/report
import bear/monitors/status.{New, Up}
import bear/monitors_checked
import bear/scope
import bear/teams
import bear/users
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import wisp

@target(erlang)
fn new_scope() {
  let prefix = wisp.random_string(16)
  let assert Ok(user) =
    users.create_user_with_email(prefix <> "_bob@testing.com")
  let assert Ok(team) = teams.create_team("testing")
  scope.new(user, team)
}

fn monitor_fixture() {
  let monitor = monitor.new()
  Monitor(
    ..monitor,
    name: "testing",
    config: Config(..monitor.config, url: "http://monitorbear.com"),
  )
}

fn alert_fixture() {
  Alert(..alert.new(), name: "testing")
}

@target(erlang)
pub fn healthcheck_test() {
  let scope = new_scope()
  let assert Ok(monitor) = monitors.create_monitor(scope, monitor_fixture())
  should.not_equal(0, monitor.id)

  let state =
    monitors.get_state(monitor)
    |> should.be_ok()

  should.equal(state.status, New)
  should.equal(state.missed, 0)
  should.equal(state.events, 0)

  report.new()
  |> report.runtime(69)
  |> monitors_checked.checked(monitor)
  |> should.be_ok()

  let state =
    monitors.get_state(monitor)
    |> should.be_ok()

  should.equal(state.status, Up)
  should.equal(state.missed, 0)
  should.equal(state.events, 1)
}

@target(erlang)
pub fn alerts_test() {
  let scope = new_scope()
  let assert Ok(monitor) = monitors.create_monitor(scope, monitor_fixture())
  let assert Ok(_) = alerts.create_alert(scope, alert_fixture())

  let flip =
    Flip(
      id: 0,
      monitor_id: monitor.id,
      from: status.Up,
      to: status.Down,
      inserted_at: "",
    )
  alerts.trigger_monitor_flipped(monitor, flip)
}

@target(erlang)
pub fn next_region_test() {
  monitors.next_region(["a", "b", "c"], None)
  |> should.equal(Some("a"))

  monitors.next_region(["a", "b", "c"], Some("a"))
  |> should.equal(Some("b"))

  monitors.next_region(["a", "b", "c"], Some("b"))
  |> should.equal(Some("c"))

  monitors.next_region(["a", "b", "c"], Some("c"))
  |> should.equal(Some("a"))

  monitors.next_region([], Some("c"))
  |> should.equal(None)

  monitors.next_region(["a", "b"], Some("c"))
  |> should.equal(Some("a"))
}

@target(erlang)
pub fn intervals_test() {
  let scope = new_scope()

  config.intervals_for_team(scope.team)
  |> should.equal(["1 hour", "30 minutes", "5 minutes"])
}

@target(erlang)
pub fn list_users_by_tag_test() {
  let assert Ok(team) = teams.create_team("testing")

  let assert Ok(user1) =
    users.create_user_with_email(wisp.random_string(16) <> "_bob@testing.com")
  let assert Ok(user2) =
    users.create_user_with_email(wisp.random_string(16) <> "_bob@testing.com")
  let assert Ok(user3) =
    users.create_user_with_email(wisp.random_string(16) <> "_bob@testing.com")

  let assert Ok(_) =
    memberships.create_membership(user1.id, team.id, "owner", ["all", "1"])
  let assert Ok(_) =
    memberships.create_membership(user2.id, team.id, "owner", ["all", "2"])
  let assert Ok(_) =
    memberships.create_membership(user3.id, team.id, "owner", ["all", "3"])

  users.list_users_by_tag(team.id, ["all"])
  |> should.be_ok()
  |> list.map(fn(user) { user.id })
  |> should.equal([user1.id, user2.id, user3.id])

  users.list_users_by_tag(team.id, ["3"])
  |> should.be_ok()
  |> list.map(fn(user) { user.id })
  |> should.equal([user3.id])

  users.list_users_by_tag(team.id, ["2", "3", "not found"])
  |> should.be_ok()
  |> list.map(fn(user) { user.id })
  |> should.equal([user2.id, user3.id])
}
