import bear/utils
import bear_spa/view/transition
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{div}
import lustre/event
import lustre/sub.{type Sub}
import lustre/sub/keys
import lustre/sub/mouse

pub type Animation {
  Idle
  EnterStart
  Enter
  EnterEnd
  LeaveStart
  Leave
  LeaveEnd
}

pub type Msg(yours) {
  TransitionMsg(transition.Msg)
  Open
  Close
  Closed
  Pressed(String)
  Custom(yours)
}

pub type Model {
  Model(
    open: Bool,
    animation: String,
    warnings: Bool,
    transition: transition.Model,
  )
}

pub type Item(msg) {
  Item(name: String, clicked: fn() -> msg)
}

pub fn init() {
  Model(
    open: False,
    animation: "closed",
    warnings: False,
    transition: transition.new(
      "transition-all ease-out duration-150 transform",
      "opacity-0 scale-90",
      "opacity-100 scale-100",
      100,
    ),
  )
}

pub fn update(model: Model, msg: Msg(yours)) -> #(Model, Effect(Msg(yours))) {
  case msg {
    TransitionMsg(msg) -> {
      let #(transition, effects) = transition.update(model.transition, msg)
      #(
        Model(..model, transition: transition),
        effect.map(effects, TransitionMsg),
      )
    }

    Custom(_) -> {
      #(model, effect.none())
    }

    Open -> {
      let #(transition, effects) = transition.start(model.transition)
      #(
        Model(..model, transition: transition, open: True),
        effect.map(effects, TransitionMsg),
      )
    }

    Closed -> {
      #(Model(..model, open: False, animation: "leave-end"), effect.none())
    }

    Close -> {
      let #(transition, effects) = transition.reverse(model.transition)
      #(
        Model(..model, transition: transition, open: True),
        effect.batch([
          effect.map(effects, TransitionMsg),
          effect.from(fn(dispatch) {
            utils.timeout(fn() { dispatch(Closed) }, 300)
          }),
        ]),
      )
    }

    Pressed("Escape") -> {
      #(model, effect.from(fn(dispatch) { dispatch(Close) }))
    }

    Pressed(_) -> {
      #(model, effect.none())
    }
  }
}

pub fn subscriptions(model: Model) -> Sub(Msg(yours)) {
  case model.open {
    False -> sub.none()
    True -> {
      sub.batch([
        mouse.clicks_outside("dropdown_clicks", ".dropdown-menu", Close),
        keys.downs("dropdown_esc", Pressed),
      ])
    }
  }
}

pub fn on_click(msg) {
  event.on_click(Custom(msg))
}

pub fn view(
  model model: Model,
  trigger trigger,
  items items,
) -> Element(Msg(yours)) {
  html.header([class("dropdown relative inline-block text-left")], [
    div([class("dropdown-trigger inline-block"), event.on_click(Open)], [
      trigger,
    ]),
    div(
      [
        class(menu_class(model)),
        attribute.style([
          #("display", case model.open {
            True -> "block"
            False -> "none"
          }),
        ]),
      ],
      [div([class("py-1")], items)],
    ),
  ])
}

fn menu_class(model: Model) {
  "dropdown-menu absolute right-0 z-10 mt-2 w-56 origin-top-right rounded-md bg-crust shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none"
  <> " "
  <> transition.class(model.transition)
}
