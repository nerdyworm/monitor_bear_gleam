@target(erlang)
import logging

@target(erlang)
pub fn configure() {
  logging.configure()
}

@target(erlang)
pub fn info(msg: String) {
  logging.log(logging.Info, msg)
}

@target(erlang)
pub fn error(msg: String) {
  logging.log(logging.Error, msg)
}

@target(javascript)
pub fn configure() {
  Nil
}

@target(javascript)
import gleam/io

@target(javascript)
pub fn info(msg: String) {
  io.println("[info] " <> msg)
}

@target(javascript)
pub fn error(msg: String) {
  io.println("[error] " <> msg)
}
