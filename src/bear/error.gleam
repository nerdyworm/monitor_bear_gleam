import gleam/pgo
import validates

pub type BearError {
  ErrorMessage(message: String)
  DatabaseError(pgo.QueryError)
  DatabaseNone
  Validation(List(validates.Errors))
}
