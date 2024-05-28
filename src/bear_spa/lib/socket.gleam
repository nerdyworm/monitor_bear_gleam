pub type Socket

@external(javascript, "../../bear_spa.ffi.mjs", "socket_new")
pub fn new(url: String) -> Socket {
  let _ = url
  panic as "javascript only"
}

@external(javascript, "../../bear_spa.ffi.mjs", "socket_onmessage")
pub fn onmessage(socket: Socket, callback: fn(String) -> Nil) -> Socket {
  let _ = callback
  socket
}

@external(javascript, "../../bear_spa.ffi.mjs", "socket_connect")
pub fn connect(socket: Socket, token: String) -> Socket {
  let _ = token
  socket
}

@external(javascript, "../../bear_spa.ffi.mjs", "socket_disconnect")
pub fn disconnect(socket: Socket) -> Socket {
  socket
}
