import gleam/dict
import gleam/pgo
import internal/actor
import internal/queries
import types.{type Callback, type Queue, type Worker, Queue, Worker}

pub fn ack() {
  Ok(types.Ack)
}

pub fn nack(message: String) {
  Error(message)
}

pub fn snooze(seconds: Int) {
  Ok(types.Sleep(seconds))
}

pub fn new(name: String, conn: pgo.Connection) {
  Queue(name: name, workers: dict.new(), conn: conn, max: 10)
}

pub fn register(queue: Queue, name: String, callback: Callback) {
  Queue(
    ..queue,
    workers: dict.insert(
      queue.workers,
      name,
      Worker(name: name, callback: callback),
    ),
  )
}

pub fn max(queue: Queue, max: Int) -> Queue {
  Queue(..queue, max: max)
}

pub fn push(queue: Queue, name: String, args: String) {
  queries.push(queue, name, args)
}

@target(erlang)
pub fn start_link(queue: Queue) {
  actor.start_link(queue)
}

@target(javascript)
pub fn start_link(queue: Queue) {
  panic as "erlang only"
}
