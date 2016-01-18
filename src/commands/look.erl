%%%-------------------------------------------------------------------
%%% @author shuieryin
%%% @copyright (C) 2015, Shuieryin
%%% @doc
%%%
%%% Look module. This module returns the current scene content to
%%% player when no arugments provided, or returns specific character
%%% or object vice versa.
%%%
%%% @end
%%% Created : 20. Sep 2015 8:19 PM
%%%-------------------------------------------------------------------
-module(look).
-author("shuieryin").

%% API
-export([
    exec/2,
    exec/3
]).

-type sequence() :: pos_integer(). % generic integer
-type target() :: atom(). % generic atom

-include("../data_type/scene_info.hrl").

-export_type([sequence/0,
    target/0]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Returns the current scene content when no arguments provided.
%%
%% @end
%%--------------------------------------------------------------------
-spec exec(DispatcherPid, Uid) -> ok when
    Uid :: player_fsm:uid(),
    DispatcherPid :: pid().
exec(DispatcherPid, Uid) ->
    player_fsm:look_scene(DispatcherPid, Uid).

%%--------------------------------------------------------------------
%% @doc
%% Show the first matched target scene object description.
%%
%% @end
%%--------------------------------------------------------------------
-spec exec(DispatcherPid, Uid, TargetArgs) -> ok when
    Uid :: player_fsm:uid(),
    DispatcherPid :: pid(),
    TargetArgs :: binary().
exec(DispatcherPid, Uid, TargetArgs) ->
    {ok, TargetId, Sequence} = cm:parse_target_id(TargetArgs),
    TargetContent = #target_content{
        actions = [under_look, looked],
        dispatcher_pid = DispatcherPid,
        target = TargetId,
        sequence = Sequence,
        target_bin = TargetArgs,
        self_targeted_message = [{nls, look_self}, <<"\n">>]
    },
    cm:general_target(Uid, TargetContent).

%%%===================================================================
%%% Internal functions (N/A)
%%%===================================================================