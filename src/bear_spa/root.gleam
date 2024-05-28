import bear/monitors/monitor.{type Monitor}
import bear/monitors/state
import bear/pubsub_message.{type PubsubMessage, MonitorState}
import bear/session.{type Session}
import bear_spa/api.{type ApiError}
import bear_spa/api/monitors
import bear_spa/app.{type App, App}
import bear_spa/lib/localstorage
import bear_spa/lib/pubsub
import bear_spa/page/admin
import bear_spa/page/checks
import bear_spa/page/dashboard
import bear_spa/page/heartbeats_index
import bear_spa/page/incidents
import bear_spa/page/login
import bear_spa/page/register
import bear_spa/page/reset_password
import bear_spa/page/reset_password_create
import bear_spa/route.{type Route}
import bear_spa/store
import bear_spa/view/flash
import bear_spa/view/header
import gleam/io
import gleam/json
import gleam/option.{None, Some}
import gleam/uri.{type Uri}
import lustre/attribute
import lustre/browser.{type Document, Document}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/sub

pub type Model {
  Model(
    admin: admin.Model,
    app: App,
    flash: flash.Model,
    checks: checks.Model,
    incidents: incidents.Model,
    dashboard: dashboard.Model,
    heartbeats_index: heartbeats_index.Model,
    login: login.Model,
    register: register.Model,
    reset_password: reset_password.Model,
    reset_password_create: reset_password_create.Model,
  )
}

pub type Msg {
  OnUrlRequest(uri: Uri)
  OnUrlChange(uri: Uri)
  StartSession(session: Session)
  EndSession
  Logout
  OnPubsubMessage(PubsubMessage)
  LoadedMonitors(Result(List(Monitor), ApiError))
  LoadedMonitorStates(Result(List(state.State), ApiError))
  DeletedMonitor(Int)
  PageMsg(PageMsg)
  FlashMessage(String)
  FlashMsg(flash.Msg)
}

pub type PageMsg {
  AdminMsg(admin.Msg)
  ChecksMsg(checks.Msg)
  IncidentsMsg(incidents.Msg)
  // DashboardMsg(dashboard.Msg)
  // HeartbeatsIndexMsg(heartbeats_index.Msg)
  LoginMsg(login.Msg)
  RegisterMsg(register.Msg)
  ResetPasswordMsg(reset_password.Msg)
  ResetPasswordCreateMsg(reset_password_create.Msg)
}

pub fn on_url_request(uri) {
  OnUrlRequest(uri)
}

pub fn on_url_change(uri) {
  OnUrlChange(uri)
}

fn update_page(model: Model, page_msg: PageMsg) {
  case page_msg {
    AdminMsg(submsg) -> {
      let result = admin.update(model.app, model.admin, submsg)

      Model(..model, admin: result.0)
      |> map_effects(result.1, AdminMsg)
    }

    ChecksMsg(submsg) -> {
      let result = checks.update(model.app, model.checks, submsg)

      Model(..model, checks: result.0)
      |> map_effects(result.1, ChecksMsg)
    }

    IncidentsMsg(submsg) -> {
      let result = incidents.update(model.app, model.incidents, submsg)

      Model(..model, incidents: result.0)
      |> map_effects(result.1, IncidentsMsg)
    }

    // DashboardMsg(submsg) -> {
    //   let result = dashboard.update(model.app, model.dashboard, submsg)
    //
    //   Model(..model, dashboard: result.0)
    //   |> map_effects(result.1, DashboardMsg)
    // }
    //
    // HeartbeatsIndexMsg(submsg) -> {
    //   let result =
    //     heartbeats_index.update(model.app, model.heartbeats_index, submsg)
    //
    //   Model(..model, heartbeats_index: result.0)
    //   |> map_effects(result.1, HeartbeatsIndexMsg)
    // }
    LoginMsg(submsg) -> {
      let result = login.update(model.app, model.login, submsg)

      Model(..model, login: result.0)
      |> map_effects(result.1, LoginMsg)
    }

    RegisterMsg(submsg) -> {
      let result = register.update(model.app, model.register, submsg)

      Model(..model, register: result.0)
      |> map_effects(result.1, RegisterMsg)
    }

    ResetPasswordMsg(submsg) -> {
      let result =
        reset_password.update(model.app, model.reset_password, submsg)

      Model(..model, reset_password: result.0)
      |> map_effects(result.1, ResetPasswordMsg)
    }

    ResetPasswordCreateMsg(submsg) -> {
      let result =
        reset_password_create.update(
          model.app,
          model.reset_password_create,
          submsg,
        )

      Model(..model, reset_password_create: result.0)
      |> map_effects(result.1, ResetPasswordCreateMsg)
    }
  }
}

pub fn init(app: App, uri: Uri) {
  let model =
    Model(
      admin: admin.init(app, route.MembershipsIndex).0,
      app: app,
      flash: flash.init(),
      checks: checks.init(app, route.ChecksIndex).0,
      incidents: incidents.init(app, route.IncidentsIndex).0,
      dashboard: dashboard.init(app).0,
      heartbeats_index: heartbeats_index.init(app).0,
      login: login.init(app).0,
      register: register.init(app).0,
      reset_password: reset_password.init(app, "").0,
      reset_password_create: reset_password_create.init(app).0,
    )

  #(
    model,
    effect.batch([
      pubsub_subscribe(model),
      maybe_start_session(app),
      effect.from(fn(dispatch) { dispatch(OnUrlChange(uri)) }),
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnUrlRequest(_uri) -> {
      // need to stash scrool position here...
      #(model, effect.none())
    }

    OnUrlChange(uri) -> {
      let route = route.uri_to_route(uri)
      case route {
        route.Public(_) -> require_no_session(route, model)
        route.Private(_) -> require_session(route, model)
      }
    }

    StartSession(session) -> {
      let app = App(..model.app, session: Some(session))
      let model = Model(..model, app: app)
      let updated = update_route(app.route, model)

      #(
        updated.0,
        effect.batch([
          updated.1,
          monitors.list_monitors(app, LoadedMonitors),
          monitors.list_monitor_states(app, LoadedMonitorStates),
        ]),
      )
    }

    EndSession -> {
      let app = app.end_session(model.app)
      localstorage.remove("session")
      #(Model(..model, app: app), effect.batch([route.push("/login")]))
    }

    Logout -> {
      #(
        model,
        effect.from(fn(_) {
          pubsub.publish(model.app.pubsub, app.SessionInvalid)
        }),
      )
    }

    PageMsg(submsg) -> {
      update_page(model, submsg)
    }

    OnPubsubMessage(MonitorState(state)) -> {
      let store = store.state(model.app.store, state)
      let app = App(..model.app, store: store)
      #(Model(..model, app: app), effect.none())
    }

    OnPubsubMessage(_) -> {
      #(model, effect.none())
    }

    DeletedMonitor(id) -> {
      let store = store.delete_monitor(model.app.store, id)
      let app = App(..model.app, store: store)
      let model = Model(..model, app: app)
      #(model, effect.none())
    }

    LoadedMonitors(Ok(monitors)) -> {
      let store = store.monitors(model.app.store, monitors)
      let app = App(..model.app, store: store)
      let model = Model(..model, app: app)
      #(model, effect.none())
    }

    LoadedMonitors(Error(error)) -> {
      io.debug(error)
      #(model, effect.none())
    }

    LoadedMonitorStates(Ok(states)) -> {
      let store = store.states(model.app.store, states)
      let app = App(..model.app, store: store)
      let model = Model(..model, app: app)
      #(model, effect.none())
    }

    LoadedMonitorStates(Error(error)) -> {
      io.debug(error)
      #(model, effect.none())
    }

    FlashMessage(message) -> {
      let #(flash, effects) = flash.flash(model.flash, message)
      #(
        Model(..model, flash: flash),
        effect.batch([effect.map(effects, FlashMsg)]),
      )
    }

    FlashMsg(msg) -> {
      let #(flash, effects) = flash.update(model.flash, msg)
      #(
        Model(..model, flash: flash),
        effect.batch([effect.map(effects, FlashMsg)]),
      )
    }
  }
}

fn require_session(route: Route, model: Model) {
  case model.app.session {
    Some(_) -> {
      update_route(route, model)
    }

    None -> {
      #(model, route.push("/login"))
    }
  }
}

fn require_no_session(route: Route, model: Model) {
  case model.app.session {
    None -> {
      update_route(route, model)
    }

    Some(_) -> {
      #(model, route.push("/dashboard"))
    }
  }
}

pub fn subscriptions(model: Model) {
  case model.app.route {
    route.Private(route.Checks(_route)) -> {
      checks.subscriptions(model.app, model.checks)
      |> sub.map(fn(m) { PageMsg(ChecksMsg(m)) })
    }

    route.Private(route.Incidents(_route)) -> {
      incidents.subscriptions(model.app, model.incidents)
      |> sub.map(fn(m) { PageMsg(IncidentsMsg(m)) })
    }

    route.Private(route.Admin(_)) -> {
      admin.subscriptions(model.app, model.admin)
      |> sub.map(fn(m) { PageMsg(AdminMsg(m)) })
    }

    route.Public(_) -> {
      sub.none()
    }
  }
}

fn update_route(route: Route, model: Model) {
  let model = Model(..model, app: App(..model.app, route: route))

  case route {
    route.Public(route.Login) -> {
      let tuple = login.init(model.app)

      Model(..model, login: tuple.0)
      |> map_effects(tuple.1, LoginMsg)
    }

    route.Public(route.Register) -> {
      let tuple = register.init(model.app)

      Model(..model, register: tuple.0)
      |> map_effects(tuple.1, RegisterMsg)
    }

    route.Public(route.ResetPassword(token)) -> {
      let tuple = reset_password.init(model.app, token)

      Model(..model, reset_password: tuple.0)
      |> map_effects(tuple.1, ResetPasswordMsg)
    }

    route.Public(route.ResetPasswordCreate) -> {
      let tuple = reset_password_create.init(model.app)

      Model(..model, reset_password_create: tuple.0)
      |> map_effects(tuple.1, ResetPasswordCreateMsg)
    }

    route.Private(route.Admin(admin)) -> {
      let tuple = admin.init(model.app, admin)
      Model(..model, admin: tuple.0)
      |> map_effects(tuple.1, AdminMsg)
    }

    route.Private(route.Checks(route)) -> {
      let tuple = checks.init(model.app, route)
      Model(..model, checks: tuple.0)
      |> map_effects(tuple.1, ChecksMsg)
    }

    route.Private(route.Incidents(route)) -> {
      let tuple = incidents.init(model.app, route)
      Model(..model, incidents: tuple.0)
      |> map_effects(tuple.1, IncidentsMsg)
    }
    // route.Private(route.Dashboard) -> {
    //   let tuple = dashboard.init(model.app)
    //
    //   Model(..model, dashboard: tuple.0)
    //   |> map_effects(tuple.1, DashboardMsg)
    // }
    // route.Private(route.HeartbeatsIndex) -> {
    //   let tuple = heartbeats_index.init(model.app)
    //
    //   Model(..model, heartbeats_index: tuple.0)
    //   |> map_effects(tuple.1, HeartbeatsIndexMsg)
    // }
  }
}

fn map_effects(model, effects, to_page_msg) {
  #(model, effect.map(effects, fn(msg) { PageMsg(to_page_msg(msg)) }))
}

pub fn document(model: Model) {
  Document(title: title(model), body: view(model))
}

fn title(model: Model) {
  case model.app.route {
    route.Public(route.Login) -> {
      "Login - Monitor Bear"
    }

    route.Public(route.Register) -> {
      "Register - Monitor Bear"
    }

    route.Public(route.ResetPassword(_)) -> {
      "Reset your password - Monitor Bear"
    }

    route.Public(route.ResetPasswordCreate) -> {
      "Forgot your password? - Monitor Bear"
    }

    route.Private(route.Checks(_)) -> {
      checks.title(model.app, model.checks) <> " - Monitor Bear"
    }

    route.Private(_) -> {
      "Rawr"
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.body([attribute.class("mocha")], [
    element.map(flash.view(model.flash), FlashMsg),
    case model.app.route {
      route.Public(public) -> {
        html.div([], [
          header.public(model.app),
          view_public_route(public, model),
        ])
      }

      route.Private(private) -> {
        html.div([attribute.class("private")], [
          header.private(model.app, Logout),
          html.div([attribute.class("max-w-3xl mx-auto")], [
            view_private_route(private, model),
          ]),
        ])
      }
    },
  ])
}

fn view_public_route(public: route.Public, model: Model) -> Element(Msg) {
  case public {
    route.Login -> {
      login.view(model.app, model.login)
      |> pmap(LoginMsg)
    }

    route.Register -> {
      register.view(model.app, model.register)
      |> pmap(RegisterMsg)
    }

    route.ResetPassword(_) -> {
      reset_password.view(model.app, model.reset_password)
      |> pmap(ResetPasswordMsg)
    }

    route.ResetPasswordCreate -> {
      reset_password_create.view(model.app, model.reset_password_create)
      |> pmap(ResetPasswordCreateMsg)
    }
  }
}

fn view_private_route(private: route.Private, model: Model) -> Element(Msg) {
  case private {
    route.Admin(admin) -> {
      admin.view(model.app, model.admin, admin)
      |> pmap(AdminMsg)
    }

    route.Checks(_) -> {
      checks.view(model.app, model.checks)
      |> pmap(ChecksMsg)
    }

    route.Incidents(_) -> {
      incidents.view(model.app, model.incidents)
      |> pmap(IncidentsMsg)
    }
  }
}

fn pmap(view, to_msg) {
  element.map(view, fn(msg) { PageMsg(to_msg(msg)) })
}

fn pubsub_subscribe(model: Model) {
  effect.from(fn(dispatch) {
    pubsub.subscribe(model.app.pubsub, fn(event) {
      case event {
        app.SessionStarted(session) -> dispatch(StartSession(session))
        app.SessionInvalid -> dispatch(EndSession)
        app.LoadedMonitors(monitors) -> dispatch(LoadedMonitors(Ok(monitors)))
        app.LoadedMonitorStates(states) -> {
          dispatch(LoadedMonitorStates(Ok(states)))
        }

        app.FlashMessage(message) -> {
          dispatch(FlashMessage(message))
        }

        app.DeletedMonitor(monitor_id) -> {
          dispatch(DeletedMonitor(monitor_id))
        }
      }
    })
  })
}

fn maybe_start_session(app: App) {
  effect.from(fn(_) {
    case localstorage.read("session") {
      Error(Nil) -> Nil
      Ok(session) -> {
        case json.decode(session, session.decoder) {
          Error(_) -> Nil
          Ok(session) -> {
            pubsub.publish(app.pubsub, app.SessionStarted(session))
          }
        }
      }
    }
  })
}
