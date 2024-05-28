import bear/scope.{type Scope}
import bear/teams/team
import bear_server/render
import wisp.{type Request, type Response}

pub fn show(scope: Scope, _req: Request) -> Response {
  scope.team
  |> team.to_json()
  |> render.json(200)
}
