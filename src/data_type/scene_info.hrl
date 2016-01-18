%%%-------------------------------------------------------------------
%%% @author shuieryin
%%% @copyright (C) 2015, Shuieryin
%%% @doc
%%%
%%% @end
%%% Created : 23. Nov 2015 4:55 PM
%%%-------------------------------------------------------------------
-author("shuieryin").

-record(scene_info, {
    id :: scene_fsm:scene_name(),
    exits :: scene_fsm:exits_map(),
    title :: nls_server:key(),
    desc :: nls_server:key(),
    npcs :: [npc_fsm_manager:npc_spec()]
}).

-record(target_content, {
    actions :: [player_fsm:action()],
    action_args :: player_fsm:action_args(),
    scene :: scene_fsm:scene_name(),
    from :: scene_fsm:scene_object(),
    to :: scene_fsm:scene_object(),
    dispatcher_pid :: pid(),
    target :: player_fsm:id() | npc_fsm_manager:npc_type(),
    sequence :: non_neg_integer(),
    target_bin :: binary(),
    self_targeted_message :: [nls_server:nls_object()]
}).