%%%-------------------------------------------------------------------
%%% @author shuieryin
%%% @copyright (C) 2015, Shuieryin
%%% @doc
%%%
%%% @end
%%% Created : 29. Nov 2015 8:09 PM
%%%-------------------------------------------------------------------
-module(common_server_test).
-author("shuieryin").

%% API
-export([
    command/1,
    initial_state/0,
    precondition/2,
    postcondition/3,
    next_state/3
]).

-export([
    test/1
]).

-define(SERVER, common_server).

-include_lib("wechat_mud_test.hrl").
-include_lib("wechat_mud/src/data_type/npc_born_info.hrl").

-define(RANDOM_RUNTIME_FILENAME,
    begin
        {ok, FileNameList} = file:list_dir(filename:join(code:priv_dir(wechat_mud), "runtime")),
        list_to_atom(filename:rootname(?ONE_OF(FileNameList)))
    end).

-define(RUNTIME_DATA_INSTRUCTION, ?ONE_OF([

    [?RANDOM_RUNTIME_FILENAME],

    begin
        FileName = ?RANDOM_RUNTIME_FILENAME,
        CertainData = common_server:get_runtime_data(FileName),
        DataKeys = maps:keys(CertainData),
        RecordKey = ?ONE_OF(DataKeys),
        [FileName, RecordKey]
    end

])).

%%%===================================================================
%%% API
%%%===================================================================

test(_Config) ->
    common_server:start_link(),
    ?GT(),
    common_server:stop().

command(_ModelState) ->
    oneof([
        {call, ?SERVER, turn_on_wechat_debug, []},
        {call, ?SERVER, turn_off_wechat_debug, []},
        {call, ?SERVER, get_runtime_data, ?RUNTIME_DATA_INSTRUCTION},
        {call, ?SERVER, random_npc, []}
    ]).

initial_state() ->
    {}.

next_state(ModelState, _Var, {call, ?SERVER, _Action, _Args}) ->
    ModelState.

precondition(_ModelState, {call, ?SERVER, _Action, _Args}) ->
    true.

postcondition(_ModelState, {call, ?SERVER, turn_on_wechat_debug, []}, _Result) ->
    common_server:is_wechat_debug();
postcondition(_ModelState, {call, ?SERVER, turn_off_wechat_debug, []}, _Result) ->
    not common_server:is_wechat_debug();
postcondition(_ModelState, {call, ?SERVER, get_runtime_data, Args}, Result) ->
    case length(Args) of
        1 ->
            0 == length([any || Record <- maps:values(Result), not record_not_undefined(Record)]);
        2 ->
            record_not_undefined(Result)
    end;
postcondition(_ModelState, {call, ?SERVER, random_npc, []}, #npc_born_info{npc_fsm_id = NpcFsmId}) ->
    #npc_born_info{npc_fsm_id = NewNpcFsmId} = common_server:get_runtime_data(npc_born_info, NpcFsmId),
    NewNpcFsmId == NpcFsmId.

%%%===================================================================
%%% Internal functions (N/A)
%%%===================================================================
record_not_undefined(Record) ->
    0 == length([Field || Field <- tuple_to_list(Record), undefined == Field]).