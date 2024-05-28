import bear/mailer
import gleeunit/should
import lib/email

@target(erlang)
pub fn ses_test() {
  let email =
    email.new()
    |> email.from("ben@nerdyworm.com")
    |> email.to("benjamin.s.rhodes@gmail.com")
    |> email.subject("Yay testing")
    |> email.text_body("HEY!!!")
    |> email.html_body("<h1>HEY!!!</h1>")

  mailer.deliver(email)
  |> should.be_ok()
}
