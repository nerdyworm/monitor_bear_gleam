import { Ok, Error } from "@build/gleam_stdlib/gleam.mjs";

let app = null;

export function set(applicaiton) {
  app = applicaiton
  console.log('set', app)
}

export function get() {
  return app;
}

export function localstorage_get_item(key) {
  const value = window.localStorage.getItem(key);

  return value ? new Ok(value) : new Error(undefined);
}

export function localstorage_set_item(key, value) {
  window.localStorage.setItem(key, value);
}

export function localstorage_remove_item(key) {
  window.localStorage.removeItem(key);
}

class Socket {
  constructor(endpoint) {
    console.log({ endpoint })
    this.callback = null;
    this.endpoint = endpoint
  }

  disconnect() {
    this.socket.onclose = () => { };
    this.socket.close();
  }

  connect(token) {
    this.socket = new WebSocket(this.endpoint + "?token=" + token)
    this.socket.onmessage = this.callback;

    this.socket.onclose = () => {
      setTimeout(() => {
        this.connect(token);
      }, 1000);
    };

    this.socket.onopen = function() { };

    this.socket.onerror = function(error) {
      console.error(error);
    };
  }

  _callback(callback) {
    this.callback = function(event) {
      callback(event.data);
    };
  }
}

export function socket_new(endpoint) {
  return new Socket(endpoint);
}

export function socket_connect(socket, token) {
  socket.connect(token);
  return socket;
}
export function socket_disconnect(socket) {
  socket.disconnect();
  return socket;
}

export function socket_onmessage(socket, callback) {
  socket._callback(callback);
  return socket;
}

class PubSub {
  constructor() {
    this.subscribers = [];
  }

  subscribe(subscriber) {
    this.subscribers = [...this.subscribers, subscriber];
  }

  unsubscribe(subscriber) {
    this.subscribers = this.subscribers.filter((sub) => sub !== subscriber);
  }

  publish(payload) {
    this.subscribers.forEach((subscriber) => subscriber(payload));
  }
}

export function new_pubsub() {
  return new PubSub();
}

export function publish_pubsub(pubsub, subscriber) {
  pubsub.publish(subscriber);
}

export function subscribe_pubsub(pubsub, subscriber) {
  pubsub.subscribe(subscriber);
}

export function unsubscribe_pubsub(pubsub, subscriber) {
  pubsub.unsubscribe(subscriber);
}

export function now() {
  return new Date().getTime();
}

export function random(n) {
  return Math.floor(Math.random() * n);
}

export function set_timeout(callback, ms) {
  return setTimeout(callback, ms);
}

export function focus(selector) {
  setTimeout(() => {
    const element = document.querySelector(selector);
    if (element) {
      element.focus();
    }
  }, 0)
}

export function redirect(url) {
  window.location.href = url;
}

export function get_element_by_id(id) {
  const element = document.getElementById(id)
  if (element) {
    return new Ok(element)
  } else {
    return new Error(null)
  }
}

export function bounding_client_rect(element) {
  return element.getBoundingClientRect()
}
