import bear_spa/api.{type ApiError}
import bear_spa/api/users
import bear_spa/app.{type App}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(email: String, warning: Bool)
}

pub type Msg {
  SetEmail(String)
  Submit
  Response(Result(String, ApiError))
}

pub fn init(_app: App) -> #(Model, Effect(Msg)) {
  let model = Model(email: "", warning: False)
  #(model, effect.batch([]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SetEmail(email) -> {
      #(Model(..model, email: email), effect.none())
    }

    Submit -> {
      #(model, users.create_password_reset(model.email, app, Response))
    }

    Response(Ok(_)) -> {
      #(model, app.flash(app, "Check your inbox for the password reset link!"))
    }

    Response(Error(_)) -> {
      #(model, effect.none())
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("p-4")], [
    html.div([attribute.class("max-w-96 mx-auto")], [
      html.div([attribute.class("mb-4")], [
        html.h1([], [html.text("Forgot your password?")]),
        html.h2([], [html.text("No worries, it happens to everyone.")]),
      ]),
      html.form([event.on_submit(Submit)], [
        html.div([attribute.class("mb-4")], [
          html.input([
            attribute.type_("email"),
            attribute.value(model.email),
            attribute.class("form-input"),
            attribute.placeholder("bob@example.com"),
            event.on_input(SetEmail),
          ]),
        ]),
        html.button([attribute.class("btn-primary")], [
          html.text("Send Password Reset Email"),
        ]),
      ]),
    ]),
  ])
}
