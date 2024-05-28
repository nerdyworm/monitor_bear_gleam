-module(fox_ffi).
-export([now/0, random/1]).

now() ->
    os:system_time(millisecond).

random(N) ->
    rand:uniform(N).
