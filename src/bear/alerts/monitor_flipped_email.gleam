import bear/config
import bear/incidents/incident.{type Incident}
import bear/monitors/flip.{type Flip}
import bear/monitors/monitor.{type Monitor}
import bear/monitors/status
import gleam/int
import lib/email
import lustre/attribute
import lustre/element
import lustre/element/html

// TODO - default from alerts@monitorbear.com
pub fn email(monitor: Monitor, flip: Flip, incident: Result(Incident, Nil)) {
  email.new()
  |> email.from("ben@nerdyworm.com")
  |> email.subject(subject(monitor, flip))
  |> email.html_body(html_body(monitor, flip, incident))
  |> email.text_body(text_body(monitor, flip, incident))
}

fn subject(monitor: Monitor, flip: Flip) {
  monitor.name
  <> " "
  <> "flipped from "
  <> status.to_string(flip.from)
  <> " to "
  <> status.to_string(flip.to)
}

fn html_body(monitor: Monitor, flip: Flip, incident: Result(Incident, Nil)) {
  html.div([], [
    html.h1([], [html.text(subject(monitor, flip))]),
    html.a([attribute.href(url(monitor))], [html.text(monitor.name)]),
    case incident {
      Error(Nil) -> html.span([], [])
      Ok(incident) -> {
        html.p([], [
          html.a([attribute.href(incident_url(incident))], [
            html.text("Track the incident here"),
          ]),
        ])
      }
    },
  ])
  |> element.to_string()
}

fn text_body(monitor: Monitor, flip: Flip, incident: Result(Incident, Nil)) {
  subject(monitor, flip)
  <> "\n\n"
  <> url(monitor)
  <> "\n\n"
  <> case incident {
    Error(Nil) -> ""
    Ok(incident) -> incident_url(incident)
  }
}

fn url(monitor: Monitor) {
  config.endpoint() <> "/checks/" <> int.to_string(monitor.id)
}

fn incident_url(incident: Incident) {
  config.endpoint() <> "/incidents/" <> int.to_string(incident.id)
}
