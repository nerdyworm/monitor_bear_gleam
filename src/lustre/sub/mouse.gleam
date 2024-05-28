import gleam/dynamic
import lustre/sub
import lustre/sub/utils

pub fn clicks(key: String, msg: msg) -> sub.Sub(msg) {
  sub.new(key, fn(dispatch) {
    let callback = fn(_) { dispatch(msg) }
    utils.document_add_event_listener("click", callback)
    fn() { utils.document_remove_event_listener("click", callback) }
  })
}

pub fn clicks_outside(key: String, selector: String, msg: msg) -> sub.Sub(msg) {
  sub.new(key, fn(dispatch) {
    let callback = fn(event) {
      let assert Ok(target) = dynamic.field("target", dynamic.dynamic)(event)
      case utils.within(target, selector) {
        False -> dispatch(msg)
        True -> Nil
      }
    }
    utils.document_add_event_listener("click", callback)
    fn() { utils.document_remove_event_listener("click", callback) }
  })
}
