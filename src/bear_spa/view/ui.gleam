import bear/monitors/state.{type State}
import bear/monitors/status
import bear/tags
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute.{class}
import lustre/element/html.{div}
import lustre/event
import validates.{type Errors}

pub type Group {
  Group(
    class: String,
    name: String,
    label: String,
    errors: List(Errors),
    placeholder: String,
    hint: String,
  )
}

pub fn new_group() {
  Group(
    class: "form-group",
    name: "",
    label: "",
    errors: [],
    placeholder: "",
    hint: "",
  )
}

pub fn group(input: Group, tag) {
  html.div(
    [
      attribute.class(
        input.class <> " " <> error_class(input.name, input.errors),
      ),
    ],
    [
      case input.label {
        "" -> html.text("")
        _ ->
          html.label([attribute.class("form-label")], [html.text(input.label)])
      },
      tag,
      case input.hint {
        "" -> html.text("")
        _ -> html.div([attribute.class("form-hint")], [html.text(input.hint)])
      },
      case validates.error_on(input.errors, input.name) {
        Error(Nil) -> html.div([], [html.text("")])
        Ok(errors) ->
          html.div([attribute.class("validation-error")], [
            html.text(string.join(errors, ", ")),
          ])
      },
    ],
  )
}

pub fn text(
  name: String,
  label: String,
  value: String,
  errors: List(Errors),
  on_input: fn(String) -> msg,
) {
  html.div([attribute.class("form-group" <> error_class(name, errors))], [
    html.label([attribute.class("form-label")], [html.text(label)]),
    html.input([
      attribute.type_("text"),
      attribute.name(name),
      attribute.value(value),
      attribute.class("form-input"),
      event.on_input(on_input),
    ]),
    case validates.error_on(errors, name) {
      Error(Nil) -> html.div([], [html.text("")])
      Ok(errors) ->
        html.div([attribute.class("validation-error")], [
          html.text(string.join(errors, ", ")),
        ])
    },
  ])
}

pub fn text_autofocus(
  name: String,
  label: String,
  value: String,
  errors: List(Errors),
  on_input: fn(String) -> msg,
) {
  html.div([attribute.class("form-group" <> error_class(name, errors))], [
    html.label([attribute.class("form-label")], [html.text(label)]),
    html.input([
      attribute.type_("text"),
      attribute.name(name),
      attribute.value(value),
      attribute.class("form-input"),
      attribute.autofocus(True),
      event.on_input(on_input),
    ]),
    case validates.error_on(errors, name) {
      Error(Nil) -> html.div([], [html.text("")])
      Ok(errors) ->
        html.div([attribute.class("validation-error")], [
          html.text(string.join(errors, ", ")),
        ])
    },
  ])
}

pub fn justtext(
  name: String,
  placeholder: String,
  value: String,
  errors: List(Errors),
  on_input: fn(String) -> msg,
) {
  html.div([attribute.class(error_class(name, errors))], [
    html.input([
      attribute.type_("text"),
      attribute.name(name),
      attribute.value(value),
      attribute.class("form-input"),
      attribute.placeholder(placeholder),
      event.on_input(on_input),
    ]),
    case validates.error_on(errors, name) {
      Error(Nil) -> html.div([], [html.text("")])
      Ok(errors) ->
        html.div([attribute.class("validation-error")], [
          html.text(string.join(errors, ", ")),
        ])
    },
  ])
}

pub fn password(
  name: String,
  label: String,
  value: String,
  errors: List(Errors),
  on_input: fn(String) -> msg,
) {
  html.div([attribute.class("form-group" <> error_class(name, errors))], [
    html.label([attribute.class("form-label")], [html.text(label)]),
    html.input([
      attribute.type_("password"),
      attribute.name(name),
      attribute.value(value),
      attribute.class("form-input"),
      event.on_input(on_input),
    ]),
    case validates.error_on(errors, name) {
      Error(Nil) -> html.div([], [html.text("")])
      Ok(errors) ->
        html.div([attribute.class("validation-error")], [
          html.text(string.join(errors, ", ")),
        ])
    },
  ])
}

pub fn textarea(
  name: String,
  label: String,
  value: String,
  errors: List(Errors),
  on_input: fn(String) -> msg,
) {
  html.div([attribute.class("form-group" <> error_class(name, errors))], [
    html.label([attribute.class("form-label")], [html.text(label)]),
    html.textarea(
      [
        attribute.type_("text"),
        attribute.name(name),
        attribute.class("form-input"),
        event.on_input(on_input),
      ],
      value,
    ),
    case validates.error_on(errors, name) {
      Error(Nil) -> html.div([], [html.text("")])
      Ok(errors) ->
        html.div([attribute.class("validation-error")], [
          html.text(string.join(errors, ", ")),
        ])
    },
  ])
}

pub fn checkbox(name: String, label: String, checked: Bool, on_check) {
  let attrs = [
    attribute.class("form-checkbox"),
    attribute.type_("checkbox"),
    attribute.name(name),
    event.on_check(on_check),
  ]

  let attrs = case checked {
    True -> [attribute.checked(True), ..attrs]
    False -> attrs
  }

  html.label([attribute.class("form-label")], [
    html.input(attrs),
    html.span([], [html.text(label)]),
  ])
}

pub fn select(
  name: String,
  label: String,
  value: String,
  options: List(#(String, String)),
  errors: List(Errors),
  on_change,
) {
  Group(..new_group(), name: name, label: label, errors: errors)
  |> group(html.select(
    [
      attribute.name(name),
      attribute.class("w-full form-input"),
      event.on_input(on_change),
    ],
    list.map(options, fn(option) {
      let attrs = [attribute.value(option.0)]
      let attrs = case option.0 == value {
        True -> [attribute.selected(True), ..attrs]
        False -> attrs
      }
      html.option(attrs, option.1)
    }),
  ))
}

pub fn int(
  name: String,
  label: String,
  value: Int,
  errors: List(Errors),
  on_input: fn(Int) -> msg,
) {
  html.div([attribute.class("form-group" <> error_class(name, errors))], [
    html.label([attribute.class("form-label")], [html.text(label)]),
    html.input([
      attribute.type_("number"),
      attribute.name(name),
      attribute.value(int.to_string(value)),
      attribute.class("form-input"),
      event.on_input(fn(input) {
        case int.parse(input) {
          Ok(value) -> value
          Error(_) -> value
        }
        |> on_input
      }),
    ]),
    case validates.error_on(errors, name) {
      Error(Nil) -> html.div([], [html.text("")])
      Ok(errors) ->
        html.div([attribute.class("validation-error")], [
          html.text(string.join(errors, ", ")),
        ])
    },
  ])
}

fn error_class(name, errors) {
  case has_errors(name, errors) {
    True -> " has-error"
    False -> ""
  }
}

fn has_errors(name, errors) {
  case validates.error_on(errors, name) {
    Ok(_) -> True
    Error(Nil) -> False
  }
}

pub fn state(state: State) {
  case state.status, state.missed, state.recovered, state.checking {
    _, _, _, True -> state_checking()
    status.Up, missed, _, False if missed > 0 -> state_missed(state.missed)
    status.Down, _, recovered, False if recovered > 0 ->
      state_recovering(state.recovered)
    status, _, _, False -> state_status(status)
  }
}

pub fn state_card(state: State) {
  case state.status, state.missed, state.recovered, state.checking {
    _, _, _, True -> state_card_checking()
    status.Up, missed, _, False if missed > 0 -> state_card_missed(state.missed)
    status.Down, _, recovered, False if recovered > 0 ->
      state_card_recovering(state.recovered)
    status, _, _, False -> state_card_status(status)
  }
}

const state_class = " text-center shadow rounded items-center text-xs px-2 py-0.5 inline-block text-base text-sm"

pub fn status_color(status: status.Status) {
  case status {
    status.Down -> "bg-red"
    status.New -> "bg-blue"
    status.Paused -> "bg-sapphire"
    status.Up -> "bg-teal"
  }
}

fn state_status(status: status.Status) {
  let color = status_color(status)

  html.div([attribute.class(color <> state_class)], [
    html.text(status.to_string(status)),
  ])
}

fn state_missed(missed: Int) {
  html.div([attribute.class("bg-peach" <> state_class)], [
    html.div([], [html.text("missed " <> int.to_string(missed))]),
  ])
}

fn state_recovering(missed: Int) {
  html.div([attribute.class("bg-mauve" <> state_class)], [
    html.div([], [html.text("recovering " <> int.to_string(missed))]),
  ])
}

fn state_checking() {
  html.div([attribute.class("bg-sapphire" <> state_class)], [
    html.div([attribute.class("flex space-x-2  items-center")], [
      spinner(),
      html.div([], [html.text("Checking...")]),
    ]),
  ])
}

fn state_card_checking() {
  div([class("bg-sapphire text-base status-card relative overflow-visible")], [
    div([class("text-base text-sm")], [html.text("Status:")]),
    div([class("mt-1 text-2xl font-bold")], [
      spinner_class("w-6 h-6 border-4 mr-2"),
      html.text("Checking..."),
    ]),
  ])
}

fn state_card_missed(missed: Int) {
  div([class("bg-peach text-base status-card relative overflow-visible")], [
    div([class("text-base text-sm")], [html.text("Status:")]),
    div([class("mt-1 text-2xl font-bold")], [
      icon("hero-warning-triangle w-6 h-6"),
      html.text("missed " <> int.to_string(missed)),
    ]),
  ])
}

fn state_card_recovering(missed: Int) {
  div([class("bg-mauve text-base status-card relative overflow-visible")], [
    div([class("text-base text-sm")], [html.text("Status:")]),
    div([class("mt-1 text-2xl font-bold")], [
      icon("hero-warning-triangle w-6 h-6"),
      html.text("recovering " <> int.to_string(missed)),
    ]),
  ])
}

fn state_card_status(status: status.Status) {
  let color = status_color(status)
  div([class(color <> " text-base status-card relative overflow-visible")], [
    div([class("text-base text-sm")], [html.text("Status:")]),
    div([class("mt-1 text-2xl font-bold")], [
      html.text(status.to_string(status)),
    ]),
  ])
}

pub fn icon(name: String) {
  html.span([attribute.class(name)], [])
}

pub fn spinner() {
  spinner_class("w-4 h-4 border-2")
}

pub fn spinner_class(clazz) {
  html.div(
    [
      attribute.class(
        "inline-block animate-spin rounded-full border-solid border-current border-e-transparent align-[-0.125em] text-surface motion-reduce:animate-[spin_1.5s_linear_infinite] "
        <> clazz,
      ),
    ],
    [
      html.span(
        [
          attribute.class(
            "!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip:rect(0,0,0,0)]",
          ),
        ],
        [],
      ),
    ],
  )
}

pub fn options_for_select(options: List(String), value: String) {
  list.map(options, fn(opt) {
    let attrs = [attribute.value(opt), attribute.selected(opt == value)]
    html.option(attrs, opt)
  })
}

pub fn pill(color, text) {
  pill2(color, [html.text(text)])
}

pub fn pill2(color, children) {
  let pill = "text-sm text-base px-2 py-0.5 rounded-md "
  html.span([attribute.class(pill <> color)], children)
}

pub fn tags(tags: String) {
  tagsl(tags.split(tags))
}

pub fn tagsl(tags: List(String)) {
  html.div(
    [attribute.class("inline-block space-x-1")],
    list.map(tags, fn(tag) { pill("bg-base text-subtext0", tag) }),
  )
}

pub fn alert(message: String) {
  html.div(
    [attribute.class("p-4 py-2 rounded bg-red flex space-x-4 items-center")],
    [
      icon("hero-exclamation-triangle w-8 h-8"),
      html.div([attribute.class("flex-1")], [html.text(message)]),
    ],
  )
}

pub fn null() {
  html.span([attribute.class("hidden")], [])
}

pub fn list(items: List(#(String, String))) {
  div(
    [],
    list.map(items, fn(tuple) {
      html.div([attribute.class("flex mb-1")], [
        html.div([attribute.class("font-bold w-32 text-sm")], [
          html.text(tuple.0),
        ]),
        html.div(
          [
            attribute.class(
              "text-subtext0 flex-1 font-mono whitespace-nowrap-line overflow-auto text-sm",
            ),
          ],
          [html.text(tuple.1)],
        ),
      ])
    }),
  )
}

pub fn card(attrs, children) {
  div([class("rounded-md bg-mantle p-4"), ..attrs], children)
}

pub fn class_list(classes: List(#(String, Bool))) {
  classes
  |> list.filter(fn(t) { t.1 })
  |> list.map(fn(t) { t.0 })
  |> string.join(" ")
  |> class()
}
