import gleam/dynamic
import gleam/json
import gleam/pgo
import gleam/string
import job.{type Job}
import types.{type Queue}

pub fn ack(queue: Queue, job: Job) {
  let query =
    "UPDATE fox_jobs SET state = 'completed', completed_at = now() at time zone 'utc' WHERE fox_jobs.id = $1"

  let result =
    pgo.execute(query, queue.conn, [pgo.int(job.id)], dynamic.dynamic)

  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

pub fn prune(queue: Queue) {
  let query =
    "DELETE FROM fox_jobs WHERE queue = $1 AND state = 'completed' AND scheduled_at < (now() AT TIME ZONE 'utc' - interval '5 minutes') "

  pgo.execute(query, queue.conn, [pgo.text(queue.name)], dynamic.dynamic)
}

pub fn pop(queue: Queue, limit: Int) {
  let query =
    "
WITH subset AS MATERIALIZED (
  SELECT fox_jobs.id
  FROM fox_jobs
  WHERE fox_jobs.state = 'available' AND fox_jobs.queue = $1
  ORDER BY fox_jobs.scheduled_at, fox_jobs.id
  LIMIT $2
  FOR UPDATE SKIP LOCKED
),

updated AS (
  UPDATE fox_jobs
  SET state = 'running', attempt = attempt + 1
  FROM subset
  WHERE fox_jobs.id = subset.id
  RETURNING fox_jobs.*
)

SELECT
  updated.id,
  updated.state,
  updated.queue,
  updated.worker,
  updated.args,
  updated.errors,
  updated.attempt,
  updated.max_attempts,
  updated.inserted_at::text,
  updated.scheduled_at::text,
  updated.completed_at::text
FROM updated;"

  let result =
    pgo.execute(
      query,
      queue.conn,
      [pgo.text(queue.name), pgo.int(limit)],
      job.decoder,
    )

  case result {
    Ok(pgo.Returned(count: _, rows: jobs)) -> Ok(jobs)
    Error(error) -> Error(error)
  }
}

pub fn push(queue: Queue, name: String, args: String) {
  let result =
    pgo.execute(
      "INSERT INTO fox_jobs (queue, worker, args) VALUES ($1, $2, $3) RETURNING id",
      queue.conn,
      [pgo.text(queue.name), pgo.text(name), pgo.text(args)],
      dynamic.element(0, dynamic.int),
    )

  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(string.inspect(error))
  }
}

pub fn nack(queue: Queue, job: Job, error: String) {
  let query =
    "UPDATE fox_jobs SET state = 'available', scheduled_at = now() at time zone 'utc', errors = $2 WHERE fox_jobs.id = $1"

  let result =
    pgo.execute(
      query,
      queue.conn,
      [
        pgo.int(job.id),
        pgo.text(
          [error, ..job.errors]
          |> json.array(json.string)
          |> json.to_string(),
        ),
      ],
      dynamic.dynamic,
    )

  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

pub fn dead(queue: Queue, job: Job, error: String) {
  let query =
    "UPDATE fox_jobs SET state = 'dead', errors = $2 WHERE fox_jobs.id = $1"

  let result =
    pgo.execute(
      query,
      queue.conn,
      [
        pgo.int(job.id),
        pgo.text(
          [error, ..job.errors]
          |> json.array(json.string)
          |> json.to_string(),
        ),
      ],
      dynamic.dynamic,
    )

  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}

pub fn snooze(queue: Queue, job: Job, seconds: Int) {
  let query =
    "UPDATE fox_jobs SET state = 'available', scheduled_at = (now() at time zone 'utc' + (interval '1 second' * $2)) WHERE fox_jobs.id = $1"

  let result =
    pgo.execute(
      query,
      queue.conn,
      [pgo.int(job.id), pgo.int(seconds)],
      dynamic.dynamic,
    )

  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}
