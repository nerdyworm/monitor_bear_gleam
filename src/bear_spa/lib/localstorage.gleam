@external(javascript, "../../bear_spa.ffi.mjs", "localstorage_get_item")
pub fn read(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

@external(javascript, "../../bear_spa.ffi.mjs", "localstorage_set_item")
pub fn write(_key: String, _value: String) -> Nil {
  Nil
}

@external(javascript, "../../bear_spa.ffi.mjs", "localstorage_remove_item")
pub fn remove(_key: String) -> Nil {
  Nil
}
