import gleam/dynamic

@external(javascript, "../../lustre_sub.ffi.mjs", "document_add_event_listener")
pub fn document_add_event_listener(
  name: String,
  callback: fn(dynamic.Dynamic) -> Nil,
) -> Nil {
  let _ = name
  let _ = callback
  panic as "javascript only"
}

@external(javascript, "../../lustre_sub.ffi.mjs", "document_remove_event_listener")
pub fn document_remove_event_listener(
  name: String,
  callback: fn(dynamic.Dynamic) -> Nil,
) -> Nil {
  let _ = name
  let _ = callback
  panic as "javascript only"
}

@external(javascript, "../../lustre_sub.ffi.mjs", "window_add_event_listener")
pub fn window_add_event_listener(
  name: String,
  callback: fn(dynamic.Dynamic) -> Nil,
) -> Nil {
  let _ = name
  let _ = callback
  panic as "javascript only"
}

@external(javascript, "../../lustre_sub.ffi.mjs", "window_remove_event_listener")
pub fn window_remove_event_listener(
  name: String,
  callback: fn(dynamic.Dynamic) -> Nil,
) -> Nil {
  let _ = name
  let _ = callback
  panic as "javascript only"
}

@external(javascript, "../../lustre_sub.ffi.mjs", "within")
pub fn within(element: dynamic.Dynamic, selector: String) -> Bool {
  let _ = element
  let _ = selector
  False
}
