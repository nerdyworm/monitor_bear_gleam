import aws4_request
import gleam/bytes_builder
import gleam/erlang/os
import gleam/hackney
import gleam/http
import gleam/http/request
import gleam/io
import gleam/json
import lib/email.{type Email}

@target(erlang)
pub fn send_email(email: Email) {
  let assert Ok(access_key_id) = os.get_env("AWS_ACCESS_KEY")
  let assert Ok(secret_access_key) = os.get_env("AWS_SECRET_ACCESS_KEY")
  let assert Ok(region) = os.get_env("AWS_REGION")
  let date_time = localtime()
  let assert Ok(request) =
    request.to("https://email.us-east-1.amazonaws.com/v2/email/outbound-emails")

  let request =
    request.Request(
      ..request,
      headers: [
        #("host", "email.us-east-1.amazonaws.com"),
        #("content-type", "application/json; charset=utf-8"),
      ],
    )
  let payload =
    email
    |> email_to_json()
    |> json.to_string()

  let request =
    request
    |> request.set_method(http.Post)
    |> request.set_body(
      payload
      |> bytes_builder.from_string()
      |> bytes_builder.to_bit_array(),
    )

  let signed_request =
    aws4_request.sign(
      request,
      date_time,
      access_key_id,
      secret_access_key,
      region,
      "ses",
    )

  // TODO - handle Ok(Response(400-500, etc))
  signed_request
  |> request.set_body(payload)
  |> hackney.send()
  |> io.debug()
  // let assert Ok(message_id) = dynamic.field("MessageId", dynamic.string)(body)
  // io.debug(message_id)
}

fn email_to_json(email: Email) {
  let subject = #(
    "Subject",
    json.object([
      #("Data", json.string(email.subject)),
      #("Charset", json.string("UTF-8")),
    ]),
  )

  let body = #(
    "Body",
    json.object([
      #(
        "Text",
        json.object([
          #("Data", json.string(email.text_body)),
          #("Charset", json.string("UTF-8")),
        ]),
      ),
      #(
        "Html",
        json.object([
          #("Data", json.string(email.html_body)),
          #("Charset", json.string("UTF-8")),
        ]),
      ),
    ]),
  )

  json.object([
    #("FromEmailAddress", json.string(email.from)),
    #("Content", json.object([#("Simple", json.object([subject, body]))])),
    #(
      "Destination",
      json.object([#("ToAddresses", json.array(email.to, json.string))]),
    ),
  ])
}

@external(erlang, "calendar", "universal_time")
fn localtime() -> #(#(Int, Int, Int), #(Int, Int, Int)) {
  panic as "erlang only"
}
