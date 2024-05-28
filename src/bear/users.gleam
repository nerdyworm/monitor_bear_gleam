import bear/memberships/membership.{type Membership}
import bear/users/user.{type User, User}
import bear_server/lib/db
import beecrypt
import gleam/dynamic
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/pgo
import gleam/string
import wisp

pub fn get_user_by_email(email: String) {
  db.get(
    "SELECT id, email FROM users WHERE email = $1",
    [pgo.text(email)],
    user_decoder,
  )
}

pub fn list_users_by_memberships(memberships: List(Membership)) {
  list.map(memberships, fn(m) { m.user_id })
  |> list_users_by_id()
}

pub fn list_users_by_id(user_ids: List(Int)) {
  let ids =
    list.map(user_ids, int.to_string)
    |> string.join(",")

  db.execute(
    "SELECT id, email FROM users WHERE id in (select unnest(string_to_array($1, ',')::int[]))",
    [pgo.text(ids)],
    user_decoder,
  )
}

pub fn list_users_by_tag(team_id: Int, tags: List(String)) {
  db.all(
    "
    SELECT id, email FROM users JOIN memberships ON memberships.user_id = users.id
    WHERE memberships.team_id = $1 AND memberships.tags && $2
    ",
    [pgo.int(team_id), pgo.array(tags, pgo.text)],
    user_decoder,
  )
}

pub fn create_session_token(user: User) {
  use <- db.transaction()
  let assert Ok(_) = delete_password_reset_tokens(user)

  db.one(
    "INSERT INTO user_tokens (user_id, token, context) VALUES ($1, $2, $3) RETURNING token",
    [pgo.int(user.id), pgo.text(wisp.random_string(32)), pgo.text("session")],
    dynamic.element(0, dynamic.string),
  )
}

pub fn delete_password_reset_tokens(user: User) {
  db.execute(
    "DELETE FROM user_tokens WHERE user_id = $1 AND context = 'password_reset'",
    [pgo.int(user.id)],
    dynamic.dynamic,
  )
}

pub fn get_user_by_session_token(token: String) {
  db.one(
    "
    SELECT users.id, users.email FROM user_tokens
      JOIN users ON user_tokens.user_id = users.id
      WHERE token = $1 AND context = 'session' AND user_tokens.inserted_at > now() - interval '30 days'
    ",
    [pgo.text(token)],
    user_decoder,
  )
}

pub fn create_reset_password_token(user: User) {
  db.one(
    "INSERT INTO user_tokens (user_id, token, context, sent_to) VALUES ($1, $2, $3, $4) RETURNING token",
    [
      pgo.int(user.id),
      pgo.text(wisp.random_string(32)),
      pgo.text("reset_password"),
      pgo.text(user.email),
    ],
    dynamic.element(0, dynamic.string),
  )
}

pub fn get_user_by_reset_password_token(token: String) {
  db.get(
    "
    SELECT users.id, users.email FROM user_tokens
      JOIN users ON user_tokens.user_id = users.id
      WHERE token = $1 AND context = 'reset_password' AND user_tokens.inserted_at > now() - interval '30 days'
    ",
    [pgo.text(token)],
    user_decoder,
  )
}

pub fn create_user_with_email(email: String) {
  db.one(
    "INSERT INTO users (email) VALUES ($1) RETURNING id, email",
    [pgo.text(email)],
    user_decoder,
  )
}

pub fn create_user_with_email_and_password(email: String, password: String) {
  let hashed_password = hash_password(password)

  db.one(
    "INSERT INTO users (email, hashed_password) VALUES ($1, $2) RETURNING id, email",
    [pgo.text(email), pgo.text(hashed_password)],
    user_decoder,
  )
}

pub fn update_user_password(user: User, password: String) {
  let hashed_password = hash_password(password)

  db.one(
    "UPDATE users SET hashed_password = $2 WHERE id = $1 RETURNING id, email",
    [pgo.int(user.id), pgo.text(hashed_password)],
    user_decoder,
  )
}

pub fn verify_password(user: User, password: String) {
  let result =
    db.get(
      "SELECT hashed_password FROM users WHERE id = $1",
      [pgo.int(user.id)],
      dynamic.element(0, dynamic.optional(dynamic.string)),
    )

  case result {
    Ok(maybe_hashed_password) -> {
      case maybe_hashed_password {
        None -> False
        Some(hashed_password) -> do_verify_password(password, hashed_password)
      }
    }

    Error(Nil) -> {
      False
    }
  }
}

fn user_decoder(dynamic) {
  dynamic.decode2(
    User,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
  )(dynamic)
}

@target(erlang)
fn hash_password(password) {
  beecrypt.hash(password)
}

@target(javascript)
fn hash_password(_) {
  panic as "erlang only"
}

@target(erlang)
fn do_verify_password(password, hashed_password) {
  beecrypt.verify(password, hashed_password)
}

@target(javascript)
fn do_verify_password(_, _) {
  panic as "erlang only"
}
