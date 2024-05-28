import bear/config
import bear/log
import bear/monitors_checked
import bear/queue
import bear_server/router
import bear_server/routes/api/socket
import bear_worker/main as worker
import gleam/erlang/os
import gleam/erlang/process
import gleam/http/request.{type Request as HttpRequest}
import mist
import wisp

@target(erlang)
pub fn main(
  port: Int,
  endpoint: String,
  worker: Bool,
  regions: List(String),
  max: Int,
) {
  log.configure()

  let assert Ok(priv) = wisp.priv_directory("bear")

  let assert Ok(internal_api_key) = os.get_env("BEAR_INTERNAL_API_KEY")
  let assert Ok(secret_key_base) = os.get_env("BEAR_SECRET_KEY_BASE")

  let assert Ok(stripe_key) = os.get_env("STRIPE_KEY")
  let assert Ok(stripe_webhook_signing_key) =
    os.get_env("STRIPE_WEBHOOK_SIGNING_KEY")

  let assert Ok(Nil) =
    config.set(config.Config(
      priv: priv,
      port: port,
      endpoint: endpoint,
      internal_api_key: internal_api_key,
      stripe_key: stripe_key,
      stripe_webhook_signing_key: stripe_webhook_signing_key,
    ))

  let handler = wisp.mist_handler(router.handle_request, secret_key_base)

  let assert Ok(_) =
    fn(req: HttpRequest(mist.Connection)) {
      case req.path {
        "/api/socket" -> socket.handle(req)
        _ -> handler(req)
      }
    }
    |> mist.new()
    |> mist.port(port)
    |> mist.after_start(fn(_port, _scheme) {
      let message = "[started] " <> endpoint
      log.info(message)
    })
    |> mist.start_http()

  maybe_start_worker(worker, regions, endpoint, max)

  let assert Ok(_) =
    queue.new()
    |> queue.register("monitor_flipped", monitors_checked.worker_after_flipped)
    |> queue.start_link()

  process.sleep_forever()
}

@target(erlang)
fn maybe_start_worker(
  worker: Bool,
  regions: List(String),
  endpoint: String,
  max: Int,
) {
  case worker {
    True -> {
      let assert Ok(_) = worker.start_worker(regions, max, endpoint)
      Nil
    }
    False -> {
      Nil
    }
  }
}
