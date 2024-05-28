@external(erlang, "bear_ffi", "broadcast")
pub fn broadcast(topic: String, message: String) -> Nil {
  let _ = topic
  let _ = message
  Nil
}

@external(erlang, "bear_ffi", "subscribe")
pub fn subscribe(topic: String) -> Nil {
  let _ = topic
  Nil
}
