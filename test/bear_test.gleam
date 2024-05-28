import bear/config
import gleeunit

@target(erlang)
pub fn main() {
  let assert Ok(Nil) = config.set(config.empty())
  gleeunit.main()
}
