import bear/config
import bear/error.{type BearError}
import bear/invitations/invitation.{type Invitation}
import bear/mailer
import bear/memberships
import bear/memberships/membership.{type Membership}
import bear/scope.{type Scope}
import bear/users
import bear/users/user.{type User}
import bear_server/lib/db
import gleam/list
import gleam/string
import lib/email
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn create_invitation(
  scope: Scope,
  invitation: Invitation,
) -> Result(List(Membership), BearError) {
  string.split(invitation.emails, ",")
  |> list.map(string.trim)
  |> list.map(fn(email) {
    use <- db.transaction()
    let user = case users.get_user_by_email(email) {
      Ok(user) -> {
        user
      }

      Error(Nil) -> {
        let assert Ok(user) = users.create_user_with_email(email)
        user
      }
    }

    let assert Ok(membership) =
      memberships.create_membership(
        user.id,
        scope.team.id,
        invitation.role,
        string.split(invitation.tags, ",")
          |> list.map(string.trim),
      )

    let assert Ok(token) = users.create_reset_password_token(user)

    let assert Ok(_) =
      message(scope, user, token)
      |> mailer.deliver()

    membership
  })
  |> Ok
}

fn message(scope: Scope, user: User, token: String) {
  let link = config.endpoint() <> "/users/reset_password/" <> token

  email.new()
  |> email.from(config.system_email())
  |> email.to(user.email)
  |> email.subject(scope.user.email <> " has invited you to monitor bear!")
  |> email.html_body(
    html.div([], [
      html.p([], [
        html.text("You have a new account to setup on monitor bear!  Awesome!"),
      ]),
      html.p([], [html.text("Please click the link to setup your account:")]),
      html.p([], [html.a([attribute.href(link)], [html.text(link)])]),
    ])
    |> element.to_string(),
  )
}
