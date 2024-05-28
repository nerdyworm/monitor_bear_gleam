import bear/monitors/monitor.{type Monitor}
import bear/monitors/state.{type State}
import gleam/dict.{type Dict}
import gleam/list

pub type Store {
  Store(monitors: Dict(Int, Monitor), states: Dict(Int, State))
}

pub fn new() {
  Store(monitors: dict.new(), states: dict.new())
}

pub fn monitors(store: Store, monitors: List(Monitor)) -> Store {
  let monitors =
    list.fold(monitors, store.monitors, fn(acc, monitor) {
      dict.insert(acc, monitor.id, monitor)
    })

  Store(..store, monitors: monitors)
}

pub fn states(store: Store, states: List(State)) -> Store {
  let states =
    list.fold(states, store.states, fn(acc, monitor) {
      dict.insert(acc, monitor.id, monitor)
    })

  Store(..store, states: states)
}

pub fn state(store: Store, state: State) -> Store {
  Store(..store, states: dict.insert(store.states, state.id, state))
}

pub fn delete_monitor(store: Store, id: Int) {
  let monitors = dict.delete(store.monitors, id)
  let states = dict.delete(store.states, id)
  Store(monitors: monitors, states: states)
}
