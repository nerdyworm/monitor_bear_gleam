pub type PubSub(a)

@external(javascript, "../../bear_spa.ffi.mjs", "new_pubsub")
pub fn new() -> PubSub(a) {
  panic as "javascript only"
}

@external(javascript, "../../bear_spa.ffi.mjs", "publish_pubsub")
pub fn publish(pubsub: PubSub(a), message: a) -> Nil {
  let _ = pubsub
  let _ = message
  Nil
}

@external(javascript, "../../bear_spa.ffi.mjs", "subscribe_pubsub")
pub fn subscribe(pubsub: PubSub(a), callback: fn(a) -> Nil) -> Nil {
  let _ = pubsub
  let _ = callback
  Nil
}

@external(javascript, "../../bear_spa.ffi.mjs", "unsubscribe_pubsub")
pub fn unsubscribe(pubsub: PubSub(a), callback: fn(a) -> Nil) -> Nil {
  let _ = pubsub
  let _ = callback
  Nil
}
