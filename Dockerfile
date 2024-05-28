FROM ghcr.io/gleam-lang/gleam:v1.2.0-erlang-alpine

RUN apk add elixir make nodejs npm build-base bsd-compat-headers linux-headers
RUN mix local.hex --force

COPY ./src/ /build/src
COPY ./priv/ /build/priv
COPY ./pages/ /build/pages
COPY ./forks/ /build/forks
COPY ./gleam.toml /build
COPY ./manifest.toml /build
COPY ./package.json /build
COPY ./package-lock.json /build
COPY ./tailwind.config.js /build
COPY ./vite.config.js /build
COPY ./postcss.config.js /build
COPY ./index.html /build


RUN cd /build && npm install
RUN cd /build && npm run build
RUN cd /build && gleam export erlang-shipment && mv build/erlang-shipment /app
RUN rm -r /build

RUN ls -ltra /app

WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run", "server"]
