import bear/error
import bear/memberships/membership.{type Membership, Membership}
import bear/scope.{type Scope}
import bear/tags
import bear_server/lib/db
import gleam/dynamic
import gleam/pgo

const membership_columns = "
  memberships.user_id,
  memberships.team_id,
  memberships.role,
  memberships.tags"

fn membership_decoder(dynamic) {
  dynamic.decode4(
    Membership,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, dynamic.string),
    dynamic.element(3, dynamic.list(dynamic.string)),
  )(dynamic)
}

pub fn create_membership(
  user_id: Int,
  team_id: Int,
  role: String,
  tags: List(String),
) {
  db.one(
    "
    INSERT INTO memberships (user_id, team_id, role, tags) VALUES ($1, $2, $3, $4)
    ON CONFLICT (user_id, team_id) 
    DO UPDATE SET role = EXCLUDED.role, tags = EXCLUDED.tags
    RETURNING user_id, team_id, role, tags
    ",
    [
      pgo.int(user_id),
      pgo.int(team_id),
      pgo.text(role),
      pgo.array(tags.trim(tags), pgo.text),
    ],
    membership_decoder,
  )
}

pub fn update_membership(team_id: Int, membership: Membership) {
  db.one(
    "
    INSERT INTO memberships (team_id, user_id, role, tags) VALUES ($1, $2, $3, $4)
    ON CONFLICT (user_id, team_id) 
    DO UPDATE SET role = EXCLUDED.role, tags = EXCLUDED.tags
    RETURNING user_id, team_id, role, tags
    ",
    [
      pgo.int(team_id),
      pgo.int(membership.user_id),
      pgo.text(membership.role),
      pgo.text_array(tags.trim(membership.tags)),
    ],
    membership_decoder,
  )
}

pub fn delete_membership(scope: Scope, membership: Membership) {
  case scope.user.id == membership.user_id {
    True -> Error(error.ErrorMessage("can not delete own membershp"))

    False ->
      db.one(
        "DELETE FROM memberships WHERE team_id = $1 AND user_id = $2 RETURNING user_id, team_id, role, tags",
        [pgo.int(scope.team.id), pgo.int(membership.user_id)],
        membership_decoder,
      )
  }
}

pub fn list_memberships(scope: Scope) {
  list_memberships_by_team_id(scope.team.id)
}

pub fn list_memberships_by_team_id(team_id: Int) {
  db.execute(
    "SELECT " <> membership_columns <> " FROM memberships WHERE team_id = $1",
    [pgo.int(team_id)],
    membership_decoder,
  )
}
