import bear/memberships
import bear/teams
import bear/users
import bear/users/user.{User}
import gleam/list
import gleeunit/should
import wisp

@target(erlang)
pub fn user_password_test() {
  let prefix = wisp.random_string(16)

  let assert Ok(user) =
    users.create_user_with_email_and_password(
      prefix <> "_bob@testing.com",
      "password1234",
    )

  users.verify_password(user, "notgood")
  |> should.be_false

  users.verify_password(user, "password1234")
  |> should.be_true

  users.verify_password(User(..user, id: -1), "password1234")
  |> should.be_false
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
