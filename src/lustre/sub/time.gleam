import lustre/sub

pub fn every(key: String, ms: Int, msg: msg) -> sub.Sub(msg) {
  sub.new(key, fn(dispatch) {
    let id = start_ticker(fn() { dispatch(msg) }, ms)
    fn() { stop_ticker(id) }
  })
}

pub fn every2(key: String, ms: Int, f: fn() -> msg) -> sub.Sub(msg) {
  sub.new(key, fn(dispatch) {
    let id =
      start_ticker(
        fn() {
          let msg = f()
          dispatch(msg)
        },
        ms,
      )
    fn() { stop_ticker(id) }
  })
}

type Ticker

@external(javascript, "../../lustre_sub.ffi.mjs", "ticker")
fn start_ticker(callback: fn() -> Nil, every: Int) -> Ticker {
  let _ = callback
  let _ = every
  panic as "javascript only"
}

@external(javascript, "../../lustre_sub.ffi.mjs", "stop_ticker")
fn stop_ticker(ticker: Ticker) -> Nil {
  let _ = ticker
  panic as "javascript only"
}
