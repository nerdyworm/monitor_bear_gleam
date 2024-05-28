import bear/teams
import gleam/int
import gleeunit/should

@target(erlang)
pub fn setup_team_test() {
  let assert Ok(team) = teams.create_team("testing")

  let team =
    teams.update_plan(int.to_string(team.id), "antyhign")
    |> should.be_ok()

  should.equal(team.limits.monitors, 3)
  should.equal(team.limits.messages, 50)
  should.equal(team.limits.interval, "3 minutes")

  let team =
    teams.update_plan(int.to_string(team.id), "business")
    |> should.be_ok()
  should.equal(team.limits.monitors, 50)

  should.equal(team.limits.messages, 200)
  should.equal(team.limits.interval, "10 seconds")
}
// pub fn verify_signature_test() {
//   let header =
//     "t=1715353739,v1=468cdbb0b1588e8b349c5e308652b8e307e25698ef50fbab88198483c285a8e4,v0=72158d99f3244071002e0ea0540becd6828c2a5cf41a72d3f2b7e5150539e41a"
//   let assert Ok(priv) = erlang.priv_directory("bear")
//   let assert Ok(payload) = simplifile.read(priv <> "/fixtures/webhook.json")
//   stripe.verify_signature(header, payload)
//   |> should.equal(Ok(True))
// }
