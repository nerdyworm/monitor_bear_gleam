import bear/invitations
import bear/invitations/invitation
import bear/memberships
import bear/memberships/membership
import bear/scope.{type Scope}
import bear/users
import bear/users/user
import bear_server/render
import gleam/json
import wisp.{type Request, type Response}

pub fn index(scope: Scope, _req: Request) -> Response {
  let assert Ok(memberships) = memberships.list_memberships(scope)
  let assert Ok(users) = users.list_users_by_memberships(memberships.rows)

  json.object([
    #("memberships", json.array(memberships.rows, membership.to_json)),
    #("users", json.array(users.rows, user.to_json)),
  ])
  |> json.to_string_builder()
  |> wisp.json_response(200)
}

pub fn create_invitation(scope: Scope, req: Request) {
  use params <- wisp.require_json(req)
  let assert Ok(invite) = invitation.decoder(params)

  case invitations.create_invitation(scope, invite) {
    Ok(memberships) -> {
      let assert Ok(users) = users.list_users_by_memberships(memberships)

      [
        #("memberships", json.array(memberships, membership.to_json)),
        #("users", json.array(users.rows, user.to_json)),
      ]
      |> json.object()
      |> render.json(200)
    }

    Error(error) -> {
      render.error(error)
    }
  }
}

pub fn update(scope: Scope, req: Request) -> Response {
  use params <- wisp.require_json(req)
  let assert Ok(params) = membership.decoder(params)

  memberships.update_membership(scope.team.id, params)
  |> render.respond(membership.to_json)
}

pub fn delete(scope: Scope, req: Request) -> Response {
  use params <- wisp.require_json(req)
  let assert Ok(params) = membership.decoder(params)

  memberships.delete_membership(scope, params)
  |> render.respond(membership.to_json)
}
