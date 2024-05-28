import bear/log
import bear/monitors/assertion
import bear/monitors/monitor.{type Monitor, Monitor}
import bear/monitors/report
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/erlang/os
import gleam/erlang/process.{type ExitMessage, type Pid, ExitMessage}
import gleam/hackney
import gleam/http.{Post}
import gleam/http/request
import gleam/http/response.{type Response, Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/otp/task
import gleam/string

@target(erlang)
pub fn main(regions: List(String), max: Int, endpoint: String) {
  log.configure()

  let assert Ok(internal_api_key) = os.get_env("BEAR_INTERNAL_API_KEY")
  let assert Ok(_) = start_spec(regions, max, endpoint, internal_api_key)
  process.sleep_forever()
}

@target(erlang)
pub fn start_worker(regions: List(String), max: Int, endpoint: String) {
  let assert Ok(internal_api_key) = os.get_env("BEAR_INTERNAL_API_KEY")
  start_spec(regions, max, endpoint, internal_api_key)
}

pub type Msg {
  Tick
  Down(ExitMessage)
  Started(Pid, String, Monitor)
}

pub type State {
  State(
    subject: process.Subject(Msg),
    regions: List(String),
    busy: Dict(Pid, #(Monitor, String, Int)),
    max: Int,
    endpoint: String,
    token: String,
  )
}

@target(erlang)
pub fn start_spec(regions, max, endpoint, internal_api_key) {
  actor.start_spec(actor.Spec(
    init: fn() {
      log.info("[worker] " <> string.join(regions, ",") <> " " <> endpoint)

      let self = process.new_subject()
      process.send(self, Tick)
      process.trap_exits(True)

      actor.Ready(
        State(self, regions, dict.new(), max, endpoint, internal_api_key),
        process.new_selector()
          |> process.selecting_trapped_exits(Down)
          |> process.selecting(self, fn(m) { m }),
      )
    },
    init_timeout: 10,
    loop: loop,
  ))
}

@target(erlang)
fn loop(msg: Msg, state: State) {
  let out = dict.size(state.busy)
  // io.debug(#("running", out, msg))

  case msg {
    Started(pid, region, monitor) -> {
      let busy = dict.insert(state.busy, pid, #(monitor, region, now()))
      actor.continue(State(..state, busy: busy))
    }

    Down(ExitMessage(pid, _reason)) -> {
      let busy = dict.delete(state.busy, pid)
      actor.continue(State(..state, busy: busy))
    }

    Tick -> {
      timeout(state)

      case out >= state.max {
        True -> {
          process.send_after(state.subject, 1000, Tick)
          actor.continue(state)
        }

        False -> {
          // ok, we are withi in limits
          // poll for work (want to do this in a task off of this process)
          case state.regions {
            [] -> {
              actor.continue(state)
            }

            [next, ..rest] -> {
              let limit = state.max - out

              // poll for work and block actor here?
              let task = task.async(fn() { work(next, limit, state) })
              let result = task.try_await(task, 5000)

              case result {
                Ok(monitors) -> {
                  use monitor <- list.each(monitors)
                  let pid =
                    process.start(fn() { report(monitor, next, state) }, True)
                  process.send(state.subject, Started(pid, next, monitor))
                }

                Error(error) -> {
                  io.debug(error)
                  Nil
                }
              }

              process.send_after(state.subject, 1000, Tick)
              actor.continue(State(..state, regions: list.append(rest, [next])))
            }
          }
        }
      }
    }
  }
}

@target(erlang)
fn timeout(state: State) {
  let now = now()

  state.busy
  |> dict.to_list()
  |> list.each(fn(kv) {
    let #(pid, #(monitor, region, timestamp)) = kv

    case timestamp + monitor.config.request.timeout < now {
      True -> {
        process.start(fn() { report_timeout(region, monitor, state) }, False)
        process.kill(pid)
      }

      False -> {
        Nil
      }
    }
  })
}

@target(erlang)
fn work(region: String, limit: Int, state: State) {
  case pop(region, limit, state) {
    Ok(Response(status: 200, headers: _, body: body)) -> {
      case json.decode(body, dynamic.list(monitor.decoder)) {
        Ok(monitors) -> {
          monitors
        }

        Error(error) -> {
          log.error("Could not decode monitors: " <> string.inspect(error))
          []
        }
      }
    }

    other -> {
      log.error("Could not pop monitors: " <> string.inspect(other))
      []
    }
  }
}

@target(erlang)
fn pop(region: String, limit: Int, state: State) {
  let body =
    [
      #("kind", json.string("healthcheck")),
      #("limit", json.int(limit)),
      #("regions", json.array([region], json.string)),
    ]
    |> json.object()
    |> json.to_string()

  let assert Ok(request) =
    request.to(state.endpoint <> "/api/internal/healthchecks/pop")

  request
  |> request.set_header("content-type", "application/json")
  |> request.set_header("authorization", state.token)
  |> request.set_header("x-region", region)
  |> request.set_method(Post)
  |> request.set_body(body)
  |> hackney.send()
}

@target(erlang)
fn report(monitor: Monitor, region: String, state: State) {
  log.info(
    "[healthcheck] monitor_id="
    <> int.to_string(monitor.id)
    <> " monitor_name="
    <> monitor.name,
  )

  let started_at = now()

  let request = build_request(monitor)
  let response = hackney.send(request)

  let time = now() - started_at

  let #(status, results, message) = case response {
    Ok(response) -> {
      let status = response.status
      let response = assertion.HealthcheckResponse(response, time)
      #(
        status,
        assertion.assert_response(response, monitor.config.assertions),
        "",
      )
    }

    Error(error) -> {
      #(0, [], string.inspect(error))
    }
  }

  let body = case response {
    Ok(response) -> {
      response.body
    }

    Error(_) -> {
      ""
    }
  }

  let healthy =
    list.all(results, fn(result: assertion.AssertionResult) { result.result })
    && message == ""

  let report =
    report.new()
    |> report.assertions(results)
    |> report.body(body)
    |> report.healthy(healthy)
    |> report.message(message)
    |> report.region(region)
    |> report.runtime(now() - started_at)
    |> report.status(status)
    |> report.to_json()
    |> json.to_string()

  let assert Ok(request) = request.to(state.endpoint)

  let request =
    request
    |> request.set_method(http.Post)
    |> request.set_path(
      "/api/internal/healthchecks/report/" <> int.to_string(monitor.id),
    )
    |> request.set_header("content-type", "application/json")
    |> request.set_header("authorization", state.token)
    |> request.set_header("x-region", region)
    |> request.set_body(report)

  case hackney.send(request) {
    Ok(Response(204, _, _)) -> {
      Nil
    }

    response -> {
      let _ = io.debug(response)
      Nil
    }
  }
}

@target(erlang)
fn report_timeout(region: String, monitor: Monitor, state: State) {
  let report =
    report.new()
    |> report.region(region)
    |> report.healthy(False)
    |> report.status(0)
    |> report.runtime(monitor.config.request.timeout)
    |> report.message("timeout")
    |> report.to_json()
    |> json.to_string()

  let assert Ok(request) =
    request.to(
      state.endpoint
      <> "/api/internal/healthchecks/report/"
      <> int.to_string(monitor.id),
    )

  let request =
    request
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_header("authorization", state.token)
    |> request.set_header("x-region", region)
    |> request.set_body(report)

  case hackney.send(request) {
    Ok(Response(204, _, _)) -> {
      Nil
    }

    response -> {
      let _ = io.debug(response)
      Nil
    }
  }
}

@external(erlang, "bear_ffi", "now")
fn now() -> Int {
  panic as "erlang only"
}

fn build_request(monitor: Monitor) {
  let assert Ok(request) = request.to(monitor.config.url)

  let request = case monitor.config.request.method {
    "post" -> {
      request
      |> request.set_method(http.Post)
      |> request.set_body(monitor.config.request.body)
    }

    _ -> {
      request
      |> request.set_method(http.Get)
    }
  }

  use request, header <- list.fold(monitor.config.request.headers, request)
  request.set_header(request, header.name, header.value)
}
