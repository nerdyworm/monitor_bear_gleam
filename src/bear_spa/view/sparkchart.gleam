import gleam/float
import gleam/int
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/element/svg

pub fn line(runtimes: List(Int), width: Int, height: Int) {
  let w = int.to_float(width)
  let h = int.to_float(height + 10)
  let max =
    list.fold(runtimes, 0, fn(max, ms) { int.max(max, ms) })
    |> int.to_float()

  let lines =
    runtimes
    |> list.fold(#([], -10.0, -10.0, 0.0), fn(acc, ms) {
      let tooltip = int.to_string(ms) <> "ms"
      let #(elements, last_x, last_y, i) = acc

      let ms = int.to_float(ms)

      let x = i /. 9.0
      let x = x *. w

      let y = 1.0 -. ms /. max
      let y = y *. h

      let elements =
        list.append(elements, [
          svg.line([
            attribute.attribute("x1", float.to_string(last_x)),
            attribute.attribute("y1", float.to_string(last_y)),
            attribute.attribute("x2", float.to_string(x)),
            attribute.attribute("y2", float.to_string(y)),
            attribute.attribute("stroke", "black"),
            attribute.class("stroke-teal"),
          ]),
          element.namespaced(
            "http://www.w3.org/2000/svg",
            "circle",
            [
              attribute.attribute("cx", float.to_string(x)),
              attribute.attribute("cy", float.to_string(y)),
              attribute.attribute("r", "15"),
              attribute.attribute("fill", "transparent"),
            ],
            [svg.title([], [html.text(tooltip)])],
          ),
        ])

      #(elements, x, y, i +. 1.0)
    })

  html.div([attribute.class("")], [
    svg.svg(
      [
        attribute.class("bg-teal/5 rounded-md"),
        attribute.style([
          #("width", int.to_string(width) <> "px"),
          #("height", int.to_string(height) <> "px"),
        ]),
      ],
      lines.0,
    ),
  ])
}
