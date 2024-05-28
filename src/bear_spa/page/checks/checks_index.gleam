import bear/monitors/flip.{type Flip}
import bear/monitors/monitor.{type Monitor}
import bear/monitors/state.{type State}
import bear/monitors/status.{type Status, Down, Up}
import bear_spa/api.{type ApiError}
import bear_spa/api/monitors
import bear_spa/app.{type App}
import bear_spa/lib/time
import bear_spa/view/sparkchart
import bear_spa/view/ui
import birl
import birl/duration
import gleam/dict.{type Dict}
import gleam/int
import gleam/iterator
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/sub
import lustre/sub/time as ticker

pub type Model {
  Model(flips: Dict(Int, List(Flip)), range: List(String))
}

pub type Msg {
  Tick
  LoadedMonitors(Result(List(Monitor), ApiError))
  LoadedMonitorStates(Result(List(State), ApiError))
  LoadedMonitorFlips(Result(List(Flip), ApiError))
}

pub fn title(_app: App, _model: Model) -> String {
  "Checks"
}

pub fn init(app: App) -> #(Model, Effect(Msg)) {
  let model = Model(flips: dict.new(), range: init_range())

  #(
    model,
    effect.batch([
      monitors.list_monitors(app, LoadedMonitors),
      monitors.list_monitor_states(app, LoadedMonitorStates),
      monitors.list_monitor_flips(app, LoadedMonitorFlips),
    ]),
  )
}

pub fn subscriptions(_app: App, _model: Model) -> sub.Sub(Msg) {
  sub.batch([ticker.every("check_index_ticker", 1000, Tick)])
}

fn init_range() {
  let now = birl.utc_now()

  birl.add(now, duration.days(-29))
  |> birl.range(Some(now), duration.days(1))
  |> iterator.map(birl.to_naive_date_string)
  |> iterator.to_list()
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick -> {
      #(model, effect.none())
    }

    LoadedMonitors(Ok(monitors)) -> {
      #(model, app.replace_monitors(app, monitors))
    }

    LoadedMonitorStates(Ok(states)) -> {
      #(model, app.replace_states(app, states))
    }

    LoadedMonitorFlips(Ok(flips)) -> {
      #(Model(..model, flips: flips_to_dict(flips)), effect.none())
    }

    _ -> #(model, effect.none())
  }
}

pub fn view(app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("checks-index")], [
    html.div([attribute.class("page-header")], [
      html.h1([], [html.text("Listing Checks")]),
      html.div([attribute.class("page-actions")], [
        html.a([attribute.href("/checks/new"), attribute.class("btn-primary")], [
          html.text("Create check"),
        ]),
      ]),
    ]),
    html.div(
      [attribute.class("monitors space-y-4")],
      app.store.monitors
        |> dict.values()
        |> list.map(fn(m) { view_monitor(m, model, app) }),
    ),
  ])
}

pub fn view_monitor(monitor: Monitor, model: Model, app: App) -> Element(Msg) {
  let sid = int.to_string(monitor.id)

  let state = case dict.get(app.store.states, monitor.id) {
    Error(Nil) -> state.new()
    Ok(state) -> state
  }

  html.div(
    [
      attribute.id("monitor-" <> sid),
      attribute.class("monitor rounded-md p-4 bg-mantle"),
    ],
    [
      html.div([attribute.class("monitor-header mb-2")], [
        html.a(
          [
            attribute.href("/checks/" <> sid),
            attribute.class("block flex mb-1"),
          ],
          [
            html.div([attribute.class("monitor-left")], [
              html.div([attribute.class("name")], [html.text(monitor.name)]),
              html.div([attribute.class("url text-subtext0 text-xs")], [
                html.text(monitor.config.url),
              ]),
            ]),
            div([class("ml-2")], [
              div([class("text-subtext0")], [
                span([], [text("Next check ")]),
                case state.next_region {
                  Some(region) -> span([class("font-bold")], [text(region)])
                  None -> span([], [])
                },
              ]),
              div([class("text-text text-xs font-bold")], [
                case state.checking, state.next_check_at {
                  False, Some(time) -> text(time.since(time))
                  _, _ -> span([class("text-text/10")], [text("-")])
                },
              ]),
            ]),
            html.div(
              [attribute.class("monitor-right ml-auto mr-2 text-right")],
              [
                html.div([attribute.class("name")], [ui.state(state)]),
                html.div(
                  [attribute.class("last_runtime_ms text-subtext0 text-sm")],
                  [
                    html.text(case state.metrics.last_runtime_ms {
                      option.Some(ms) -> int.to_string(ms) <> "ms"
                      option.None -> ""
                    }),
                  ],
                ),
              ],
            ),
            html.div([attribute.class("monitor-center")], [
              sparkchart.line(state.metrics.runtimes, 100, 35),
            ]),
          ],
        ),
      ]),
      view_monitor_uptime(monitor, model, app),
    ],
  )
}

fn view_monitor_uptime(monitor: Monitor, model: Model, _app: App) {
  let uptime =
    dict.get(model.flips, monitor.id)
    |> result.unwrap([])
    |> flips_to_uptime(model.range)

  html.div([attribute.class("monitor-uptime")], [
    html.div(
      [attribute.class("flex space-x-0.5")],
      list.map(uptime, fn(ds) {
        let color = case ds.1 {
          "new" -> "bg-base"
          "up" -> "bg-teal"
          "down" -> "bg-red"
          _ -> ""
        }

        html.div(
          [
            attribute.attribute("title", ds.0),
            attribute.class("w-2 h-12 rounded flex-1 " <> color),
          ],
          [],
        )
      }),
    ),
  ])
}

fn flips_to_uptime(flips: List(Flip), range: List(String)) {
  list.fold(range, #([], "new"), fn(acc, date) {
    let down = flips_by_date_and_status(flips, date, Down)
    let up = flips_by_date_and_status(flips, date, Up)

    case down, up, flips {
      _, _, [] -> #(list.append(acc.0, [#(date, acc.1)]), acc.1)
      True, True, _ -> #(list.append(acc.0, [#(date, "down")]), "up")
      True, _, _ -> #(list.append(acc.0, [#(date, "down")]), "down")
      _, True, _ -> #(list.append(acc.0, [#(date, "up")]), "up")
      _, _, _ -> #(list.append(acc.0, [#(date, acc.1)]), acc.1)
    }
  }).0
}

fn flips_by_date_and_status(flips: List(Flip), date: String, status: Status) {
  flips
  |> list.filter(fn(flip: Flip) {
    date == string.slice(flip.inserted_at, 0, 10)
  })
  |> list.any(fn(flip: Flip) { flip.to == status })
}

fn flips_to_dict(flips: List(Flip)) {
  list.fold(flips, dict.new(), fn(acc, flip: Flip) {
    case dict.get(acc, flip.monitor_id) {
      Error(Nil) -> {
        dict.insert(acc, flip.monitor_id, [flip])
      }

      Ok(things) -> {
        dict.insert(acc, flip.monitor_id, list.append(things, [flip]))
      }
    }
  })
}
