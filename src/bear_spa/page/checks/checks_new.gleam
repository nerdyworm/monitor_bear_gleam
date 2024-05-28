import bear/monitors/config.{type Config, Config}
import bear/monitors/monitor.{type Monitor, Monitor}
import bear_spa/api.{type ApiError, Validation}
import bear_spa/api/monitors
import bear_spa/app.{type App}
import bear_spa/route
import bear_spa/view/ui
import gleam/int
import gleam/io
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, h1, p, text}
import lustre/event
import validates.{type Errors}

pub type Model {
  Model(monitor: Monitor, errors: List(Errors))
}

pub type Msg {
  Change(Monitor)
  Submit
  Created(Result(Monitor, ApiError))
}

pub fn title(_: App, _model: Model) -> String {
  "Create Check"
}

pub fn init(_app: App) -> #(Model, Effect(Msg)) {
  let model = Model(monitor: monitor.new(), errors: [])
  #(model, effect.batch([]))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Submit -> {
      #(
        Model(..model, errors: []),
        monitors.create_monitor(model.monitor, app, Created),
      )
    }

    Change(monitor) -> {
      #(Model(..model, monitor: monitor), effect.none())
    }

    Created(Error(Validation(errors))) -> {
      #(Model(..model, errors: errors), effect.none())
    }

    Created(Error(other)) -> {
      io.debug(other)
      #(model, effect.none())
    }

    Created(Ok(monitor)) -> {
      let uri = "/checks/" <> int.to_string(monitor.id)
      #(model, effect.batch([route.push(uri), app.flash(app, "Check created")]))
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("")], [
    html.form([event.on_submit(Submit)], [
      div([class("flex bg-mantle p-4 rounded-md space-x-4 shadow mb-8")], [
        div([class("w-1/3")], [
          h1([class("text-2xl font-bold mb-2")], [text("Uptime Monitor")]),
          p([], [text("We just need a few fields to start running monitors.")]),
        ]),
        div([class("w-2/3")], [
          alerts(model),
          ui.text("name", "Name", model.monitor.name, model.errors, fn(input) {
            Monitor(..model.monitor, name: input)
            |> Change
          }),
          ui.text(
            "config.url",
            "URL",
            model.monitor.config.url,
            model.errors,
            fn(input) {
              Monitor(
                ..model.monitor,
                config: Config(..model.monitor.config, url: input),
              )
              |> Change
            },
          ),
        ]),
      ]),
      div([class("text-right mt-8")], [
        button([attribute.type_("submit"), class("btn-primary")], [
          text("Create new health check"),
        ]),
      ]),
    ]),
  ])
}

fn alerts(model: Model) {
  case validates.error_on(model.errors, "team.limits.monitors") {
    Error(Nil) -> ui.null()
    Ok(_) ->
      div([class("mb-4")], [
        ui.alert(
          "You have reached your monitor limit, please upgrade your plan if you need more.",
        ),
      ])
  }
}
