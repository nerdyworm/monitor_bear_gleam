import bear/pubsub_message
import bear_spa/app
import bear_spa/lib/pubsub
import bear_spa/lib/socket
import bear_spa/root
import gleam/io
import gleam/json
import lustre
import lustre/browser

pub fn main(endpoint: String, endpoint_socket: String) {
  let app = app.new(endpoint, endpoint_socket)

  let assert Ok(dispatch) =
    browser.application(
      app,
      root.init,
      root.document,
      root.update,
      root.subscriptions,
      root.on_url_request,
      root.on_url_change,
    )

  let socket =
    socket.new(app.endpoint_socket)
    |> socket.onmessage(fn(msg) {
      case json.decode(msg, pubsub_message.decoder) {
        Ok(message) -> {
          dispatch(lustre.dispatch(root.OnPubsubMessage(message)))
          pubsub.publish(app.pubsub2, message)
        }

        Error(error) -> {
          io.debug(#("error decoding message", error, msg))
          Nil
        }
      }
    })

  pubsub.subscribe(app.pubsub, fn(event) {
    case event {
      app.SessionStarted(session) -> {
        socket.connect(socket, session.token)
        Nil
      }

      app.SessionInvalid -> {
        socket.disconnect(socket)
        Nil
      }

      _ -> Nil
    }
  })
}
