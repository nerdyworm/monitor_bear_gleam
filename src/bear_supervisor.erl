-module(bear_supervisor).
-behavior(supervisor).
-export([init/1]).

init(_Args) ->
    SupFlags = #{},
    DefaultChildren = [#{id => pubsub, start => {pg, start_link, []}}],
    ChildSpecs = maybe_start_database(DefaultChildren),
    {ok, {SupFlags, ChildSpecs}}.

maybe_start_database(Children) ->
    case database_connection_info() of
        {error, _} ->
            Children;
        {ok, C} ->
            Config =
                #{
                    pool_size => 15,
                    queue_target => 50,
                    queue_interval => 1000,
                    idle_interval => 1000,
                    trace => false,
                    ssl => false,
                    host => maps:get(host, C),
                    database => maps:get(database, C),
                    user => maps:get(user, C),
                    password => maps:get(password, C)
                },
            [
                #{
                    id => pgo_pool,
                    start => {pgo_pool, start_link, [default, Config]},
                    shutdown => 1000
                }
                | Children
            ]
    end.

database_connection_info() ->
    case os:getenv("DATABASE_URL") of
        false ->
            {error, "DATABASE_URL Environment variable not found"};
        EnvVar ->
            case uri_string:parse(EnvVar) of
                {error, Reason} ->
                    {error, Reason};
                Uri ->
                    UserInfo = maps:get(userinfo, Uri),
                    [Username, Password] = string:split(UserInfo, ":", all),

                    Path = maps:get(path, Uri),
                    [_, Database] = string:split(Path, "/", all),

                    {ok,
                        maps:merge(Uri, #{
                            user => Username, password => Password, database => Database
                        })}
            end
    end.
