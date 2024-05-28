import bear/config
import bear/incidents/incident.{type Incident}
import bear/monitors/monitor.{type Monitor}
import bear/monitors/state.{type State}
import bear/monitors/status
import gleam/int
import lib/email
import lustre/attribute
import lustre/element
import lustre/element/html

// TODO - default from alerts@monitorbear.com
pub fn email(monitor: Monitor, state: State, incident: Result(Incident, Nil)) {
  email.new()
  |> email.from("ben@nerdyworm.com")
  |> email.subject(subject(monitor, state))
  |> email.html_body(html_body(monitor, state, incident))
  |> email.text_body(text_body(monitor, state, incident))
}

fn subject(monitor: Monitor, state: State) {
  monitor.name <> " " <> "has been " <> status.to_string(state.status)
}

fn html_body(monitor: Monitor, state: State, incident: Result(Incident, Nil)) {
  html.div([], [
    html.h1([], [html.text(subject(monitor, state))]),
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

fn text_body(monitor: Monitor, state: State, incident: Result(Incident, Nil)) {
  subject(monitor, state)
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
