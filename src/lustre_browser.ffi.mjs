import { Some, None } from "@build/gleam_stdlib/gleam/option.mjs";
import { Uri, to_string } from "@build/gleam_stdlib/gleam/uri.mjs";

export function current_uri() {
  const url = new URL(window.location.href);
  return uri_from_url(url);
}

let _title = document.title

export function set_title(title) {
  if (_title != title) {
    document.title = title;
    _title = title;
  }
}

export function push(uri) {
  window.history.pushState({}, "", to_string(uri));

  const pushChangeEvent = new CustomEvent("onpushstate", {
    detail: {
      uri
    }
  });

  window.dispatchEvent(pushChangeEvent);
}

export function attach_listeners(dispatch, on_url_request, on_url_change) {
  document.body.addEventListener("click", (event) => {
    if (event.shiftKey || event.ctrlKey || event.metaKey) {
      return;
    }

    const a = maybe_anchor(event.target);

    if (!a) return;


    event.preventDefault();

    const url = new URL(a.href)
    const uri = uri_from_url(url)

    dispatch(on_url_request(uri))
    window.history.pushState({}, "", a.href);
    dispatch(on_url_change(uri))
  })

  window.addEventListener("popstate", (event) => {
    event.preventDefault();
    const url = new URL(window.location.href);
    const uri = uri_from_url(url);
    dispatch(on_url_change(uri))
  });


  window.addEventListener("onpushstate", (event) => {
    dispatch(on_url_change(event.detail.uri))
  });
}


function uri_from_url(url) {
  return new Uri(
    new (url.protocol ? Some : None)(url.protocol),
    new None(),
    new (url.hostname ? Some : None)(url.hostname),
    new (url.port ? Some : None)(url.port),
    url.pathname,
    new (url.search ? Some : None)(url.search),
    new (url.hash ? Some : None)(url.hash.slice(1)),
  );
};


function maybe_anchor(element) {
  if (!element) {
    return null;
  }

  if (element.tagName === "BODY") {
    return null;
  } else if (element.tagName === "A") {
    return element;
  } else {
    return maybe_anchor(element.parentElement);
  }
};
