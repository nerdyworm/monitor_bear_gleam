import bear/utils
import bear_spa/view/transition
import bear_spa/view/ui
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(message: Option(String), t: transition.Model, warn: Bool)
}

pub type Msg {
  Flash(String)
  Fade
  Clear
  TransitionMsg(transition.Msg)
}

pub fn flash(model: Model, message: String) {
  update(model, Flash(message))
}

pub fn init() -> Model {
  Model(
    message: None,
    t: transition.new(
      "transition-all ease-out duration-300 transform",
      "opacity-0",
      "opacity-100",
      300,
    ),
    warn: False,
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Clear -> {
      #(Model(..model, message: None), effect.batch([]))
    }

    Fade -> {
      let #(t, effects) = transition.reverse(model.t)
      #(
        Model(..model, t: t),
        effect.batch([
          effect.map(effects, TransitionMsg),
          effect.from(fn(dispatch) {
            utils.timeout(fn() { dispatch(Clear) }, 300)
          }),
        ]),
      )
    }

    Flash(message) -> {
      let #(t, effects0) = transition.start(model.t)
      #(
        Model(..model, message: Some(message), t: t),
        effect.batch([
          effect.map(effects0, TransitionMsg),
          effect.from(fn(dispatch) {
            utils.timeout(fn() { dispatch(Fade) }, 3000)
          }),
        ]),
      )
    }

    TransitionMsg(submsg) -> {
      let #(t, effects) = transition.update(model.t, submsg)
      #(Model(..model, t: t), effect.map(effects, TransitionMsg))
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model.message {
    None -> html.text("")
    Some(message) ->
      html.div(
        [
          attribute.class(
            "fixed top-p bg-teal text-base w-full text-center text-sm items-center flex space-x-2 justify-center "
            <> transition.class(model.t),
          ),
        ],
        [
          html.div([], [html.text(message)]),
          html.button([attribute.type_("button"), event.on_click(Fade)], [
            ui.icon("hero-x-mark w-4 h-4"),
          ]),
        ],
      )
  }
}
