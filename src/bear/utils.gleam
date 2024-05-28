import gleam/int

@external(erlang, "bear_ffi", "now")
@external(javascript, "../bear_spa.ffi.mjs", "now")
pub fn now() -> Int

@external(erlang, "bear_ffi", "random")
@external(javascript, "../bear_spa.ffi.mjs", "random")
pub fn random(n: Int) -> Int

@external(javascript, "../bear_spa.ffi.mjs", "set_timeout")
pub fn set_timeout(callback: fn() -> Nil, ms: Int) -> Int {
  let _ = callback
  let _ = ms
  0
}

@external(javascript, "../bear_spa.ffi.mjs", "set_timeout")
pub fn timeout(callback: fn() -> Nil, ms: Int) -> Nil {
  let _ = callback
  let _ = ms
  Nil
}

pub fn make_id() -> String {
  random(100_000)
  |> int.to_string()
}

@external(javascript, "../bear_spa.ffi.mjs", "focus")
pub fn focus(selector: String) -> Nil {
  let _ = selector
  Nil
}
