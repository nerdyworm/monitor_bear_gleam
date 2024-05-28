import argv
import bear_server/lib/db
import bear_server/main as server_main
import bear_worker/main as worker_main
import glint
import glint/flag

@target(erlang)
fn server(input: glint.CommandInput) -> Nil {
  let assert Ok(port) = flag.get_int(from: input.flags, for: "port")
  let assert Ok(endpoint) = flag.get_string(from: input.flags, for: "endpoint")
  let assert Ok(worker) = flag.get_bool(from: input.flags, for: "worker")
  let assert Ok(regions) = flag.get_strings(from: input.flags, for: "regions")
  let assert Ok(max) = flag.get_int(from: input.flags, for: "max")
  server_main.main(port, endpoint, worker, regions, max)
}

@target(erlang)
fn worker(input: glint.CommandInput) -> Nil {
  let assert Ok(regions) = flag.get_strings(from: input.flags, for: "regions")
  let assert Ok(max) = flag.get_int(from: input.flags, for: "max")
  let assert Ok(endpoint) = flag.get_string(from: input.flags, for: "endpoint")
  worker_main.main(regions, max, endpoint)
}

@target(erlang)
fn migrate(_input: glint.CommandInput) -> Nil {
  db.migrate()
}

@target(erlang)
pub fn main() {
  glint.new()
  |> glint.with_pretty_help(glint.default_pretty_help())
  |> glint.add(
    at: ["server"],
    do: glint.command(server)
      |> glint.description("Starts the web server")
      |> commond_flags()
      |> glint.flag(
      "port",
      flag.int()
        |> flag.default(8080)
        |> flag.description("PORT"),
    )
      |> glint.flag(
      "worker",
      flag.bool()
        |> flag.default(False)
        |> flag.description("Runs a worker on the server"),
    ),
  )
  |> glint.add(
    at: ["migrate"],
    do: glint.command(migrate)
      |> glint.description("Runs database migrations"),
  )
  |> glint.add(
    at: ["worker"],
    do: glint.command(worker)
      |> commond_flags()
      |> glint.description("Starts a worker process"),
  )
  |> glint.run(argv.load().arguments)
}

fn commond_flags(cmd) {
  cmd
  |> glint.flag(
    "regions",
    flag.string_list()
      |> flag.default(["us-east", "us-west"])
      |> flag.description("Worker regions"),
  )
  |> glint.flag(
    "max",
    flag.int()
      |> flag.default(100)
      |> flag.description("Max number of checks that the worker should pull"),
  )
  |> glint.flag(
    "endpoint",
    flag.string()
      |> flag.default("http://localhost:8080")
      |> flag.description("API ENDPOINT"),
  )
}
