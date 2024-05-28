import bear/config
import gleam/string_builder
import simplifile
import wisp.{type Request, type Response}

@target(erlang)
pub fn index(_req: Request) -> Response {
  let assert Ok(home) =
    simplifile.read(config.priv() <> "/static/pages/home.html")

  home
  |> string_builder.from_string()
  |> wisp.html_response(200)
}

@target(erlang)
pub fn spa(_req: Request) -> Response {
  let assert Ok(layout) = simplifile.read(config.priv() <> "/static/index.html")

  layout
  |> string_builder.from_string()
  |> wisp.html_response(200)
}
