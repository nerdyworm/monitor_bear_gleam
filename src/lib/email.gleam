import gleam/list

pub type Email {
  Email(
    subject: String,
    text_body: String,
    html_body: String,
    to: List(String),
    from: String,
  )
}

pub fn new() {
  Email(subject: "", text_body: "", html_body: "", to: [], from: "")
}

pub fn to(email: Email, address: String) {
  Email(..email, to: list.append(email.to, [address]))
}

pub fn from(email: Email, address: String) {
  Email(..email, from: address)
}

pub fn subject(email: Email, subject: String) {
  Email(..email, subject: subject)
}

pub fn text_body(email: Email, text: String) {
  Email(..email, text_body: text)
}

pub fn html_body(email: Email, html: String) {
  Email(..email, html_body: html)
}
