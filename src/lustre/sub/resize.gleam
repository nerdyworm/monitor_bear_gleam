import gleam/dynamic
import lustre/sub
import lustre/sub/utils

pub type Size {
  Size(height: Int, width: Int)
}

pub fn resized(key: String, msg: fn(Size) -> msg) -> sub.Sub(msg) {
  sub.new(key, fn(dispatch) {
    let callback = fn(_event) { dispatch(msg(size())) }

    utils.window_add_event_listener("resize", callback)
    fn() { utils.window_remove_event_listener("resize", callback) }
  })
}

fn size() -> Size {
  let assert Ok(size) =
    dynamic.decode2(
      Size,
      dynamic.field("height", dynamic.int),
      dynamic.field("width", dynamic.int),
    )(window_size())

  size
}

@external(javascript, "../../lustre_sub.ffi.mjs", "window_size")
fn window_size() -> dynamic.Dynamic {
  panic as "javascript only"
}
