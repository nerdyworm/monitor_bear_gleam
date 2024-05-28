import gleam/list
import gleam/string

pub fn split(tags: String) {
  string.split(tags, ",")
  |> list.map(string.trim)
}

pub fn join(tags: List(String)) {
  tags
  |> list.map(string.trim)
  |> string.join(", ")
}

pub fn join2(tags: List(String)) {
  tags
  |> string.join(", ")
}

pub fn trim(tags: List(String)) {
  list.map(tags, string.trim)
}
