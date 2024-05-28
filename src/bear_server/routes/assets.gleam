import bear/config
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/result
import gleam/string
import simplifile
import wisp.{type Request, type Response}

@target(erlang)
pub fn assets(req: Request) -> Response {
  case wisp.path_segments(req) {
    ["assets", ..path] -> {
      let path = string.join(path, "/")

      let ext =
        req.path
        |> string.split(on: ".")
        |> list.last
        |> result.unwrap("")

      let gzip = case request.get_header(req, "Accept-Encoding") {
        Ok(accept) -> string.contains(accept, "gzip")
        Error(Nil) -> False
      }

      let path = case gzip {
        True -> static() <> "/assets/" <> path <> ".gz"
        False -> static() <> "/assets/" <> path
      }

      case ext {
        "css" -> {
          case simplifile.verify_is_file(path) {
            Ok(True) -> serve(path, gzip, "text/css")

            _ -> {
              wisp.not_found()
            }
          }
        }

        "js" -> {
          case simplifile.verify_is_file(path) {
            Ok(True) -> serve(path, gzip, "application/javascript")

            _ -> {
              wisp.not_found()
            }
          }
        }
        _ -> wisp.not_found()
      }
    }
    _ -> wisp.not_found()
  }
}

@target(erlang)
fn serve(path: String, gzip: Bool, content: String) {
  let response =
    response.new(200)
    |> response.set_header("content-type", content)
    |> response.set_header(
      "cache-control",
      "public, max-age=31536000, immutable",
    )
    |> response.set_body(wisp.File(path))

  case gzip {
    True -> response.set_header(response, "Content-Encoding", "gzip")
    False -> response
  }
}

@target(erlang)
fn static() -> String {
  config.priv() <> "/static"
}
