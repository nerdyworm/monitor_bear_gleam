pub type Config {
  Config(
    priv: String,
    port: Int,
    endpoint: String,
    internal_api_key: String,
    stripe_key: String,
    stripe_webhook_signing_key: String,
  )
}

pub fn empty() {
  Config(
    priv: "",
    port: 0,
    endpoint: "",
    internal_api_key: "",
    stripe_key: "",
    stripe_webhook_signing_key: "",
  )
}

@external(erlang, "bear_ffi", "set_config")
pub fn set(config: Config) -> Result(Nil, Nil) {
  let _ = config
  Ok(Nil)
}

@external(erlang, "bear_ffi", "get_config")
pub fn get() -> Result(Config, Nil) {
  Error(Nil)
}

pub fn endpoint() -> String {
  let assert Ok(config) = get()
  config.endpoint
}

pub fn priv() -> String {
  let assert Ok(config) = get()
  config.priv
}

pub fn system_email() -> String {
  "system@monitorbear.com"
}

pub fn internal_api_key() -> String {
  let assert Ok(config) = get()
  config.internal_api_key
}
