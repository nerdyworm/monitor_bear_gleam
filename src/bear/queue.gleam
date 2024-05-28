import fox
import gleam/pgo

@external(erlang, "bear_ffi", "default_pool")
fn pool() -> pgo.Connection {
  panic as "erlang only"
}

pub fn push(name: String, args: String) {
  fox.push(new(), name, args)
}

pub fn new() {
  fox.new("default", pool())
  |> fox.max(10)
}

pub fn ack() {
  fox.ack()
}

pub fn register(queue, name, callback) {
  fox.register(queue, name, callback)
}

pub fn start_link(queue) {
  fox.start_link(queue)
}
