import bear_spa/app.{type App}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model
}

pub type Msg {
  NOOP
}

pub fn init(_app: App) -> #(Model, Effect(Msg)) {
  let model = Model
  #(model, effect.batch([]))
}

pub fn update(_app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    NOOP -> {
      #(model, effect.none())
    }
  }
}

pub fn view(_app: App, _model: Model) -> Element(Msg) {
  html.div([attribute.class("border-b border-white/10 p-4")], [
    html.text("HEART BEATS"),
  ])
}
