pub type Element

pub type Rect {
  Rect(x: Int, y: Int, width: Int, height: Int, left: Int, top: Int)
}

@external(javascript, "../../bear_spa.ffi.mjs", "get_element_by_id")
pub fn get_element_by_id(_key: String) -> Result(Element, Nil) {
  Error(Nil)
}

@external(javascript, "../../bear_spa.ffi.mjs", "bounding_client_rect")
pub fn bounding_client_rect(_element: Element) -> Rect {
  Rect(0, 0, 0, 0, 0, 0)
}
