import bear/alerts
import bear/alerts/alert
import bear/error
import bear/memberships
import bear/scope
import bear/teams
import bear/users
import bear/users/user.{type User, User}
import bear_server/lib/db
import gleam/pgo
import gleam/result
import gleam/string
import validates.{Errors}

pub fn register_user(email: String, password: String) {
  let user = User(id: 0, email: email)
  use _ <- result.try(user.validate(user))
  use <- db.transaction()

  case users.create_user_with_email_and_password(email, password) {
    Ok(user) -> {
      let assert Ok(team) = teams.create_team("My Team")
      let assert Ok(_) =
        memberships.create_membership(user.id, team.id, "owner", ["all"])
      let scope = scope.new(user, team)
      let assert Ok(_) = alerts.create_alert(scope, alert.default())
      Ok(user)
    }

    Error(error.DatabaseError(pgo.ConstraintViolated(_, "idx_users_email", _))) ->
      Error(error.Validation([Errors("email", ["already taken"])]))

    Error(other) -> {
      panic as string.inspect(other)
    }
  }
}
