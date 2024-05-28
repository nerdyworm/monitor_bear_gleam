import bear/session.{type Session, Session}
import bear_spa/api.{type ApiError, Validation}
import bear_spa/api/users
import bear_spa/app.{type App}
import bear_spa/route
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
  Login
  ChangeEmail(String)
  ChangePassword(String)
  Created(Result(Session, ApiError))
}

pub fn init(_app: App) -> #(Model, Effect(Msg)) {
  let model = Model(email: "", password: "", errors: [])
  #(model, effect.batch([]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ChangePassword(password) -> {
      #(Model(..model, password: password), effect.none())
    }

    ChangeEmail(email) -> {
      #(Model(..model, email: email), effect.none())
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
        Model(..model, email: "", password: ""),
        effect.batch([app.begin_session(app, session), route.push("/dashboard")]),
      )
    }

    Login -> {
      #(model, users.create_session(model.email, model.password, app, Created))
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("p-4")], [
    html.div([attribute.class("max-w-96 mx-auto")], [
      html.div([attribute.class("mb-4")], [
        html.h1([attribute.class("font-bold text-2xl")], [
          html.text("Welcome Back"),
        ]),
      ]),
      html.form([event.on_submit(Login)], [
        html.input([
          attribute.class("form-input mb-4"),
          attribute.name("email"),
          attribute.type_("email"),
          attribute.value(model.email),
          attribute.placeholder("Email"),
          attribute.attribute("autocomplete", "email"),
          event.on_input(ChangeEmail),
        ]),
        html.input([
          attribute.class("form-input mb-4"),
          attribute.name("password"),
          attribute.type_("password"),
          attribute.value(model.password),
          attribute.placeholder("Password"),
          attribute.attribute("autocomplete", "current-password"),
          event.on_input(ChangePassword),
        ]),
        html.div([attribute.class("flex items-center")], [
          html.div([], [
            html.a(
              [
                attribute.href("/users/reset_password"),
                attribute.class("text-sm"),
              ],
              [html.text("Forgot Password?")],
            ),
          ]),
          html.div([attribute.class("ml-auto")], [
            html.button(
              [attribute.type_("submit"), attribute.class("btn-primary")],
              [html.text("Sign in")],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}
