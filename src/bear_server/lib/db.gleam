import bear/error
import bear_server/lib/db/migrations
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Pid}
import gleam/pgo
import gleam/string

@external(erlang, "bear_ffi", "default_pool")
fn pool() -> pgo.Connection {
  panic as "erlang only"
}

@external(erlang, "bear_ffi", "start_default_pool")
pub fn start_default_pool(config: pgo.Config) -> Result(Pid, Dynamic) {
  let _ = config
  panic as "erlang only"
}

@external(erlang, "pgo", "transaction")
pub fn transaction(callback: fn() -> a) -> a {
  callback()
}

pub fn migrate() {
  migrations.run(pool())
}

pub fn execute(query, params, expect) {
  pgo.execute(query, pool(), params, expect)
}

pub fn all(query, params, expect) {
  case pgo.execute(query, pool(), params, expect) {
    Ok(result) -> Ok(result.rows)
    Error(error) -> Error(error)
  }
}

pub fn one(query, params, expect) {
  case execute(query, params, expect) {
    Ok(pgo.Returned(count: 1, rows: [row])) -> Ok(row)

    Ok(_) -> {
      Error(error.DatabaseNone)
    }

    Error(error) -> {
      Error(error.DatabaseError(error))
    }
  }
}

pub fn get(query, params, expect) {
  case execute(query, params, expect) {
    Ok(pgo.Returned(count: 1, rows: [row])) -> Ok(row)
    Ok(pgo.Returned(count: 0, rows: [])) -> Error(Nil)

    error -> {
      panic as string.inspect(error)
    }
  }
}
