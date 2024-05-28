import bear/utils
import bear_spa/view/transition
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/sub.{type Sub}
import lustre/sub/keys

pub type Model {
  Model(open: Bool, background: transition.Model, container: transition.Model)
}

pub type Msg(msg) {
  Open
  Close
  Closed
  Pressed(String)
  Custom(msg)
  BackgroundTransitionMsg(transition.Msg)
  ContainerTransitionMsg(transition.Msg)
}

pub fn msg(msg) {
  Custom(msg)
}

pub fn init() -> Model {
  Model(
    open: False,
    background: transition.new(
      "transition-all ease-out duration-300 transform",
      "opacity-0",
      "opacity-100",
      300,
    ),
    container: transition.new(
      "transition-all ease-out duration-300 transform",
      "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
      "opacity-100 translate-y-0 sm:scale-100",
      300,
    ),
  )
}

pub fn open(model: Model) {
  update(model, Open)
}

pub fn close(model: Model) {
  update(model, Close)
}

pub fn update(model: Model, msg: Msg(msg)) -> #(Model, Effect(Msg(msg))) {
  case msg {
    BackgroundTransitionMsg(submsg) -> {
      let #(background, effects) = transition.update(model.background, submsg)
      #(
        Model(..model, background: background),
        effect.map(effects, BackgroundTransitionMsg),
      )
    }

    ContainerTransitionMsg(submsg) -> {
      let #(container, effects) = transition.update(model.container, submsg)
      #(
        Model(..model, container: container),
        effect.map(effects, ContainerTransitionMsg),
      )
    }

    Open -> {
      let #(background, effects0) = transition.start(model.background)
      let #(container, effects1) = transition.start(model.container)

      #(
        Model(open: True, background: background, container: container),
        effect.batch([
          effect.map(effects0, BackgroundTransitionMsg),
          effect.map(effects1, ContainerTransitionMsg),
          effect.from(fn(_) { utils.focus("[autofocus]") }),
        ]),
      )
    }

    Close -> {
      let #(background, effects0) = transition.reverse(model.background)
      let #(container, effects1) = transition.reverse(model.container)
      #(
        Model(..model, background: background, container: container),
        effect.batch([
          effect.map(effects0, BackgroundTransitionMsg),
          effect.map(effects1, ContainerTransitionMsg),
          effect.from(fn(dispatch) {
            let _ = utils.set_timeout(fn() { dispatch(Closed) }, 300)
            Nil
          }),
        ]),
      )
    }

    Closed -> {
      #(Model(..model, open: False), effect.none())
    }

    Pressed("Escape") -> {
      #(model, effect.from(fn(dispatch) { dispatch(Close) }))
    }

    Pressed(_) -> {
      #(model, effect.none())
    }

    Custom(_) -> {
      #(model, effect.none())
    }
  }
}

pub fn view(model: Model, body: List(Element(Msg(msg)))) -> Element(Msg(msg)) {
  case model.open {
    False -> html.div([attribute.class("hidden")], [])
    True -> {
      html.div([attribute.class("modal")], [
        html.div([attribute.class(background_class(model))], []),
        html.div([attribute.class("fixed inset-0 overflow-y-auto")], [
          html.div(
            [attribute.class("flex min-h-full items-center justify-center")],
            [
              html.div([attribute.class("w-full max-w-3xl p-4")], [
                html.div([attribute.class(container_class(model))], [
                  html.div([attribute.class("absolute right-4 top-4")], [
                    html.button(
                      [
                        event.on_click(Close),
                        attribute.class("hover:text-subtext0"),
                        attribute.attribute("title", "Close"),
                      ],
                      [html.span([attribute.class("hero-x-mark w-5 h-5")], [])],
                    ),
                  ]),
                  html.div([attribute.class("p-4")], body),
                ]),
              ]),
            ],
          ),
        ]),
      ])
    }
  }
}

fn background_class(model: Model) {
  "bg-crust/90 fixed inset-0 transition-opacity"
  <> " "
  <> transition.class(model.background)
}

fn container_class(model: Model) {
  "relative rounded-2xl bg-base shadow-lg ring-crust ring-1 transition shadow relative"
  <> " "
  <> transition.class(model.container)
}

pub fn subscriptions(model: Model) -> Sub(Msg(yours)) {
  case model.open {
    False -> sub.none()
    True -> sub.batch([keys.downs("modal_esc", Pressed)])
  }
}
