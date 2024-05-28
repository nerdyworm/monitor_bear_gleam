import bear/alerts/alert.{type Alert}
import bear_spa/api.{type ApiError, type RemoteData, Done, Loading}
import bear_spa/api/alerts
import bear_spa/app.{type App}
import bear_spa/page/admin/alerts_form as form
import bear_spa/route
import bear_spa/view/ui
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(
    id: Int,
    alert: RemoteData(Alert, ApiError),
    form: form.Model,
    confirm_delete: Bool,
  )
}

pub type Msg {
  GetResponse(Result(Alert, ApiError))
  FormMsg(form.Msg)
  Delete
  DeleteConfirmed
  DeleteResponse(Result(Alert, ApiError))
}

pub fn init(app: App, id: Int) -> #(Model, Effect(Msg)) {
  let #(form, effects) = form.init(app, alert.new(), "Update alert")

  let model = Model(id: id, alert: Loading, form: form, confirm_delete: False)

  #(
    model,
    effect.batch([
      alerts.get_alert(id, app, GetResponse),
      effect.map(effects, FormMsg),
    ]),
  )
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    GetResponse(Ok(alert)) -> {
      let #(form, _effects) = form.init(app, alert, "Update alert")
      #(Model(..model, form: form, alert: Done(Ok(alert))), effect.none())
    }

    GetResponse(response) -> {
      #(Model(..model, alert: Done(response)), effect.none())
    }

    FormMsg(form.Response(Ok(_alert))) -> {
      #(
        model,
        effect.batch([
          route.push("/admin/alerts"),
          app.flash(app, "Alert saved"),
        ]),
      )
    }

    FormMsg(submsg) -> {
      let #(form, effects) = form.update(app, model.form, submsg)
      #(Model(..model, form: form), effect.map(effects, FormMsg))
    }

    Delete -> {
      #(Model(..model, confirm_delete: True), effect.none())
    }

    DeleteConfirmed -> {
      let assert Done(Ok(alert)) = model.alert
      #(
        Model(..model, confirm_delete: False),
        alerts.delete_alert(alert, app, DeleteResponse),
      )
    }

    DeleteResponse(_) -> {
      #(
        model,
        effect.batch([
          route.push("/admin/alerts"),
          app.flash(app, "Alert was deleted"),
        ]),
      )
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("alerts-edit")], [
    html.div([attribute.class("page-header")], [
      html.h1([], [html.text("Edit Alert")]),
      html.div([attribute.class("page-actions flex space-x-4")], [
        view_delete_button(model),
        html.a([attribute.href("/admin/alerts"), attribute.class("btn")], [
          html.text("Back"),
        ]),
      ]),
    ]),
    html.div([attribute.class("page-body")], [
      case model.alert {
        Done(Ok(_)) -> element.map(form.view(model.form), FormMsg)
        _ -> html.div([], [])
      },
    ]),
  ])
}

fn view_delete_button(model: Model) {
  case model.confirm_delete {
    False ->
      html.button([attribute.class("btn"), event.on_click(Delete)], [
        html.text("Delete this alert"),
      ])

    True ->
      html.button(
        [attribute.class("btn-danger"), event.on_click(DeleteConfirmed)],
        [
          ui.icon("hero-exclamation-triangle w-4 h-4 mr-1"),
          html.text("Confirm Delete Alert"),
        ],
      )
  }
}
