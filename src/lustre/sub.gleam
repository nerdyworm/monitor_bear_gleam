import gleam/list
import lustre/effect

pub type Teardown =
  fn() -> Nil

pub type Dispatch(a) =
  fn(a) -> Nil

pub type Setup(msg) =
  fn(Dispatch(msg)) -> Teardown

pub type Sub(msg) {
  SubNone
  Sub(key: String, func: Setup(msg))
  Batch(List(Sub(msg)))
}

pub type Subscriptions(model, msg) {
  Subscriptions(subs: Sub(msg), subscriptions: fn(model) -> Sub(msg))
}

pub fn init(callback) {
  Subscriptions(subs: none(), subscriptions: callback)
}

type Model(model, msg) {
  Model(subs: Sub(msg), model: model)
}

pub fn with_subscriptions(application, subscriptions: fn(model) -> Sub(msg)) {
  update_application(
    application,
    fn(init) {
      fn(flags) {
        let #(model0, effects0) = init(flags)
        let subs = subscriptions(model0)
        #(
          Model(subs: subs, model: model0),
          effect.batch([effects0, run(none(), subs)]),
        )
      }
    },
    fn(update) {
      fn(wrapped: Model(model, msg), msg) {
        let #(model0, effects0) = update(wrapped.model, msg)
        let subs = subscriptions(model0)
        #(
          Model(subs: subs, model: model0),
          effect.batch([effects0, run(wrapped.subs, subs)]),
        )
      }
    },
    fn(view) { fn(wrapped: Model(model, msg)) { view(wrapped.model) } },
  )
}

pub fn none() {
  SubNone
}

pub fn batch(subs: List(Sub(msg))) -> Sub(msg) {
  let batches =
    list.map(subs, fn(sub) {
      case sub {
        SubNone -> Batch([])
        Sub(_, _) -> Batch([sub])
        Batch(_) -> sub
      }
    })

  let subs =
    list.fold(batches, [], fn(acc, sub) {
      let assert Batch(subs) = sub
      list.append(acc, subs)
    })

  Batch(subs)
}

pub fn map(sub: Sub(a), f: fn(a) -> b) -> Sub(b) {
  case sub {
    SubNone -> SubNone
    Batch(subs) -> Batch(list.map(subs, fn(sub) { map(sub, f) }))
    Sub(key, func) ->
      Sub(key, fn(dispatch) { func(fn(msg) { dispatch(f(msg)) }) })
  }
}

@external(javascript, "../lustre_sub.ffi.mjs", "add_teardown")
pub fn add_teardown(sub: a, teardown: b) -> Nil {
  let _ = sub
  let _ = teardown
  Nil
}

@external(javascript, "../lustre_sub.ffi.mjs", "call_teardown")
pub fn call_teardown(sub: a) -> Nil {
  let _ = sub
  Nil
}

@external(javascript, "../lustre_sub.ffi.mjs", "update_application")
pub fn update_application(
  application: a,
  init_mapper: b,
  update_mapper: c,
  view_mapper: d,
) -> a {
  let _ = application
  let _ = init_mapper
  let _ = update_mapper
  let _ = view_mapper
  application
}

pub fn run(prev: Sub(msg), next: Sub(msg)) {
  effect.from(fn(dispatch) { do_run(prev, next, dispatch) })
}

fn to_list(sub: Sub(msg)) {
  case sub {
    SubNone -> []
    Sub(_, _) -> [sub]
    Batch(sub) ->
      list.map(sub, to_list)
      |> list.flatten()
  }
}

fn do_run(prev: Sub(msg), next: Sub(msg), dispatch) {
  let prev = to_list(prev)
  let next = to_list(next)

  let removed =
    list.filter(prev, fn(p) {
      list.find(next, fn(n) {
        let assert Sub(p, _) = p
        let assert Sub(n, _) = n
        n == p
      })
      == Error(Nil)
    })

  let added =
    list.filter(next, fn(p) {
      list.find(prev, fn(n) {
        let assert Sub(p, _) = p
        let assert Sub(n, _) = n
        n == p
      })
      == Error(Nil)
    })

  list.each(removed, fn(sub) {
    let assert Sub(key, _) = sub
    call_teardown(key)
  })

  list.each(added, fn(sub) {
    let assert Sub(key, f) = sub
    let callback = f(dispatch)
    add_teardown(key, callback)
  })
}

pub fn new(key, setup) -> Sub(msg) {
  Sub(key, setup)
}
