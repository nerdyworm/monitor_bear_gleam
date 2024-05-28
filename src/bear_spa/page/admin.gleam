import bear_spa/app.{type App}
import bear_spa/page/admin/admin_dashboard
import bear_spa/page/admin/alerts_edit
import bear_spa/page/admin/alerts_index
import bear_spa/page/admin/alerts_new
import bear_spa/page/admin/memberships_index
import bear_spa/page/admin/plan_index
import bear_spa/route
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/sub

pub type Model {
  Model(
    admin_dashboard: admin_dashboard.Model,
    alerts_edit: alerts_edit.Model,
    alerts_index: alerts_index.Model,
    alerts_new: alerts_new.Model,
    memberships_index: memberships_index.Model,
    plan_index: plan_index.Model,
    route: route.Admin,
  )
}

pub type Msg {
  AdminDashboardMsg(admin_dashboard.Msg)
  AlertsIndexMsg(alerts_index.Msg)
  AlertsNewMsg(alerts_new.Msg)
  AlertsEditMsg(alerts_edit.Msg)
  MembershipsIndexMsg(memberships_index.Msg)
  PlanIndexMsg(plan_index.Msg)
}

pub fn init(app: App, route: route.Admin) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      admin_dashboard: admin_dashboard.init(app).0,
      alerts_edit: alerts_edit.init(app, 0).0,
      alerts_index: alerts_index.init(app).0,
      alerts_new: alerts_new.init(app).0,
      memberships_index: memberships_index.init(app).0,
      plan_index: plan_index.init(app).0,
      route: route,
    )

  case route {
    route.AdminDashboard -> {
      let tuple = admin_dashboard.init(app)

      Model(..model, admin_dashboard: tuple.0)
      |> map_effects(tuple.1, AdminDashboardMsg)
    }

    route.AlertsIndex -> {
      let tuple = alerts_index.init(app)

      Model(..model, alerts_index: tuple.0)
      |> map_effects(tuple.1, AlertsIndexMsg)
    }

    route.AlertsNew -> {
      let tuple = alerts_new.init(app)

      Model(..model, alerts_new: tuple.0)
      |> map_effects(tuple.1, AlertsNewMsg)
    }

    route.AlertsEdit(id) -> {
      let tuple = alerts_edit.init(app, id)

      Model(..model, alerts_edit: tuple.0)
      |> map_effects(tuple.1, AlertsEditMsg)
    }

    route.MembershipsIndex -> {
      let #(submodel, effects) = memberships_index.init(app)

      Model(..model, memberships_index: submodel)
      |> map_effects(effects, MembershipsIndexMsg)
    }

    route.PlanIndex -> {
      let #(submodel, effects) = plan_index.init(app)

      Model(..model, plan_index: submodel)
      |> map_effects(effects, PlanIndexMsg)
    }
  }
}

fn map_effects(model, effects, to_page_msg) {
  #(model, effect.map(effects, fn(msg) { to_page_msg(msg) }))
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    AdminDashboardMsg(submsg) -> {
      let result = admin_dashboard.update(app, model.admin_dashboard, submsg)

      Model(..model, admin_dashboard: result.0)
      |> map_effects(result.1, AdminDashboardMsg)
    }

    AlertsIndexMsg(submsg) -> {
      let result = alerts_index.update(app, model.alerts_index, submsg)

      Model(..model, alerts_index: result.0)
      |> map_effects(result.1, AlertsIndexMsg)
    }

    AlertsNewMsg(submsg) -> {
      let result = alerts_new.update(app, model.alerts_new, submsg)

      Model(..model, alerts_new: result.0)
      |> map_effects(result.1, AlertsNewMsg)
    }

    AlertsEditMsg(submsg) -> {
      let result = alerts_edit.update(app, model.alerts_edit, submsg)

      Model(..model, alerts_edit: result.0)
      |> map_effects(result.1, AlertsEditMsg)
    }

    MembershipsIndexMsg(submsg) -> {
      let result =
        memberships_index.update(app, model.memberships_index, submsg)

      Model(..model, memberships_index: result.0)
      |> map_effects(result.1, MembershipsIndexMsg)
    }

    PlanIndexMsg(submsg) -> {
      let result = plan_index.update(app, model.plan_index, submsg)

      Model(..model, plan_index: result.0)
      |> map_effects(result.1, PlanIndexMsg)
    }
  }
}

pub fn view(app: App, model: Model, route: route.Admin) -> Element(Msg) {
  html.div([attribute.class("admin")], [
    case route {
      route.AdminDashboard -> {
        admin_dashboard.view(app, model.admin_dashboard)
        |> element.map(AdminDashboardMsg)
      }

      route.AlertsIndex -> {
        alerts_index.view(app, model.alerts_index)
        |> element.map(AlertsIndexMsg)
      }

      route.AlertsNew -> {
        alerts_new.view(app, model.alerts_new)
        |> element.map(AlertsNewMsg)
      }

      route.AlertsEdit(_) -> {
        alerts_edit.view(app, model.alerts_edit)
        |> element.map(AlertsEditMsg)
      }

      route.MembershipsIndex -> {
        memberships_index.view(app, model.memberships_index)
        |> element.map(MembershipsIndexMsg)
      }

      route.PlanIndex -> {
        plan_index.view(app, model.plan_index)
        |> element.map(PlanIndexMsg)
      }
    },
  ])
}

pub fn subscriptions(app: App, model: Model) {
  case model.route {
    route.MembershipsIndex -> {
      memberships_index.subscriptions(app, model.memberships_index)
      |> sub.map(MembershipsIndexMsg)
    }

    _ -> sub.none()
  }
}
