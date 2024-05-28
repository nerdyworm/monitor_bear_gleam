import gleam/dict.{type Dict}
import gleam/pgo

pub type Status {
  Ack
  Sleep(in: Int)
}

pub type Callback =
  fn(String) -> Result(Status, String)

pub type Worker {
  Worker(name: String, callback: Callback)
}

pub type Queue {
  Queue(
    name: String,
    workers: Dict(String, Worker),
    conn: pgo.Connection,
    max: Int,
  )
}
