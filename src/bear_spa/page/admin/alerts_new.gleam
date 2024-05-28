import bear/alerts/alert
import bear_spa/app.{type App}
import bear_spa/page/admin/alerts_form as form
import bear_spa/route
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(form: form.Model, i_hate_this_warning: Bool)
}

pub type Msg {
  FormMsg(form.Msg)
}

pub fn init(app: App) -> #(Model, Effect(Msg)) {
  let #(form, effects) = form.init(app, alert.new(), "Create alert")
  let model = Model(form: form, i_hate_this_warning: True)
  #(model, effect.batch([effect.map(effects, FormMsg)]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    FormMsg(form.Response(Ok(_alert))) -> {
      #(model, route.push("/admin/alerts"))
    }

    FormMsg(submsg) -> {
      let #(form, effects) = form.update(app, model.form, submsg)
      #(Model(..model, form: form), effect.map(effects, FormMsg))
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("alerts-new")], [
    html.div([attribute.class("page-header")], [
      html.h1([], [html.text("Create a new alert")]),
      html.div([attribute.class("page-actions")], [
        html.a([attribute.href("/admin/alerts"), attribute.class("btn")], [
          html.text("Back"),
        ]),
      ]),
    ]),
    html.div([attribute.class("page-body")], [
      element.map(form.view(model.form), FormMsg),
    ]),
  ])
}
