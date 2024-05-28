import gleam/erlang/os
import gleam/http/response
import lib/aws/ses
import lib/email.{type Email}

@target(erlang)
pub fn deliver(email: Email) {
  case os.get_env("DELIVER_EMAIL") {
    Ok("1") -> {
      case ses.send_email(email) {
        Ok(result) -> {
          Ok(result)
        }

        Error(error) -> {
          Error(error)
        }
      }
    }

    _ -> {
      Ok(response.new(200))
    }
  }
}

@target(javascript)
pub fn deliver(email: Email) {
  panic as "erlang only"
}
