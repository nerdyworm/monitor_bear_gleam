import bear/monitors/assertion.{type Assertion, Assertion}
import bear/monitors/config.{type Config, type Header, Config, Header, Request}
import bear/monitors/monitor.{type Monitor, Monitor}
import bear/tags
import bear/teams/team.{type Team}
import bear_spa/api.{type ApiError, type RemoteData, Done, Loading, Validation}
import bear_spa/api/admin
import bear_spa/api/monitors
import bear_spa/app.{type App}
import bear_spa/route
import bear_spa/view/ui
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import lustre/attribute.{class}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, h1, span, text}
import lustre/event
import validates.{type Errors}

const regions = [
  #("us-west", "Los Angeles, CA"), #("us-east", "Secaucus, NJ"),
  #("europe", "Frankfurt, Germany"), #("japan", "Tokyo, Japan"),
  #("india", "Mumbai, India"), #("austrailia", "Sydney, Austrailia"),
]

pub type Model {
  Model(
    monitor: RemoteData(Monitor, ApiError),
    team: RemoteData(Team, ApiError),
    errors: List(Errors),
  )
}

pub type Msg {
  Change(Monitor)
  Submit
  Created(Result(Monitor, ApiError))
  Loaded(Result(Monitor, ApiError))
  LoadedTeam(Result(Team, ApiError))
}

pub fn title(_app: App, model: Model) -> String {
  case model.monitor {
    Done(Ok(monitor)) -> "Edit " <> monitor.name
    _ -> "Edit"
  }
}

pub fn init(app: App, id: Int) -> #(Model, Effect(Msg)) {
  let model = Model(monitor: Loading, team: Loading, errors: [])

  #(
    model,
    effect.batch([
      admin.get_team(app, LoadedTeam),
      monitors.get_monitor(id, app, Loaded),
    ]),
  )
}

pub fn update(app: App, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Loaded(result) -> {
      #(Model(..model, monitor: Done(result)), effect.none())
    }

    LoadedTeam(result) -> {
      #(Model(..model, team: Done(result)), effect.none())
    }

    Submit -> {
      let assert Done(Ok(monitor)) = model.monitor
      #(
        Model(..model, errors: []),
        monitors.update_monitor(monitor, app, Created),
      )
    }

    Change(monitor) -> {
      #(Model(..model, monitor: Done(Ok(monitor))), effect.none())
    }

    Created(Error(Validation(errors))) -> {
      #(Model(..model, errors: errors), effect.none())
    }

    Created(Error(other)) -> {
      io.debug(other)
      #(model, effect.none())
    }

    Created(Ok(monitor)) -> {
      #(
        model,
        effect.batch([
          app.replace_monitor(app, monitor),
          app.flash(app, "Check updated"),
          route.push("/checks/" <> int.to_string(monitor.id)),
        ]),
      )
    }
  }
}

pub fn view(_app: App, model: Model) -> Element(Msg) {
  html.div([attribute.class("p-4")], [
    case model.monitor, model.team {
      Done(Ok(monitor)), Done(Ok(team)) -> {
        view_form(monitor, team, model)
      }

      Done(Error(error)), _ -> {
        div([], [text(string.inspect(error))])
      }

      _, _ -> {
        div([], [text("Loading...")])
      }
    },
  ])
}

fn view_form(monitor: Monitor, team: Team, model: Model) -> Element(Msg) {
  html.form([event.on_submit(Submit)], [
    div([class("bg-mantle p-4 rounded-md shadow mb-8")], [
      div([class("")], [h1([class("text-2xl font-bold mb-2")], [text("Meta")])]),
      div([class("")], [
        ui.text("name", "Name", monitor.name, model.errors, fn(input) {
          Monitor(..monitor, name: input)
          |> Change
        }),
        ui.text(
          "tags",
          "Tags",
          tags.join(monitor.tags),
          model.errors,
          fn(value) { Change(Monitor(..monitor, tags: tags.split(value))) },
        ),
      ]),
    ]),
    div([class("bg-mantle p-4 rounded-md shadow mb-8")], [
      div([class("")], [
        h1([class("text-2xl font-bold mb-2")], [text("Request Settings")]),
      ]),
      div([class("")], [
        ui.text(
          "config.url",
          "URL",
          monitor.config.url,
          model.errors,
          fn(input) {
            Monitor(..monitor, config: Config(..monitor.config, url: input))
            |> Change
          },
        ),
        ui.select(
          "config.interval",
          "Interval",
          monitor.config.interval,
          config.intervals_for_team(team)
            |> list.map(fn(o) { #(o, o) }),
          model.errors,
          fn(input) {
            Monitor(
              ..monitor,
              config: Config(..monitor.config, interval: input),
            )
            |> Change
          },
        ),
      ]),
      div([class("form-group")], [
        html.label([class("form-label")], [
          text("Which regions should we monitor from?"),
        ]),
        div(
          [class("grid grid-cols-3 gap-2")],
          list.map(regions, fn(region) {
            ui.checkbox(
              "config.regions",
              region.1,
              list.contains(monitor.config.regions, region.0),
              fn(monitored) {
                Change(toggle_region(monitor, monitored, region.0))
              },
            )
          }),
        ),
      ]),
    ]),
    div([class("bg-mantle p-4 rounded-md shadow mb-8")], [
      div([class("")], [view_assertions_builder(monitor, model)]),
    ]),
    div([class("bg-mantle p-4 rounded-md shadow mb-8")], [
      div([class("")], [
        h1([class("text-2xl font-bold mb-2")], [text("Tolerance and Recovery")]),
      ]),
      div([class("")], [
        ui.int(
          "config.tolerance",
          "Tolerance",
          monitor.config.tolerance,
          model.errors,
          fn(input) {
            Monitor(
              ..monitor,
              config: Config(..monitor.config, tolerance: input),
            )
            |> Change
          },
        ),
        ui.int(
          "config.recovery",
          "Recovery",
          monitor.config.recovery,
          model.errors,
          fn(input) {
            Monitor(
              ..monitor,
              config: Config(..monitor.config, recovery: input),
            )
            |> Change
          },
        ),
      ]),
    ]),
    div([class("bg-mantle p-4 rounded-md shadow mb-8")], [
      div([class("")], [
        h1([class("text-2xl font-bold mb-2")], [text("HTTP Requset Settiongs")]),
      ]),
      div([class("")], [
        ui.select(
          "config.request.method",
          "Method",
          monitor.config.request.method,
          [#("get", "get"), #("post", "post")],
          model.errors,
          fn(input) {
            Monitor(
              ..monitor,
              config: Config(
                ..monitor.config,
                request: Request(..monitor.config.request, method: input),
              ),
            )
            |> Change
          },
        ),
        ui.textarea(
          "config.request.body",
          "Body",
          monitor.config.request.body,
          model.errors,
          fn(input) {
            Monitor(
              ..monitor,
              config: Config(
                ..monitor.config,
                request: Request(..monitor.config.request, body: input),
              ),
            )
            |> Change
          },
        ),
        ui.int(
          "config.request.timeout",
          "Timeout",
          monitor.config.request.timeout,
          model.errors,
          fn(input) {
            Monitor(
              ..monitor,
              config: Config(
                ..monitor.config,
                request: Request(..monitor.config.request, timeout: input),
              ),
            )
            |> Change
          },
        ),
        view_headers_builder(monitor, model),
      ]),
    ]),
    div([class("text-right mt-8")], [
      button([attribute.type_("submit"), class("btn-primary")], [
        text("Update health check settings"),
      ]),
    ]),
  ])
}

fn view_headers_builder(monitor: Monitor, _model: Model) {
  div([], [
    div([], [h1([], [text("Headers")])]),
    div(
      [],
      list.index_map(
        monitor.config.request.headers,
        fn(header: Header, index: Int) {
          div([class("flex items-center space-x-2 mb-2")], [
            div([], [
              html.input([
                class("form-input"),
                attribute.type_("text"),
                attribute.value(header.name),
                attribute.placeholder("X-Custom-Header"),
                event.on_input(fn(value) {
                  Change(
                    Monitor(
                      ..monitor,
                      config: config.replace_header_at(
                        monitor.config,
                        index,
                        Header(..header, name: value),
                      ),
                    ),
                  )
                }),
              ]),
            ]),
            div([], [
              html.input([
                class("form-input"),
                attribute.type_("text"),
                attribute.value(header.value),
                attribute.placeholder("Your custom value"),
                event.on_input(fn(value) {
                  Change(
                    Monitor(
                      ..monitor,
                      config: config.replace_header_at(
                        monitor.config,
                        index,
                        Header(..header, value: value),
                      ),
                    ),
                  )
                }),
              ]),
            ]),
            div([], [
              button(
                [
                  class("btn"),
                  attribute.type_("button"),
                  event.on("click", fn(_) {
                    Monitor(
                      ..monitor,
                      config: config.remove_header_at(monitor.config, index),
                    )
                    |> Change()
                    |> Ok()
                  }),
                ],
                [ui.icon("hero-trash h-4 w-4")],
              ),
            ]),
          ])
        },
      ),
    ),
    div([], [
      button(
        [
          class("btn small"),
          attribute.type_("button"),
          event.on("click", fn(_) {
            Monitor(..monitor, config: config.new_header(monitor.config))
            |> Change()
            |> Ok()
          }),
        ],
        [ui.icon("hero-plus h-4 w-4"), text("Add header")],
      ),
    ]),
  ])
}

fn toggle_region(monitor: Monitor, monitored: Bool, region: String) {
  let regions = monitor.config.regions

  let updated =
    case monitored {
      True -> [region, ..regions]
      False -> list.filter(regions, fn(r) { r != region })
    }
    |> list.unique()

  Monitor(..monitor, config: Config(..monitor.config, regions: updated))
}

fn view_assertions_builder(monitor: Monitor, model: Model) {
  div([], [
    div([class("mb-4")], [
      h1([class("font-bold text-xl")], [text("Assertions")]),
      div([class("text-subtext0")], [
        text("These determine wether or not a health check is heathly"),
      ]),
    ]),
    div(
      [],
      list.map(monitor.config.assertions, fn(assertion) {
        view_assertion(assertion, monitor, model)
      }),
    ),
    div([], [
      button(
        [
          class("btn"),
          attribute.type_("button"),
          event.on("click", fn(_) { change_add_new_assertion(monitor) }),
        ],
        [text("Add new assertion")],
      ),
    ]),
  ])
}

fn view_assertion(rule: Assertion, monitor: Monitor, _model: Model) {
  div([class("mb-2")], [
    div([class("")], [
      div([class("flex space-x-2 items-center")], [
        source_select(rule, monitor),
        op_select(rule, monitor),
        value_value_input(rule, monitor),
        button(
          [
            attribute.type_("button"),
            event.on("click", fn(_) { change_remove_assertion(monitor, rule) }),
            class("btn"),
          ],
          [span([class("hero-trash w-4 h-4")], [])],
        ),
      ]),
    ]),
  ])
}

fn source_select(assertion: Assertion, monitor: Monitor) {
  let value = assertion.source_to_string(assertion.source)
  let on_input = fn(value) {
    let source = assertion.source_from_string(value)
    change_update_assertion(monitor, Assertion(..assertion, source: source))
  }

  let options = [
    #("response.status", "response.status"),
    #("response.body", "response.body"),
    #("response.time", "response.time"),
  ]

  html.select(
    [
      attribute.name("source_" <> assertion.id),
      attribute.class("form-input"),
      event.on_input(on_input),
    ],
    list.map(options, fn(option) {
      let attrs = [attribute.value(option.0)]
      let attrs = case option.0 == value {
        True -> [attribute.selected(True), ..attrs]
        False -> attrs
      }
      html.option(attrs, option.1)
    }),
  )
}

fn op_select(assertion: Assertion, monitor: Monitor) {
  let options = options_for_op(assertion.source)
  let value = assertion.op_to_string(assertion.op)
  let on_input = fn(value) {
    let op = assertion.op_from_string(value)
    change_update_assertion(monitor, Assertion(..assertion, op: op))
  }

  html.select(
    [
      attribute.name("op_" <> assertion.id),
      attribute.class("form-input"),
      event.on_input(on_input),
    ],
    list.map(options, fn(option) {
      let attrs = [attribute.value(option.0)]
      let attrs = case option.0 == value {
        True -> [attribute.selected(True), ..attrs]
        False -> attrs
      }
      html.option(attrs, option.1)
    }),
  )
}

fn options_for_op(source) {
  case source {
    assertion.Response("body") -> {
      [
        #("contains", "contains"),
        #("!contains", "does not contain"),
        #("==", "equals"),
        #("!=", "does not equal"),
      ]
    }

    _ -> {
      [
        #("==", "equals"),
        #("!=", "not equals"),
        #("<", "less than"),
        #("<=", "less than or equal"),
        #(">=", "greater than or equal"),
        #(">", "greater than"),
      ]
    }
  }
}

fn value_value_input(assertion: Assertion, monitor: Monitor) {
  html.input([
    attribute.type_("text"),
    attribute.name("expcted_" <> assertion.id),
    attribute.value(assertion.value),
    attribute.class("form-input"),
    event.on_input(fn(value) {
      change_update_assertion(monitor, Assertion(..assertion, value: value))
    }),
  ])
}

fn change_add_new_assertion(monitor: Monitor) {
  let config =
    Config(
      ..monitor.config,
      assertions: list.append(monitor.config.assertions, [assertion.new()]),
    )

  Ok(Change(Monitor(..monitor, config: config)))
}

fn change_remove_assertion(monitor: Monitor, assertion: Assertion) {
  let config =
    Config(
      ..monitor.config,
      assertions: assertion.remove(monitor.config.assertions, assertion),
    )

  Ok(Change(Monitor(..monitor, config: config)))
}

fn change_update_assertion(monitor: Monitor, assertion: Assertion) {
  let config =
    Config(
      ..monitor.config,
      assertions: assertion.replace(monitor.config.assertions, assertion),
    )

  Change(Monitor(..monitor, config: config))
}
