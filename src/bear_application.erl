-module(bear_application).
-behavior(application).
-export([start/2, stop/1]).

start(_Type, Args) ->
    supervisor:start_link({local, bear_supervisor}, bear_supervisor, Args).

stop(_State) ->
    [].
