import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/uri.{type Uri}

pub type Rules =
  List(Validates)

pub type Errors {
  Errors(name: String, errors: List(String))
}

pub type Validates {
  S(name: String, value: String, errors: List(String))
  I(name: String, value: Int, errors: List(String))
}

pub fn rules() {
  []
}

pub fn string(name: String, value: String) {
  S(name: name, value: value, errors: [])
}

pub fn int(name: String, value: Int) {
  I(name: name, value: value, errors: [])
}

pub fn required(validates: Validates) {
  case validates {
    S(name: name, value: value, errors: errors) if value == "" ->
      S(name: name, value: value, errors: ["can't be blank", ..errors])

    S(name: name, value: value, errors: errors) ->
      S(name: name, value: value, errors: errors)

    I(name: name, value: value, errors: errors) if value == 0 ->
      I(name: name, value: value, errors: ["can't be zero", ..errors])

    I(name: name, value: value, errors: errors) ->
      I(name: name, value: value, errors: errors)
  }
}

pub fn range(validates: Validates, min: Int, max: Int) {
  case validates {
    I(name: name, value: value, errors: errors) if value >= min && value <= max ->
      I(name: name, value: value, errors: errors)

    I(name: name, value: value, errors: errors) ->
      I(name: name, value: value, errors: [invalid_range(min, max), ..errors])

    _ -> validates
  }
}

pub fn in(validates: Validates, options: List(String)) -> Validates {
  case validates {
    S(name: name, value: value, errors: errors) ->
      case list.contains(options, value) {
        True -> S(name: name, value: value, errors: errors)

        False ->
          S(name: name, value: value, errors: ["is not an option", ..errors])
      }

    _ -> validates
  }
}

pub fn url(validates: Validates) -> Validates {
  case validates {
    S(name: name, value: value, errors: errors) ->
      case uri.parse(value) {
        Ok(uri.Uri(Some("https"), _, Some(_), _, _, _, _)) ->
          S(name: name, value: value, errors: errors)

        Ok(uri.Uri(Some("http"), _, Some(_), _, _, _, _)) ->
          S(name: name, value: value, errors: errors)

        _ ->
          S(name: name, value: value, errors: ["is not an valid url", ..errors])
      }

    _ -> validates
  }
}

fn invalid_range(min: Int, max: Int) {
  "not in valid range ("
  <> int.to_string(min)
  <> ", "
  <> int.to_string(max)
  <> ")"
}

pub fn errors(validates: Validates) -> List(String) {
  validates.errors
}

pub fn add(rules: Rules, validates: Validates) -> Rules {
  list.append(rules, [validates])
}

pub fn validate(rules: Rules) -> List(Errors) {
  list.fold(rules, [], fn(acc, rule) {
    case rule.errors == [] {
      True -> acc
      False -> [Errors(rule.name, rule.errors), ..acc]
    }
  })
  |> list.reverse()
}

pub fn result(rules: Rules, anything: a) -> Result(a, List(Errors)) {
  case validate(rules) {
    [] -> Ok(anything)
    errors -> Error(errors)
  }
}

pub fn result_map_error(rules: Rules, anything, to_error) {
  case validate(rules) {
    [] -> Ok(anything)
    errors -> Error(to_error(errors))
  }
}

pub fn to_json(errors: List(Errors)) {
  json.array(errors, error_to_json)
}

fn error_to_json(error: Errors) {
  json.object([
    #("name", json.string(error.name)),
    #("errors", json.array(error.errors, json.string)),
  ])
}

pub fn decoder(dynamic: Dynamic) -> Result(List(Errors), List(DecodeError)) {
  dynamic.list(dynamic.decode2(
    Errors,
    dynamic.field("name", dynamic.string),
    dynamic.field("errors", dynamic.list(dynamic.string)),
  ))(dynamic)
}

pub fn error_on(errors: List(Errors), name: String) -> Result(List(String), Nil) {
  case list.find(errors, fn(error) { error.name == name }) {
    Ok(Errors(name: _, errors: errors)) -> Ok(errors)
    Error(Nil) -> Error(Nil)
  }
}
