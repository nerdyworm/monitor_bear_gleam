import bear/teams/team.{type Team}
import bear_spa/api.{type ApiError, type RemoteData, Done, Loading}
import bear_spa/api/admin
import bear_spa/app.{type App}
import bear_spa/route
import bear_spa/view/ui
import gleam/int
import gleam/io
import lustre/attribute.{class, href}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, button, div, h1, span, text}
import lustre/event

pub type Model {
  Model(team: RemoteData(Team, ApiError), i: Int)
}

pub type Msg {
  GotTeam(Result(Team, ApiError))
  Checkout(String)
  CheckoutURL(Result(String, ApiError))
}

pub fn init(app: App) -> #(Model, Effect(Msg)) {
  let model = Model(team: Loading, i: 0)
  #(model, effect.batch([admin.get_team(app, GotTeam)]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Checkout(plan) -> {
      io.debug(plan)
      #(model, admin.create_checkout_session(plan, app, CheckoutURL))
    }

    CheckoutURL(Ok(url)) -> {
      route.redirect(url)
      #(model, effect.none())
    }

    CheckoutURL(Error(result)) -> {
      io.debug(result)
      #(model, effect.none())
    }

    GotTeam(team) -> {
      #(Model(..model, team: Done(team)), effect.none())
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  div([class("alerts-index")], [
    div([class("page-header")], [
      h1([], [text("Plans")]),
      div([class("page-actions")], [
        a([href("/checks"), class("btn")], [text("Back")]),
      ]),
    ]),
    div([class("page-body")], [
      case model.team {
        Done(Ok(team)) -> {
          ui.card([class("mb-4")], [
            div([class("mb-4")], [
              div([class("font-bold")], [text("Current Plan:")]),
              div([class("")], [text(team.plan)]),
            ]),
            div([class("mb-4")], [
              div([class("font-bold")], [text("Current Limits:")]),
              ui.list([
                #("monitors", int.to_string(team.limits.monitors)),
                #("interval", team.limits.interval),
                #("history", int.to_string(team.limits.messages)),
              ]),
            ]),
          ])
        }
        _ -> {
          ui.card([class("mb-4")], [
            div([class("mb-4")], [
              div([class("font-bold")], [text("Current Plan:")]),
              div([class("")], [text("Loading...")]),
            ]),
            div([class("mb-4")], [
              div([class("font-bold")], [text("Current Limits:")]),
              ui.list([
                #("monitors", int.to_string(0)),
                #("interval", ""),
                #("history", int.to_string(0)),
              ]),
            ]),
          ])
        }
      },
      div([class("grid grid-cols-3")], [
        indie_plan(),
        startup_plan(),
        business_plan(),
      ]),
    ]),
  ])
}

fn indie_plan() {
  div([], [
    div([class("mb-2")], [h1([], [text("Indie Plan")])]),
    div([class("mb-2")], [
      span([class("text-xl semi-bold")], [text("$9")]),
      span([class("text-subtext0")], [text("/m")]),
    ]),
    div([class("mb-4")], [
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("60 second checks"),
      ]),
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("10 monitors"),
      ]),
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("Email Alerts"),
      ]),
      div([], [
        ui.icon("hero-x-mark w-4 h-4 text-red mr-2"),
        text("Integrations"),
      ]),
    ]),
    div([], [
      button([event.on_click(Checkout("startup")), class("btn-primary")], [
        text("Startup Plan"),
      ]),
    ]),
  ])
}

fn startup_plan() {
  div([], [
    div([class("mb-2")], [h1([], [text("Startup Plan")])]),
    div([class("mb-2")], [
      span([class("text-xl semi-bold")], [text("$29")]),
      span([class("text-subtext0")], [text("/m")]),
    ]),
    div([class("mb-4")], [
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("30 second checks"),
      ]),
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("25 monitors"),
      ]),
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("Email Alerts"),
      ]),
      div([], [
        ui.icon("hero-x-mark w-4 h-4 text-red mr-2"),
        text("Integrations"),
      ]),
    ]),
    div([], [
      button([event.on_click(Checkout("startup")), class("btn-primary")], [
        text("Startup Plan"),
      ]),
    ]),
  ])
}

fn business_plan() {
  div([], [
    div([class("mb-2")], [h1([], [text("Business Plan")])]),
    div([class("mb-2")], [
      span([class("text-xl semi-bold")], [text("$49")]),
      span([class("text-subtext0")], [text("/m")]),
    ]),
    div([class("mb-4")], [
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("10 second checks"),
      ]),
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("50 monitors"),
      ]),
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("Email Alerts"),
      ]),
      div([], [
        ui.icon("hero-check w-4 h-4 text-green mr-2"),
        text("Integrations"),
      ]),
    ]),
    div([], [
      button([event.on_click(Checkout("business")), class("btn-primary")], [
        text("Business Plan"),
      ]),
    ]),
  ])
}
