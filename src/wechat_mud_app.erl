-module(wechat_mud_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    ok = start_web(),
    {ok, _} = wechat_mud_sup:start_link().

stop(_State) ->
    ok.

%%--------------------------------------------------------------------
%% @doc
%% Launch web service
%%
%% @end
%%--------------------------------------------------------------------
start_web() ->
    io:format("a web test....~n"),
    Port = 13579,
    io:format("Load the page http://localhost:~p/ in your browser~n", [Port]),
    web_server_start:start_link(Port).