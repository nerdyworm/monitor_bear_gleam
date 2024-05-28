import gleam/dynamic
import gleam/result
import lustre/sub
import lustre/sub/utils

pub fn presses(key: String, msg: fn(String) -> msg) -> sub.Sub(msg) {
  sub.new(key, fn(dispatch) {
    let callback = fn(event) {
      let _ =
        event
        |> dynamic.field("key", dynamic.string)
        |> result.map(fn(key) { dispatch(msg(key)) })
      Nil
    }

    utils.document_add_event_listener("keypress", callback)
    fn() { utils.document_remove_event_listener("keypress", callback) }
  })
}

pub fn downs(key: String, msg: fn(String) -> msg) -> sub.Sub(msg) {
  sub.new(key, fn(dispatch) {
    let callback = fn(event) {
      let _ =
        event
        |> dynamic.field("key", dynamic.string)
        |> result.map(fn(key) { dispatch(msg(key)) })
      Nil
    }

    utils.document_add_event_listener("keydown", callback)
    fn() { utils.document_remove_event_listener("keydown", callback) }
  })
}
