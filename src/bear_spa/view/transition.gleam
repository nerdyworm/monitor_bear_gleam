import bear/utils
import lustre/effect

pub type Model {
  Model(
    phase: String,
    enter: String,
    start: String,
    finish: String,
    duration: Int,
  )
}

pub type Msg {
  Start
  Started
  Finish
  Reversed
  ReversedStarted
  ReversedFinished
}

pub fn new(enter: String, start: String, finish: String, duration: Int) {
  Model("idle", enter, start, finish, duration)
}

pub fn init(model: Model) {
  #(
    Model(..model, phase: "start"),
    effect.from(fn(dispatch) {
      let _ = utils.set_timeout(fn() { dispatch(Start) }, 0)
      Nil
    }),
  )
}

pub fn class(model: Model) {
  case model.phase {
    "idle" -> ""
    "start" -> model.enter <> " " <> model.start
    "started" -> model.enter <> " " <> model.finish
    "reversed" -> model.enter <> " " <> model.finish
    "reversed-started" -> model.enter <> " " <> model.start
    "reversed-finished" -> model.enter <> " " <> model.start
    _ -> ""
  }
}

pub fn start(model: Model) {
  update(model, Start)
}

pub fn reverse(model: Model) {
  update(model, Reversed)
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    Start -> {
      #(
        Model(..model, phase: "start"),
        effect.from(fn(dispatch) {
          let _ = utils.set_timeout(fn() { dispatch(Started) }, 0)
          Nil
        }),
      )
    }

    Started -> {
      #(
        Model(..model, phase: "started"),
        effect.from(fn(dispatch) {
          let _ = utils.set_timeout(fn() { dispatch(Finish) }, model.duration)
          Nil
        }),
      )
    }

    Finish -> {
      #(Model(..model, phase: "finished"), effect.none())
    }

    Reversed -> {
      #(
        Model(..model, phase: "reversed"),
        effect.from(fn(dispatch) {
          let _ = utils.set_timeout(fn() { dispatch(ReversedStarted) }, 0)
          Nil
        }),
      )
    }

    ReversedStarted -> {
      #(
        Model(..model, phase: "reversed-started"),
        effect.from(fn(dispatch) {
          let _ =
            utils.set_timeout(
              fn() { dispatch(ReversedFinished) },
              model.duration,
            )
          Nil
        }),
      )
    }

    ReversedFinished -> {
      #(Model(..model, phase: "reversed-finished"), effect.none())
    }
  }
}
