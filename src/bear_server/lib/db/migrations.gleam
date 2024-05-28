import gleam/dynamic
import gleam/erlang
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/pgo
import gleam/regex
import gleam/string
import simplifile

pub type Migration {
  Migration(version: Int, statements: List(String))
}

@external(erlang, "pgo", "transaction")
pub fn transaction(callback: fn() -> a) -> a {
  callback()
}

@target(javascript)
pub fn run(_) {
  Ok(Nil)
}

@target(erlang)
pub fn run(db) {
  let assert Ok(_) =
    "
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version bigint NOT NULL,
      inserted_at timestamp without time zone,
      CONSTRAINT schema_migrations_pkey PRIMARY KEY (version)
    )
    "
    |> pgo.execute(db, [], dynamic.dynamic)

  let assert Ok(versions) =
    "SELECT version FROM schema_migrations"
    |> pgo.execute(db, [], dynamic.element(0, dynamic.int))

  let assert Ok(priv) = erlang.priv_directory("bear")
  let dir = priv <> "/migrations/"
  let assert Ok(files) = simplifile.read_directory(dir)
  let migrations = files_to_migrations(dir, files)

  // filter any migratrions alreay ran
  list.filter(migrations, fn(migration) {
    case list.contains(versions.rows, migration.version) {
      True -> False
      False -> True
    }
  })
  |> run_migrations(db)
}

fn run_migrations(migrations: List(Migration), db) {
  use migration <- list.each(migrations)
  // can't create materizlied views in tx :(
  // use <- transaction()

  migration.statements
  |> list.map(string.trim)
  |> list.filter(fn(sql) { sql != "" })
  |> list.each(fn(sql) {
    io.println(sql)
    let assert Ok(_) = pgo.execute(sql, db, [], dynamic.dynamic)
  })

  let assert Ok(_) = insert_version(migration.version, db)
}

fn files_to_migrations(dir, files) {
  list.map(files, fn(file) {
    let assert Ok(data) = simplifile.read(dir <> file)
    let assert Ok(re) = regex.from_string("(\\d+)_")
    let assert Ok(version) = case regex.scan(with: re, content: file) {
      [regex.Match(_, [Some(version)])] -> int.parse(version)
      _ -> Error(Nil)
    }

    let statements = string.split(data, ";;")
    Migration(version, statements)
  })
  |> list.sort(fn(a, b) { int.compare(a.version, b.version) })
}

fn insert_version(version, db) {
  "INSERT INTO schema_migrations (version, inserted_at) VALUES ($1, now())"
  |> pgo.execute(db, [pgo.int(version)], dynamic.dynamic)
}
