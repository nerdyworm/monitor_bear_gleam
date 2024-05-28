import bear_spa/app.{type App}
import bear_spa/page/incidents/incidents_index
import bear_spa/page/incidents/incidents_show
import bear_spa/route
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/sub

pub type Model {
  Model(
    incidents_index: incidents_index.Model,
    incidents_show: incidents_show.Model,
    route: route.Incidents,
  )
}

pub type Msg {
  IncidentsIndexMsg(incidents_index.Msg)
  IncidentsShowMsg(incidents_show.Msg)
}

pub fn init(app: App, route: route.Incidents) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      incidents_index: incidents_index.init(app).0,
      incidents_show: incidents_show.init(app, 0).0,
      route: route,
    )

  case route {
    route.IncidentsIndex -> {
      let #(submodel, effects) = incidents_index.init(app)

      Model(..model, incidents_index: submodel)
      |> map_effects(effects, IncidentsIndexMsg)
    }

    route.IncidentsShow(id) -> {
      let #(submodel, effects) = incidents_show.init(app, id)

      Model(..model, incidents_show: submodel)
      |> map_effects(effects, IncidentsShowMsg)
    }
  }
}

fn map_effects(model, effects, to_page_msg) {
  #(model, effect.map(effects, fn(msg) { to_page_msg(msg) }))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    IncidentsIndexMsg(submsg) -> {
      let result = incidents_index.update(app, model.incidents_index, submsg)

      Model(..model, incidents_index: result.0)
      |> map_effects(result.1, IncidentsIndexMsg)
    }

    IncidentsShowMsg(submsg) -> {
      let result = incidents_show.update(app, model.incidents_show, submsg)

      Model(..model, incidents_show: result.0)
      |> map_effects(result.1, IncidentsShowMsg)
    }
  }
}

pub fn view(app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("admin")], [
    case model.route {
      route.IncidentsIndex -> {
        incidents_index.view(app, model.incidents_index)
        |> element.map(IncidentsIndexMsg)
      }

      route.IncidentsShow(_id) -> {
        incidents_show.view(app, model.incidents_show)
        |> element.map(IncidentsShowMsg)
      }
    },
  ])
}

pub fn subscriptions(app: App, model: Model) {
  case model.route {
    route.IncidentsIndex ->
      incidents_index.subscriptions(app, model.incidents_index)
      |> sub.map(fn(m) { IncidentsIndexMsg(m) })

    route.IncidentsShow(_) ->
      incidents_show.subscriptions(app, model.incidents_show)
      |> sub.map(fn(m) { IncidentsShowMsg(m) })
  }
}

pub fn title(_app: App, _model: Model) -> String {
  "Incidents"
  // case model.route {
  //   route.IncidentsEdit(_) -> incidents_edit.title(app, model.incidents_edit)
  //   route.IncidentsIndex -> incidents_index.title(app, model.incidents_index)
  //   route.IncidentsNew -> incidents_new.title(app, model.incidents_new)
  //   route.IncidentsShow(_) -> incidents_show.title(app, model.incidents_show)
  // }
}
