import bear_spa/app.{type App}
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, div, h1, text}

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
    _ -> {
      #(model, effect.none())
    }
  }
}

pub fn view(_app: App, _model: Model) -> Element(Msg) {
  div([class("alerts-index")], [
    div([class("page-header")], [
      h1([], [text("Admin")]),
      div([class("page-actions")], [
        a([href("/checks"), class("btn")], [text("Back")]),
      ]),
    ]),
    div([class("page-body")], [
      div([class("space-y-4")], [
        div([class("bg-mantle rounded p-4")], [
          a([href("/admin/alerts")], [
            h1([class("font-bold text-xl")], [text("Alerts")]),
            div([], [text("Mange your alerting rules")]),
          ]),
        ]),
        div([class("bg-mantle rounded p-4")], [
          a([href("/admin/memberships")], [
            h1([class("font-bold text-xl")], [text("Team Memberships")]),
            div([], [text("Manage who has access to your monitor bear team")]),
          ]),
        ]),
        div([class("bg-mantle rounded p-4")], [
          a([href("/admin/plans")], [
            h1([class("font-bold text-xl")], [text("Plans & Billing")]),
            div([], [text("Manage your plan and billing")]),
          ]),
        ]),
      ]),
    ]),
  ])
}
