import bear/teams/team.{type Team}
import bear/users/user.{type User}

pub type Scope {
  Scope(user: User, team: Team)
}

pub fn new(user: User, team: Team) -> Scope {
  Scope(user: user, team: team)
}
