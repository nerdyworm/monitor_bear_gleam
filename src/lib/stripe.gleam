import bear/config
import bear/teams
import bear/teams/team.{type Team}
import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/hackney
import gleam/http.{Post}
import gleam/http/request
import gleam/int
import gleam/json
import gleam/string

@target(erlang)
pub fn create_checkout_session(team: Team, name: String) {
  let assert Ok(config) = config.get()

  let price = case name {
    "business" -> "price_1PEN7OCzwvP83LGaiE0n36Tv"
    "startup" -> "price_1PEN6tCzwvP83LGaOYQ2qInZ"
    // indie/default
    _ -> "price_1PEN6GCzwvP83LGaOHqAc6lL"
  }

  let assert Ok(request) =
    request.to("https://api.stripe.com/v1/checkout/sessions")

  let url = config.endpoint <> "/admin/plans"

  let assert Ok(response) =
    request
    |> request.set_header("Content-Type", "application/x-www-form-urlencoded")
    |> request.set_header("Authorization", "Bearer " <> config.stripe_key)
    |> request.set_method(Post)
    |> request.set_body(
      "cancel_url="
      <> url
      <> "&success_url="
      <> url
      <> "&line_items[0][price]="
      <> price
      <> "&line_items[0][quantity]=1"
      <> "&mode=subscription"
      <> "&subscription_data[metadata][team_id]="
      <> int.to_string(team.id)
      <> "&subscription_data[metadata][plan]="
      <> name,
    )
    |> hackney.send()

  let assert Ok(data) = json.decode(response.body, dynamic.dynamic)

  let assert Ok(url) = dynamic.field("url", dynamic.string)(data)
  Ok(url)
}

@target(erlang)
pub fn handle_webhook(data: String, signature: String) {
  let assert Ok(True) = verify_signature(signature, data)
  let assert Ok(params) = json.decode(data, dynamic.dynamic)
  let assert Ok(kind) = dynamic.field("type", dynamic.string)(params)

  case kind {
    "customer.subscription.created" | "customer.subscription.upated" -> {
      let assert Ok(data) = dynamic.field("data", dynamic.dynamic)(params)
      let assert Ok(object) = dynamic.field("object", dynamic.dynamic)(data)
      // let assert Ok(plan) = dynamic.field("plan", dynamic.dynamic)(object)
      // let assert Ok(plan_id) = dynamic.field("id", dynamic.string)(plan)
      let assert Ok(metadata) =
        dynamic.field("metadata", dynamic.dynamic)(object)
      let assert Ok(team_id) =
        dynamic.field("team_id", dynamic.string)(metadata)
      let assert Ok(plan) = dynamic.field("plan", dynamic.string)(metadata)
      let assert Ok(_) = teams.update_plan(team_id, plan)
      Nil
    }
    _ -> Nil
  }

  Ok(Nil)
}

@target(erlang)
pub fn verify_signature(header: String, payload: String) {
  let assert [timestamp, signature, ..] = string.split(header, ",")
  let timestamp = string.replace(timestamp, "t=", "")
  let signature = string.replace(signature, "v1=", "")
  let data = timestamp <> "." <> payload

  let assert Ok(config) = config.get()
  let key = bit_array.from_string(config.stripe_webhook_signing_key)
  let data = bit_array.from_string(data)

  let result =
    crypto.hmac(data, crypto.Sha256, key)
    |> bit_array.base16_encode()
    |> string.lowercase()

  Ok(signature == result)
}
