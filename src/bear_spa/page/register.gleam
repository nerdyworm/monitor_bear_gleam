import bear/session.{type Session, Session}
import bear_spa/api.{type ApiError, Validation}
import bear_spa/api/users
import bear_spa/app.{type App}
import bear_spa/route
import bear_spa/view/ui
import gleam/io
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import validates.{type Errors}

pub type Model {
  Model(email: String, password: String, errors: List(Errors))
}

pub type Msg {
  Created(Result(Session, ApiError))
  SetEmail(String)
  SetPassword(String)
  Submit
}

pub fn init(_app: App) -> #(Model, Effect(Msg)) {
  let model = Model(email: "", password: "", errors: [])
  #(model, effect.batch([]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SetPassword(password) -> {
      #(Model(..model, password: password), effect.none())
    }

    SetEmail(email) -> {
      #(Model(..model, email: email), effect.none())
    }

    Submit -> {
      #(
        Model(..model, errors: []),
        users.register_user(model.email, model.password, app, Created),
      )
    }

    Created(Error(Validation(errors))) -> {
      #(Model(..model, errors: errors), effect.none())
    }

    Created(Error(other)) -> {
      io.debug(other)
      #(model, effect.none())
    }

    Created(Ok(session)) -> {
      #(
        model,
        effect.batch([app.begin_session(app, session), route.push("/dashboard")]),
      )
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("p-4")], [
    html.div([attribute.class("max-w-96 mx-auto")], [
      html.div([attribute.class("mb-4")], [
        html.h1([attribute.class("font-bold text-2xl")], [
          html.text("Register for a new account"),
        ]),
      ]),
      html.form([event.on_submit(Submit)], [
        ui.text("email", "Email", model.email, model.errors, SetEmail),
        ui.password(
          "password",
          "Password",
          model.password,
          model.errors,
          SetPassword,
        ),
        html.div([attribute.class("text-right mt-8")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn-primary")],
            [html.text("Register")],
          ),
        ]),
      ]),
    ]),
  ])
}
