import gleam/json
import gleeunit/should
import validates.{type Errors, Errors}

pub fn validates_empty_string_test() {
  validates.string("name", "")
  |> validates.required()
  |> validates.errors()
  |> should.equal(["can't be blank"])
}

pub fn validates_string_test() {
  validates.string("name", "be")
  |> validates.required()
  |> validates.errors()
  |> should.equal([])
}

pub fn validates_empty_int_test() {
  validates.int("age", 0)
  |> validates.required()
  |> validates.errors()
  |> should.equal(["can't be zero"])
}

pub fn validates_int_test() {
  validates.int("age", 69)
  |> validates.required()
  |> validates.errors()
  |> should.equal([])
}

pub fn validates_not_in_test() {
  validates.string("option", "option 1")
  |> validates.required()
  |> validates.in(["option a", "option b"])
  |> validates.errors()
  |> should.equal(["is not an option"])
}

pub fn validates_in_test() {
  validates.string("option", "option b")
  |> validates.required()
  |> validates.in(["option a", "option b"])
  |> validates.errors()
  |> should.equal([])
}

pub fn validates_rules_test() {
  validates.rules()
  |> validates.add(
    validates.string("name", "")
    |> validates.required(),
  )
  |> validates.add(
    validates.int("age", 0)
    |> validates.required()
    |> validates.range(10, 20),
  )
  |> validates.validate()
  |> should.equal([
    Errors("name", ["can't be blank"]),
    Errors("age", ["not in valid range (10, 20)", "can't be zero"]),
  ])
}

pub fn validates_result_test() {
  validates.rules()
  |> validates.add(
    validates.string("name", "")
    |> validates.required(),
  )
  |> validates.result("some value")
  |> should.be_error()
  |> should.equal([Errors("name", ["can't be blank"])])
}

pub fn validates_to_json_test() {
  validates.rules()
  |> validates.add(
    validates.string("name", "")
    |> validates.required(),
  )
  |> validates.validate()
  |> validates.to_json()
  |> json.to_string()
  |> should.equal("[{\"name\":\"name\",\"errors\":[\"can't be blank\"]}]")
}
