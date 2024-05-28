import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/json
import gleam/option.{type Option}

pub type Job {
  Job(
    id: Int,
    state: String,
    queue: String,
    worker: String,
    args: String,
    errors: List(String),
    attempt: Int,
    max_attempts: Int,
    inserted_at: String,
    scheduled_at: String,
    completed_at: Option(String),
  )
}

pub fn decoder(row: Dynamic) -> Result(Job, List(DecodeError)) {
  let assert Ok(id) = dynamic.element(0, dynamic.int)(row)
  let assert Ok(state) = dynamic.element(1, dynamic.string)(row)
  let assert Ok(queue) = dynamic.element(2, dynamic.string)(row)
  let assert Ok(worker) = dynamic.element(3, dynamic.string)(row)
  let assert Ok(args) = dynamic.element(4, dynamic.string)(row)
  let assert Ok(errors) = dynamic.element(5, dynamic.string)(row)
  let assert Ok(errors) = json.decode(errors, dynamic.list(dynamic.string))
  let assert Ok(attempt) = dynamic.element(6, dynamic.int)(row)
  let assert Ok(max_attempts) = dynamic.element(7, dynamic.int)(row)
  let assert Ok(inserted_at) = dynamic.element(8, dynamic.string)(row)
  let assert Ok(scheduled_at) = dynamic.element(9, dynamic.string)(row)
  let assert Ok(completed_at) =
    dynamic.element(10, dynamic.optional(dynamic.string))(row)

  Ok(Job(
    id: id,
    state: state,
    queue: queue,
    worker: worker,
    args: args,
    errors: errors,
    attempt: attempt,
    max_attempts: max_attempts,
    inserted_at: inserted_at,
    scheduled_at: scheduled_at,
    completed_at: completed_at,
  ))
}
