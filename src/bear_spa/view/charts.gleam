import bear/monitors/metric.{type Metric, Metric}
import birl
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set
import gleam/string
import lustre/attribute.{class}
import lustre/element/html.{div, span, text}
import lustre/element/svg

pub type Data {
  Data(timestamp: Int, value: Int, color: String)
}

pub type Series {
  Series(name: String, color: String, data: List(Data))
}

pub type Model {
  Model(
    series: List(Series),
    width: Int,
    height: Int,
    mouse: Option(#(Int, Int)),
    xaxis: List(String),
    yaxis: List(Int),
    padding: Int,
    max: Int,
    min: Int,
    times: List(Int),
    min_time: Int,
    max_time: Int,
    cache: List(#(String, String)),
  )
}

pub fn new() {
  Model(
    series: [],
    width: 500,
    height: 500,
    mouse: None,
    xaxis: [],
    yaxis: [],
    padding: 0,
    min: 0,
    max: 0,
    times: [],
    min_time: 0,
    max_time: 0,
    cache: [],
  )
}

// need to rerender things...
pub fn set_width(model: Model, width: Int) {
  Model(..model, width: width)
  |> cache_paths()
}

pub fn build(model: Model, metrics: List(Metric)) {
  let timestamps =
    list.fold(metrics, set.new(), fn(acc, metric) { set.insert(acc, metric.t) })
    |> set.to_list()
    |> list.sort(string.compare)

  let times =
    list.map(timestamps, fn(timestamp) {
      let assert Ok(time) = birl.parse(timestamp)
      birl.to_unix(time)
    })

  let series =
    list.fold(metrics, dict.new(), fn(acc, metric) {
      dict.update(acc, metric.name, fn(values) {
        case values {
          None -> #(metric.name, [metric])
          Some(#(name, data)) -> #(name, [metric, ..data])
        }
      })
    })

  let series = dict.values(series)

  let metrics = Model(..model, series: [], times: times)

  list.fold(series, metrics, fn(acc, series) {
    add_metrics(acc, series.0, series.1)
  })
  |> cache_paths()
}

fn cache_paths(model: Model) {
  Model(
    ..model,
    cache: list.map(model.series, fn(series) {
      #(series.color, build_path(series, model))
    }),
  )
}

pub type Msg {
  OnHover
}

fn max(series: List(Series)) -> Int {
  list.fold(series, 0, fn(max, series) {
    list.fold(series.data, max, fn(max, ms) { int.max(max, ms.value) })
  })
}

fn min(series: List(Series)) -> Int {
  list.fold(series, 9999, fn(max, series) {
    list.fold(series.data, max, fn(max, ms) { int.min(max, ms.value) })
  })
}

pub fn add_metrics(model: Model, name: String, data: List(Metric)) {
  let color = case name {
    "healthcheck:india" -> "stroke-peach fill-peach bg-peach"
    "healthcheck:austrailia" -> "stroke-mauve fill-mauve bg-mauve"
    "healthcheck:europe" -> "stroke-sky fill-sky bg-sky"
    "healthcheck:japan" -> "stroke-pink fill-pink bg-pink"
    "healthcheck:us-east" -> "stroke-sapphire fill-sapphire bg-sapphire"
    _ -> "stroke-lavender fill-lavender bg-lavender"
  }

  let data =
    list.map(data, fn(metric: Metric) {
      let assert Ok(time) = birl.parse(metric.t)
      Data(birl.to_unix(time), metric.value, color)
    })

  let model =
    Model(
      ..model,
      series: [Series(name: name, color: color, data: data), ..model.series],
    )

  let max_time = max_time(model.series)

  Model(
    ..model,
    max: max(model.series),
    min: min(model.series),
    min_time: min_time(model.series, max_time),
    max_time: max_time,
  )
}

fn min_time(series: List(Series), max_time) {
  list.fold(series, max_time, fn(max, series) {
    list.fold(series.data, max, fn(max, ms) { int.min(max, ms.timestamp) })
  })
}

fn max_time(series: List(Series)) {
  list.fold(series, 0, fn(max, series) {
    list.fold(series.data, max, fn(max, ms) { int.max(max, ms.timestamp) })
  })
}

fn build_path(series: Series, model: Model) {
  list.fold(series.data, #("M", -1, -1), fn(acc, m: Data) {
    let x = timestamp_to_x(m.timestamp, model)
    let y = value_to_y(m.value, model)

    let #(builder, last_x, last_y) = acc

    case last_x, last_y {
      -1, -1 -> #(
        builder <> " " <> int.to_string(x) <> " " <> int.to_string(y),
        x,
        y,
      )

      _, _ -> #(
        builder <> " L" <> int.to_string(x) <> " " <> int.to_string(y),
        x,
        y,
      )
    }
  }).0
}

fn build_path_element(data: #(String, String)) {
  svg.path([
    attribute.attribute("d", data.1),
    attribute.class(string.replace(data.0, "fill-", "nofill-")),
    attribute.attribute("fill", "transparent"),
  ])
}

fn timestamp_to_x(timestamp: Int, model: Model) {
  let scale_min = model.padding
  let scale_max = model.width - model.padding

  scale_min
  + { timestamp - model.min_time }
  * { scale_max - scale_min }
  / { model.max_time - model.min_time }
}

fn value_to_y(value: Int, model: Model) {
  let scale_min = model.padding
  let scale_max = model.height - model.padding

  scale_max
  - { value - model.min }
  * { scale_max - scale_min }
  / { model.max - model.min }
}

pub fn line(model: Model) {
  let #(label, values) = guide_labels(model)

  html.div([attribute.class("")], [
    svg.svg(
      [
        attribute.class(""),
        attribute.style([
          #("width", int.to_string(model.width) <> "px"),
          #("height", int.to_string(model.height) <> "px"),
        ]),
      ],
      [
        svg.g([], list.map(model.cache, build_path_element)),
        guide_line(model),
        guide_circles(values, model),
      ],
    ),
    legend(label, values, model),
  ])
}

fn guide_labels(model: Model) {
  case model.mouse {
    None -> #(" - ", [])
    Some(#(x, _)) -> {
      let timestamp = nearest_timestamp(x, model)

      let label = birl.from_unix(timestamp) |> birl.to_iso8601()

      let values =
        list.map(model.series, fn(series) {
          let value =
            list.find(series.data, fn(data) { data.timestamp == timestamp })

          #(series.name, value)
        })

      #(label, values)
    }
  }
}

fn guide_line(model: Model) {
  case model.mouse {
    None -> svg.line([])
    Some(#(x, _)) -> {
      svg.g([], [
        svg.line([
          attribute.attribute("x1", int.to_string(x)),
          attribute.attribute("y1", int.to_string(0)),
          attribute.attribute("x2", int.to_string(x)),
          attribute.attribute("y2", int.to_string(model.height)),
          attribute.class("stroke-subtext0/10"),
        ]),
      ])
    }
  }
}

fn guide_circles(values: List(#(String, Result(Data, Nil))), model: Model) {
  svg.g(
    [],
    list.map(values, fn(thing) {
      case thing {
        #(_, Ok(m)) -> {
          let x = timestamp_to_x(m.timestamp, model)
          let y = value_to_y(m.value, model)
          svg.circle([
            attribute.attribute("cx", int.to_string(x)),
            attribute.attribute("cy", int.to_string(y)),
            attribute.attribute("r", "4"),
            attribute.attribute("class", m.color <> " stroke-crust stroke-1"),
          ])
        }

        _ -> svg.g([], [])
      }
    }),
  )
}

fn legend(label, values: List(#(String, Result(Data, Nil))), model: Model) {
  div([class("grid grid-cols-3 text-xs mt-2")], [
    div([class("flex items-center space-x-1")], [
      span([class("font-bold")], [text("Time: ")]),
      span([class("text-normal")], [text(label)]),
    ]),
    ..list.map(model.series, fn(series) {
      let value = case list.find(values, fn(t) { t.0 == series.name }) {
        Ok(#(_, Ok(value))) -> int.to_string(value.value) <> "ms"
        _ -> " - "
      }

      div([class("flex items-center space-x-1")], [
        div([class("w-2 h-2 mr-1 rounded-full " <> series.color)], []),
        span([class("font-bold")], [
          text(string.replace(series.name, "healthcheck:", "") <> ": "),
        ]),
        span([class("text-normal")], [text(value)]),
      ])
    })
  ])
}

fn nearest_timestamp(mouse_x: Int, model: Model) {
  list.fold_until(model.times, #(0, 0), fn(acc, timestamp) {
    let #(last_x, _) = acc
    case timestamp_to_x(timestamp, model) {
      xx if xx > last_x && xx > mouse_x -> {
        list.Stop(#(xx, timestamp))
      }

      xx -> {
        list.Continue(#(xx, timestamp))
      }
    }
  }).1
}
