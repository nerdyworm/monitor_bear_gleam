-module(bear_ffi).
-export([test/0, default_pool/0, broadcast/2, subscribe/1, now/0, random/1, start_default_pool/1,
         set_config/1,get_config/0
        ]).

-include_lib("gleam_pgo/include/gleam@pgo_Config.hrl").

test() ->
    io:format("testing~n"),
    pgo:query("select 1").

default_pool() ->
    {pgo_pool, default, null}.

broadcast(Topic, Msg) ->
    Members = pg:get_members(Topic),
    lists:foreach(
        fun(Member) ->
            Member ! Msg
        end,
        Members
    ).

subscribe(Topic) ->
    pg:join(Topic, self()).

set_config(Config) ->
  ok = application:set_env(bear, config, Config),
  {ok, nil}.

get_config() ->
  application:get_env(bear, config).


now() ->
    os:system_time(millisecond).

random(N) ->
    rand:uniform(N).

start_default_pool(Config) ->
    #config{
        host = Host,
        port = Port,
        database = Database,
        user = User,
        password = Password,
        ssl = Ssl,
        connection_parameters = ConnectionParameters,
        pool_size = PoolSize,
        queue_target = QueueTarget,
        queue_interval = QueueInterval,
        idle_interval = IdleInterval,
        trace = Trace,
        ip_version = IpVersion
    } = Config,
    Options1 = #{
        host => Host,
        port => Port,
        database => Database,
        user => User,
        ssl => Ssl,
        connection_parameters => ConnectionParameters,
        pool_size => PoolSize,
        queue_target => QueueTarget,
        queue_interval => QueueInterval,
        idle_interval => IdleInterval,
        trace => Trace,
        socket_options =>
            case IpVersion of
                ipv4 -> [];
                ipv6 -> [inet6]
            end
    },
    Options2 =
        case Password of
            {some, Pw} -> maps:put(password, Pw, Options1);
            none -> Options1
        end,

    pgo_pool:start_link(default, Options2).
