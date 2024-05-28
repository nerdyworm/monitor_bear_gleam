import gleam/uri.{type Uri}
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/sub.{type Sub}

pub type URL =
  String

pub type Document(msg) {
  Document(title: String, body: Element(msg))
}

pub fn application(
  flags: flags,
  init: fn(flags, Uri) -> #(model, Effect(msg)),
  view: fn(model) -> Document(msg),
  update: fn(model, msg) -> #(model, Effect(msg)),
  subscriptions: fn(model) -> Sub(msg),
  on_url_request: fn(Uri) -> msg,
  on_url_change: fn(Uri) -> msg,
) {
  let assert Ok(dispatch) =
    lustre.application(
      fn(flags) { init(flags, current_uri()) },
      update,
      fn(model) {
        let document = view(model)
        set_title(document.title)
        document.body
      },
    )
    |> sub.with_subscriptions(subscriptions)
    |> lustre.start("body", flags)

  attach_listeners(
    fn(msg) { dispatch(lustre.dispatch(msg)) },
    on_url_request,
    on_url_change,
  )

  Ok(dispatch)
}

pub fn push(uri: Uri) -> Effect(msg) {
  effect.from(fn(_) { do_push(uri) })
}

@external(javascript, "../lustre_browser.ffi.mjs", "push")
fn do_push(url: Uri) -> Nil {
  let _ = url
  Nil
}

@external(javascript, "../lustre_browser.ffi.mjs", "current_uri")
pub fn current_uri() -> Uri {
  panic as "javascript only"
}

@external(javascript, "../lustre_browser.ffi.mjs", "attach_listeners")
pub fn attach_listeners(
  dispatch: fn(msg) -> Nil,
  request: fn(Uri) -> msg,
  change: fn(Uri) -> msg,
) -> Nil {
  let _ = dispatch
  let _ = request
  let _ = change
  Nil
}

@external(javascript, "../lustre_browser.ffi.mjs", "set_title")
pub fn set_title(title: String) -> Nil {
  let _ = title
  Nil
}
