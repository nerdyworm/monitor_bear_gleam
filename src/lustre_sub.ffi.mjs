let things = {};

export function add_teardown(a, b) {
  things[a] = b;
}

export function call_teardown(a) {
  const fn = things[a];
  if (fn) {
    delete things[a];
    fn();
  }
}

export function ticker(callback, every) {
  return setInterval(callback, every)
}

export function stop_ticker(ticker) {
  clearInterval(ticker);
}

export function document_add_event_listener(name, callback) {
  // using setTimeout here because if the subscription is started as the result of
  // a click then this will fire immediately.
  setTimeout(() => {
    document.addEventListener(name, callback)
  }, 0)
}

export function document_remove_event_listener(name, callback) {
  document.removeEventListener(name, callback)
}

export function window_add_event_listener(name, callback) {
  // using setTimeout here because if the subscription is started as the result of
  // a click then this will fire immediately.
  setTimeout(() => {
    window.addEventListener(name, callback)
  }, 0)
}

export function window_remove_event_listener(name, callback) {
  window.removeEventListener(name, callback)
}

export function within(element, selector) {
  const elements = document.querySelectorAll(selector)
  for (let i = 0; i < elements.length; i++) {
    if (elements[i].contains(element)) {
      return true
    }
  }

  return false;
}

export function update_application(application, initMapper, updateMapper, viewMapper) {
  return application.withFields({
    update: updateMapper(application.update),
    init: initMapper(application.init),
    view: viewMapper(application.view),
  })
}

export function window_size() {
  return { height: window.innerHeight, width: window.innerWidth }
}
