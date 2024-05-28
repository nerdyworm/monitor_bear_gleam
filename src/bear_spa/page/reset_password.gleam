import bear/session.{type Session}
import bear_spa/api.{type ApiError}
import bear_spa/api/users
import bear_spa/app.{type App}
import bear_spa/route
import gleam/io
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(token: String, password: String)
}

pub type Msg {
  Submit
  SetPassword(String)
  Response(Result(Session, ApiError))
}

pub fn init(_app: App, token: String) -> #(Model, Effect(Msg)) {
  let model = Model(token: token, password: "")
  #(model, effect.batch([]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Submit -> {
      #(model, users.reset_password(model.token, model.password, app, Response))
    }

    SetPassword(password) -> {
      #(Model(..model, password: password), effect.none())
    }

    Response(Ok(session)) -> {
      #(
        Model(..model, password: ""),
        effect.batch([app.begin_session(app, session), route.push("/dashboard")]),
      )
    }

    Response(result) -> {
      let _ = io.debug(result)
      #(model, effect.none())
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("p-4")], [
    html.div([attribute.class("max-w-96 mx-auto")], [
      html.div([attribute.class("page-header")], [
        html.div([], [html.h1([], [html.text("Reset your password")])]),
      ]),
      html.div([], [
        html.form([event.on_submit(Submit)], [
          html.div([attribute.class("mb-4")], [
            html.input([
              attribute.type_("password"),
              attribute.value(model.password),
              attribute.class("form-input"),
              event.on_input(SetPassword),
            ]),
          ]),
          html.button([attribute.class("btn-primary")], [
            html.text("Reset Password"),
          ]),
        ]),
      ]),
    ]),
  ])
}
