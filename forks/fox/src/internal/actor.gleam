import exception
import gleam/dict.{type Dict}
import gleam/erlang/process.{type ExitMessage, type Pid, ExitMessage}
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string
import internal/queries
import job.{type Job}
import types.{type Queue, type Worker, Worker}

pub type Msg {
  Tick
  Prune
  Down(ExitMessage)
  Started(Pid, Job)
}

pub type State {
  State(
    queue: Queue,
    subject: process.Subject(Msg),
    busy: Dict(Pid, #(Job, Int)),
  )
}

@target(erlang)
pub fn start_link(queue: Queue) {
  actor.start_spec(actor.Spec(
    init: fn() {
      let self = process.new_subject()
      process.send(self, Tick)
      process.send(self, Prune)
      process.trap_exits(True)

      actor.Ready(
        State(queue, self, dict.new()),
        process.new_selector()
          |> process.selecting_trapped_exits(Down)
          |> process.selecting(self, fn(m) { m }),
      )
    },
    init_timeout: 10,
    loop: queue_loop,
  ))
}

@target(erlang)
fn queue_loop(msg: Msg, state: State) {
  case msg {
    Down(ExitMessage(pid, reason)) -> down(pid, reason, state)
    Started(pid, job) -> started(pid, job, state)
    Tick -> tick(state)
    Prune -> prune(state)
  }
}

@target(erlang)
fn tick(state: State) {
  let out = dict.size(state.busy)
  let demand = state.queue.max - out

  case queries.pop(state.queue, demand) {
    Ok(jobs) -> {
      start_jobs(jobs, state)
      process.send_after(state.subject, 1000, Tick)
      actor.continue(state)
    }

    Error(error) -> {
      io.debug(error)
      process.send_after(state.subject, 1000, Tick)
      actor.continue(state)
    }
  }
}

@target(erlang)
fn prune(state: State) {
  case queries.prune(state.queue) {
    Ok(_) -> Nil
    Error(error) -> {
      io.debug(error)
      Nil
    }
  }

  process.send_after(state.subject, 69_000, Prune)
  actor.continue(state)
}

fn down(pid, _reason, state: State) {
  let busy = dict.delete(state.busy, pid)
  actor.continue(State(..state, busy: busy))
}

fn started(pid, job, state: State) {
  let busy = dict.insert(state.busy, pid, #(job, now()))
  actor.continue(State(..state, busy: busy))
}

@target(erlang)
fn start_jobs(jobs: List(Job), state: State) {
  let queue = state.queue
  use job <- list.each(jobs)
  let worker = dict.get(state.queue.workers, job.worker)
  let pid = process.start(fn() { run(job, worker, queue) }, True)
  process.send(state.subject, Started(pid, job))
}

fn run(job: Job, worker: Result(Worker, Nil), queue: Queue) {
  case worker {
    Error(Nil) -> {
      error_job(queue, job, err_worker_not_found(job.worker))
    }

    Ok(Worker(callback: callback, ..)) -> {
      case exception.rescue(fn() { callback(job.args) }) {
        Ok(Ok(types.Ack)) -> queries.ack(queue, job)
        Ok(Ok(types.Sleep(seconds))) -> queries.snooze(queue, job, seconds)
        Ok(Error(error)) -> error_job(queue, job, error)
        Error(error) -> error_job(queue, job, string.inspect(error))
      }
    }
  }
}

fn error_job(queue: Queue, job: Job, error: String) {
  case job.attempt + 1 > job.max_attempts {
    True -> queries.dead(queue, job, error)
    False -> queries.nack(queue, job, error)
  }
}

fn err_worker_not_found(name: String) {
  let n = string.inspect(name)
  "Could not find a worker for: " <> n <> ".

Hint: queue.register(queue, " <> n <> ", callback) before processing jobs."
}

@external(erlang, "fox_ffi", "now")
fn now() -> Int {
  panic as "erlang only"
}
