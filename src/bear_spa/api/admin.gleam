import bear/invitations/invitation.{type Invitation}
import bear/memberships/membership.{type Membership}
import bear/teams/team
import bear/users/user.{type User}
import bear_spa/api.{type ApiError}
import bear_spa/app.{type App}
import gleam/dynamic
import gleam/int
import gleam/json

pub type MembershipPayload {
  MembershipPayload(users: List(User), memberships: List(Membership))
}

pub fn get_team(app: App, response) {
  api.get2("/team", team.decoder, response, app)
}

pub fn list_memberships(
  app: App,
  response: fn(Result(MembershipPayload, ApiError)) -> msg,
) {
  api.get2("/memberships", membership_payload_decoder, response, app)
}

fn membership_payload_decoder(dynamic) {
  dynamic.decode2(
    MembershipPayload,
    dynamic.field("users", dynamic.list(user.decoder)),
    dynamic.field("memberships", dynamic.list(membership.decoder)),
  )(dynamic)
}

pub fn create_invitation(
  invitation: Invitation,
  app: App,
  response: fn(Result(MembershipPayload, ApiError)) -> msg,
) {
  api.post(
    "/invitations",
    invitation.to_json(invitation),
    api.expect(membership_payload_decoder, response),
    app,
  )
}

pub fn update_membership(
  membership: Membership,
  app: App,
  response: fn(Result(Membership, ApiError)) -> msg,
) {
  api.put(
    "/memberships/" <> int.to_string(membership.user_id),
    membership.to_json(membership),
    api.expect(membership.decoder, response),
    app,
  )
}

pub fn delete_membership(
  membership: Membership,
  app: App,
  response: fn(Result(Membership, ApiError)) -> msg,
) {
  api.delete(
    "/memberships/" <> int.to_string(membership.user_id),
    membership.to_json(membership),
    api.expect(membership.decoder, response),
    app,
  )
}

pub fn create_checkout_session(
  name: String,
  app: App,
  response: fn(Result(String, ApiError)) -> msg,
) {
  api.post(
    "/checkout_session",
    json.object([#("name", json.string(name))]),
    api.expect(dynamic.string, response),
    app,
  )
}
