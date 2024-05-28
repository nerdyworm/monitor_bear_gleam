import bear/error.{Validation}
import gleam/dynamic
import gleam/json
import validates

pub type User {
  User(id: Int, email: String)
}

pub fn new() {
  User(id: 0, email: "")
}

pub fn to_json(user: User) {
  json.object([#("id", json.int(user.id)), #("email", json.string(user.email))])
}

pub fn decoder(dynamic) {
  dynamic.decode2(
    User,
    dynamic.field("id", dynamic.int),
    dynamic.field("email", dynamic.string),
  )(dynamic)
}

pub fn validate(user: User) {
  validates.rules()
  |> validates.add(
    validates.string("email", user.email)
    |> validates.required(),
  )
  |> validates.result_map_error(user, Validation)
}
