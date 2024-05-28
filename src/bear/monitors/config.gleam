import bear/monitors/assertion.{type Assertion}
import bear/teams/team.{type Team}
import gleam/dynamic
import gleam/json
import gleam/list

pub type Header {
  Header(name: String, value: String)
}

pub type Request {
  Request(method: String, headers: List(Header), body: String, timeout: Int)
}

pub type Config {
  Config(
    interval: String,
    url: String,
    regions: List(String),
    assertions: List(Assertion),
    tolerance: Int,
    recovery: Int,
    request: Request,
  )
}

pub fn new() -> Config {
  Config(
    interval: "5 minutes",
    url: "",
    regions: ["us-east", "us-west"],
    assertions: assertion.new_check_defaults(),
    tolerance: 3,
    recovery: 1,
    request: Request(
      method: "get",
      headers: [Header(name: "X-Monitor-Bear", value: "Rawr")],
      body: "",
      timeout: 5000,
    ),
  )
}

pub fn interval_options() -> List(String) {
  [
    "1 hour", "30 minutes", "5 minutes", "3 minutes", "1 minute", "30 seconds",
    "10 seconds",
  ]
}

pub fn intervals_for_team(team: Team) {
  interval_options()
  |> list.take_while(fn(option) { option != team.limits.interval })
  |> list.append([team.limits.interval])
}

pub fn to_json(config: Config) {
  json.object([
    #("interval", json.string(config.interval)),
    #("url", json.string(config.url)),
    #("regions", json.array(config.regions, json.string)),
    #("assertions", json.array(config.assertions, assertion.to_json)),
    #("tolerance", json.int(config.tolerance)),
    #("recovery", json.int(config.recovery)),
    #("request", request_to_json(config.request)),
  ])
}

pub fn decoder(dynamic) {
  dynamic.decode7(
    Config,
    dynamic.field("interval", dynamic.string),
    dynamic.field("url", dynamic.string),
    dynamic.field("regions", dynamic.list(dynamic.string)),
    dynamic.field("assertions", dynamic.list(assertion.decoder)),
    dynamic.field("tolerance", dynamic.int),
    dynamic.field("recovery", dynamic.int),
    dynamic.field("request", request_decoder),
  )(dynamic)
}

pub fn request_decoder(dynamic) {
  dynamic.decode4(
    Request,
    dynamic.field("method", dynamic.string),
    dynamic.field("headers", dynamic.list(header_decoder)),
    dynamic.field("body", dynamic.string),
    dynamic.field("timeout", dynamic.int),
  )(dynamic)
}

pub fn header_decoder(dynamic) {
  dynamic.decode2(
    Header,
    dynamic.field("name", dynamic.string),
    dynamic.field("value", dynamic.string),
  )(dynamic)
}

pub fn request_to_json(request: Request) {
  json.object([
    #("method", json.string(request.method)),
    #("headers", json.array(request.headers, header_to_json)),
    #("body", json.string(request.body)),
    #("timeout", json.int(request.timeout)),
  ])
}

pub fn header_to_json(header: Header) {
  json.object([
    #("name", json.string(header.name)),
    #("value", json.string(header.value)),
  ])
}

pub fn replace_header_at(config: Config, index: Int, updated: Header) {
  let headers =
    list.index_map(config.request.headers, fn(header, idx) {
      case index == idx {
        True -> updated
        False -> header
      }
    })

  Config(..config, request: Request(..config.request, headers: headers))
}

pub fn new_header(config: Config) {
  Config(
    ..config,
    request: Request(
      ..config.request,
      headers: list.append(config.request.headers, [Header("", "")]),
    ),
  )
}

pub fn remove_header_at(config: Config, index: Int) {
  let headers =
    config.request.headers
    |> list.index_fold([], fn(acc, header, i) {
      case i == index {
        True -> acc
        False -> [header, ..acc]
      }
    })
    |> list.reverse()

  Config(..config, request: Request(..config.request, headers: headers))
}

pub fn validate(config: Config) {
  Ok(config)
}
