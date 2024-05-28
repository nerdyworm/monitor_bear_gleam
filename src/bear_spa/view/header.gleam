import bear/monitors/state
import bear_spa/app.{type App}
import bear_spa/route.{type Route}
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element/html
import lustre/event

pub fn public(app: App) {
  html.div([attribute.class("px-4 py-2 flex items-center space-x-4")], [
    html.h1([attribute.class("font-bold mr-2")], [
      html.a([attribute.href("/")], [html.text("Monitor Bear")]),
    ]),
    navlink("/login", app, [html.text("Login")]),
    navlink("/register", app, [html.text("Register")]),
  ])
}

pub fn private(app: App, logout) {
  html.div([attribute.class("p-4 flex align-middle")], [
    html.div([attribute.class("flex flex-1 items-center")], [
      html.div([], [navlink("/dashboard", app, [html.text("🐻")])]),
    ]),
    html.div([attribute.class("flex flex-1 items-center justify-center")], [
      html.div([attribute.class("flex space-x-4")], [
        html.div([], [
          navlink("/checks", app, [dot(status(app)), html.text("Checks")]),
        ]),
        html.div([], [navlink("/incidents", app, [html.text("Incidents")])]),
      ]),
    ]),
    html.div([attribute.class("flex flex-1 items-center justify-end")], [
      html.div([attribute.class("flex space-x-4")], [
        html.div([], [
          html.text(case app.session {
            None -> ""
            Some(session) -> session.email
          }),
        ]),
        html.div([], [navlink("/admin", app, [html.text("Admin")])]),
        html.div([], [
          html.button([event.on_click(logout)], [html.text("Logout")]),
        ]),
      ]),
    ]),
  ])
}

fn navlink(href: String, app: App, children) {
  html.a(
    [attribute.href(href), attribute.class(navclass(app.route, href))],
    children,
  )
}

fn navclass(route: Route, href: String) -> String {
  case route, href {
    route.Private(route.Checks(route.ChecksIndex)), "/checks" -> "font-bold"
    route.Private(route.Checks(route.ChecksShow(_))), "/checks" -> "font-bold"
    route.Public(route.Login), "/login" -> "font-bold"
    route.Public(route.Register), "/register" -> "font-bold"
    _, _ -> ""
  }
}

fn dot(name: String) {
  let bg = case name {
    "up" -> "bg-teal"
    "down" -> "bg-red"
    "missed" -> "bg-peach"
    "recovering" -> "bg-mauve"
    _ -> "bg-base"
  }

  html.div(
    [
      attribute.class("w-3 h-3 inline-block rounded-full mr-1 " <> bg),
      attribute.attribute("title", name),
    ],
    [],
  )
}

fn status(app: App) {
  dict.to_list(app.store.states)
  |> list.map(fn(tuple) { tuple.1 })
  |> state.overall_state_name()
}
