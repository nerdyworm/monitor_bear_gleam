import bear_spa/app.{type App}
import bear_spa/page/checks/checks_edit
import bear_spa/page/checks/checks_index
import bear_spa/page/checks/checks_new
import bear_spa/page/checks/checks_show
import bear_spa/route
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/sub

pub type Model {
  Model(
    checks_index: checks_index.Model,
    checks_show: checks_show.Model,
    checks_edit: checks_edit.Model,
    checks_new: checks_new.Model,
    route: route.Checks,
  )
}

pub type Msg {
  ChecksIndexMsg(checks_index.Msg)
  ChecksShowMsg(checks_show.Msg)
  ChecksEditMsg(checks_edit.Msg)
  ChecksNewMsg(checks_new.Msg)
}

pub fn init(app: App, route: route.Checks) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      checks_index: checks_index.init(app).0,
      checks_show: checks_show.init(app, 0).0,
      checks_edit: checks_edit.init(app, 0).0,
      checks_new: checks_new.init(app).0,
      route: route,
    )

  case route {
    route.ChecksIndex -> {
      let #(submodel, effects) = checks_index.init(app)

      Model(..model, checks_index: submodel)
      |> map_effects(effects, ChecksIndexMsg)
    }

    route.ChecksShow(id) -> {
      let #(submodel, effects) = checks_show.init(app, id)

      Model(..model, checks_show: submodel)
      |> map_effects(effects, ChecksShowMsg)
    }

    route.ChecksEdit(id) -> {
      let tuple = checks_edit.init(app, id)

      Model(..model, checks_edit: tuple.0)
      |> map_effects(tuple.1, ChecksEditMsg)
    }

    route.ChecksNew -> {
      let tuple = checks_new.init(app)

      Model(..model, checks_new: tuple.0)
      |> map_effects(tuple.1, ChecksNewMsg)
    }
  }
}

fn map_effects(model, effects, to_page_msg) {
  #(model, effect.map(effects, fn(msg) { to_page_msg(msg) }))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ChecksIndexMsg(submsg) -> {
      let result = checks_index.update(app, model.checks_index, submsg)

      Model(..model, checks_index: result.0)
      |> map_effects(result.1, ChecksIndexMsg)
    }

    ChecksShowMsg(submsg) -> {
      let result = checks_show.update(app, model.checks_show, submsg)

      Model(..model, checks_show: result.0)
      |> map_effects(result.1, ChecksShowMsg)
    }

    ChecksEditMsg(submsg) -> {
      let result = checks_edit.update(app, model.checks_edit, submsg)

      Model(..model, checks_edit: result.0)
      |> map_effects(result.1, ChecksEditMsg)
    }

    ChecksNewMsg(submsg) -> {
      let result = checks_new.update(app, model.checks_new, submsg)

      Model(..model, checks_new: result.0)
      |> map_effects(result.1, ChecksNewMsg)
    }
  }
}

pub fn view(app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("checks")], [
    case model.route {
      route.ChecksIndex -> {
        checks_index.view(app, model.checks_index)
        |> element.map(ChecksIndexMsg)
      }

      route.ChecksShow(_id) -> {
        checks_show.view(app, model.checks_show)
        |> element.map(ChecksShowMsg)
      }

      route.ChecksEdit(_) -> {
        checks_edit.view(app, model.checks_edit)
        |> element.map(ChecksEditMsg)
      }

      route.ChecksNew -> {
        checks_new.view(app, model.checks_new)
        |> element.map(ChecksNewMsg)
      }
    },
  ])
}

pub fn subscriptions(app: App, model: Model) {
  case model.route {
    route.ChecksShow(_) -> {
      checks_show.subscriptions(app, model.checks_show)
      |> sub.map(fn(m) { ChecksShowMsg(m) })
    }

    _ -> sub.none()
  }
}

pub fn title(app: App, model: Model) -> String {
  case model.route {
    route.ChecksEdit(_) -> checks_edit.title(app, model.checks_edit)
    route.ChecksIndex -> checks_index.title(app, model.checks_index)
    route.ChecksNew -> checks_new.title(app, model.checks_new)
    route.ChecksShow(_) -> checks_show.title(app, model.checks_show)
  }
}
