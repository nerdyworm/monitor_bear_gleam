import gleam/int
import gleam/uri.{type Uri}
import lustre/browser

pub type Route {
  Public(Public)
  Private(Private)
}

pub type Public {
  Login
  Register
  ResetPassword(String)
  ResetPasswordCreate
}

pub type Private {
  Admin(Admin)
  Checks(Checks)
  Incidents(Incidents)
}

pub type Checks {
  ChecksEdit(Int)
  ChecksIndex
  ChecksNew
  ChecksShow(Int)
}

pub type Incidents {
  IncidentsIndex
  IncidentsShow(Int)
}

pub type Admin {
  AdminDashboard
  AlertsIndex
  AlertsNew
  AlertsEdit(Int)
  MembershipsIndex
  PlanIndex
}

pub fn uri_to_route(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    ["login"] -> Public(Login)
    ["register"] -> Public(Register)
    ["users", "reset_password", token] -> Public(ResetPassword(token))
    ["users", "reset_password"] -> Public(ResetPasswordCreate)
    ["checks", "new"] -> Private(Checks(ChecksNew))
    ["checks", id, "edit"] -> Private(Checks(ChecksEdit(stoi(id))))
    ["checks", id] -> Private(Checks(ChecksShow(stoi(id))))
    ["checks"] -> Private(Checks(ChecksIndex))
    ["incidents"] -> Private(Incidents(IncidentsIndex))
    ["incidents", id] -> Private(Incidents(IncidentsShow(stoi(id))))

    // ["heartbeats", "new"] -> Private(HeartbeatsNew)
    // ["heartbeats", id, "edit"] -> Private(HeartbeatsEdit(stoi(id)))
    // ["heartbeats", id] -> Private(HeartbeatsShow(stoi(id)))
    // ["heartbeats"] -> Private(HeartbeatsIndex)
    // admin routes
    ["admin"] -> Private(Admin(AdminDashboard))
    ["admin", "alerts"] -> Private(Admin(AlertsIndex))
    ["admin", "alerts", "new"] -> Private(Admin(AlertsNew))
    ["admin", "alerts", id, "edit"] -> Private(Admin(AlertsEdit(stoi(id))))
    ["admin", "memberships"] -> Private(Admin(MembershipsIndex))
    ["admin", "plans"] -> Private(Admin(PlanIndex))
    _ -> Private(Checks(ChecksIndex))
  }
}

fn stoi(i: String) -> Int {
  case int.parse(i) {
    Ok(i) -> i
    Error(Nil) -> 0
  }
}

pub fn push(url: String) {
  let assert Ok(uri) = uri.parse(url)
  browser.push(uri)
}

@external(javascript, "../bear_spa.ffi.mjs", "redirect")
pub fn redirect(url: String) -> Nil {
  let _ = url
  Nil
}
