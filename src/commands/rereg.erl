%%%-------------------------------------------------------------------
%%% @author Shuieryin
%%% @copyright (C) 2015, Shuieryin
%%% @doc
%%%
%%% Re-register player module.
%%%
%%% @end
%%% Created : 01. Sep 2015 11:28 PM
%%%-------------------------------------------------------------------
-module(rereg).
-author("Shuieryin").

%% API
-export([exec/2]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Re-register player. The existing player profile will not be removed
%% until the registration is done.
%%
%% This function returns "ok" immeidately and the scene info will
%% be responsed to user from player_fsm by sending responses to
%% DispatcherPid process.
%%
%% @end
%%--------------------------------------------------------------------
-spec exec(DispatcherPid, Uid) -> ok when
    Uid :: player_fsm:uid(),
    DispatcherPid :: pid().
exec(DispatcherPid, Uid) ->
    case whereis(Uid) of
        undefined ->
            login_server:register_uid(DispatcherPid, Uid);
        _Pid ->
            player_fsm:response_content(Uid, [{nls, please_logout_first}], DispatcherPid)
    end.

%%%===================================================================
%%% Internal functions (N/A)
%%%===================================================================