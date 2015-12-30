%%%-------------------------------------------------------------------
%%% @author Shuieryin
%%% @copyright (C) 2015, Shuieryin
%%% @doc
%%%
%%% Player gen_fsm. This gen_fsm is created when player logs in and
%%% detroyed when player logs out. It holds the current player state
%%% and state data for player journey.
%%%
%%% @end
%%% Created : 18. Aug 2015 8:57 PM
%%%-------------------------------------------------------------------
-module(player_fsm).
-author("shuieryin").

-behaviour(gen_fsm).

%% API
-export([
    start_link/1,
    start/1,
    logout/1,
    go_direction/3,
    look_scene/2,
    get_lang/1,
    response_content/3,
    leave_scene/1,
    switch_lang/3,
    look_target/3,
    being_looked/2,
    current_scene_name/1,
    append_message/3,
    simple_player/1
]).

%% gen_fsm callbacks
-export([
    init/1,
    state_name/2,
    state_name/3,
    handle_event/3,
    handle_sync_event/4,
    handle_info/3,
    terminate/3,
    code_change/4,
    format_status/2
]).

-type uid() :: atom().
-type born_month() :: 1..12.
-type gender() :: male | female.
-type id() :: binary(). % define id to binary for convenience of pattern matching.
-type name() :: nls_server:nls_object().
-type mail_object() :: [nls_server:nls_object()].

-include("../data_type/player_profile.hrl").
-include("../data_type/npc_born_info.hrl").

-type mail_type() :: battle | scene | other.
-record(mailbox, {
    battle = [] :: [mail_object()],
    scene = [] :: [mail_object()],
    other = [] :: [mail_object()]
}).

-record(state, {
    self :: #player_profile{},
    mail_box :: #mailbox{},
    lang_map :: nls_server:lang_map()
}).

-type state_name() :: state_name | non_battle.

-export_type([
    born_month/0,
    uid/0,
    gender/0,
    id/0,
    name/0]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a player gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% This function starts gen_fsm by setting player uid as fsm name.
%%
%% @end
%%--------------------------------------------------------------------
-spec start_link(PlayerProfile) -> gen:start_ret() when
    PlayerProfile :: #player_profile{}.
start_link(#player_profile{uid = Uid} = PlayerProfile) ->
    gen_fsm:start_link({local, Uid}, ?MODULE, PlayerProfile, []).

%%--------------------------------------------------------------------
%% @doc
%% Same as start_link/1 but without link.
%% @see start_link/0.
%%
%% @end
%%--------------------------------------------------------------------
-spec start(PlayerProfile) -> gen:start_ret() when
    PlayerProfile :: #player_profile{}.
start(#player_profile{uid = Uid} = PlayerProfile) ->
    gen_fsm:start({local, Uid}, ?MODULE, PlayerProfile, []).

%%--------------------------------------------------------------------
%% @doc
%% Go to direction.
%%
%% This function does the followings:
%% 1. Checks if current scene is linked to the target scene, if so go to
%% step 2, otherwise remind user the direction is invalid.
%%
%% 2. Leave the current scene, enter the target scene, and display the
%% target scene info to user.
%%
%% @end
%%--------------------------------------------------------------------
-spec go_direction(DispatcherPid, Uid, Direction) -> ok when
    DispatcherPid :: pid(),
    Uid :: uid(),
    Direction :: direction:directions().
go_direction(DispatcherPid, Uid, Direction) ->
    gen_fsm:send_all_state_event(Uid, {go_direction, DispatcherPid, Direction}).

%%--------------------------------------------------------------------
%% @doc
%% Displays the current scene info to user.
%%
%% @end
%%--------------------------------------------------------------------
-spec look_scene(DispatcherPid, Uid) -> ok when
    DispatcherPid :: pid(),
    Uid :: uid().
look_scene(DispatcherPid, Uid) ->
    gen_fsm:send_all_state_event(Uid, {look_scene, DispatcherPid}).

%%--------------------------------------------------------------------
%% @doc
%% Displays the current scene info to user.
%%
%% @end
%%--------------------------------------------------------------------
-spec look_target(DispatcherPid, Uid, LookArgs) -> ok when
    DispatcherPid :: pid(),
    Uid :: uid(),
    LookArgs :: binary().
look_target(DispatcherPid, Uid, LookArgs) ->
    gen_fsm:send_all_state_event(Uid, {look_target, DispatcherPid, LookArgs}).

%%--------------------------------------------------------------------
%% @doc
%% Being looked by given player. The npc might launch a offensive to
%% player depending on its rage point.
%%
%% @end
%%--------------------------------------------------------------------
-spec being_looked(TargetPlayerUid, SrcCharacter) -> ok when
    TargetPlayerUid :: player_fsm:uid(),
    SrcCharacter :: scene_fsm:scene_object().
being_looked(TargetPlayerUid, SrcCharacter) ->
    gen_fsm:sync_send_all_state_event(TargetPlayerUid, {being_looked, SrcCharacter}).

%%--------------------------------------------------------------------
%% @doc
%% Get the current scene name of one player.
%%
%% @end
%%--------------------------------------------------------------------
-spec current_scene_name(PlayerUid) -> scene_fsm:scene_name() when
    PlayerUid :: player_fsm:uid().
current_scene_name(PlayerUid) ->
    gen_fsm:sync_send_all_state_event(PlayerUid, current_scene_name).

%%--------------------------------------------------------------------
%% @doc
%% Retrieve the current language of the player.
%%
%% @end
%%--------------------------------------------------------------------
-spec get_lang(Uid) -> Lang when
    Uid :: uid(),
    Lang :: nls_server:support_lang().
get_lang(Uid) ->
    gen_fsm:sync_send_all_state_event(Uid, get_lang).

%%--------------------------------------------------------------------
%% @doc
%% Given "ContentList" contains items {nls, NlsKey} with direct return
%% content values, the function is to replace {nls, NlsKey} with the actual
%% nls content, and then immediately return the result to user.
%%
%% This function is called only when is the player language is not given,
%% and the purpose of calling this function is to save return back round
%% by calling get_lang/2.
%%
%% @end
%%--------------------------------------------------------------------
-spec response_content(Uid, ContentList, DispatcherPid) -> ok when
    Uid :: uid(),
    ContentList :: [term()], % generic term
    DispatcherPid :: pid().
response_content(Uid, ContentList, DispatcherPid) ->
    gen_fsm:send_all_state_event(Uid, {response_content, ContentList, DispatcherPid}).

%%--------------------------------------------------------------------
%% @doc
%% Leaves the current scene.
%%
%% This function is called when player is going to other scene or
%% logging out.
%%
%% @end
%%--------------------------------------------------------------------
-spec leave_scene(Uid) -> ok when
    Uid :: uid().
leave_scene(Uid) ->
    gen_fsm:send_all_state_event(Uid, leave_scene).

%%--------------------------------------------------------------------
%% @doc
%% Switches player language.
%%
%% @end
%%--------------------------------------------------------------------
-spec switch_lang(DispatcherPid, Uid, TargetLang) -> ok when
    DispatcherPid :: pid(),
    Uid :: uid(),
    TargetLang :: nls_server:support_lang().
switch_lang(DispatcherPid, Uid, TargetLang) ->
    gen_fsm:send_all_state_event(Uid, {switch_lang, DispatcherPid, TargetLang}).

%%--------------------------------------------------------------------
%% @doc
%% Logs out player by exit the current scene and terminate its player
%% gen_fsm process.
%%
%% @end
%%--------------------------------------------------------------------
-spec logout(Uid) -> ok when
    Uid :: uid().
logout(Uid) ->
    gen_fsm:send_all_state_event(Uid, logout).

%%--------------------------------------------------------------------
%% @doc
%% Append message to mailbox. The appended message will be shown to
%% the target player by his/her next action.
%%
%% @end
%%--------------------------------------------------------------------
-spec append_message(Uid, Message, MailType) -> ok when
    Uid :: player_fsm:uid(),
    Message :: mail_object(),
    MailType :: mail_type().
append_message(Uid, Message, MailType) ->
    gen_fsm:send_all_state_event(Uid, {append_message, Message, MailType}).

%%--------------------------------------------------------------------
%% @doc
%% Returns simple player record.
%%
%% @end
%%--------------------------------------------------------------------
-spec simple_player(#player_profile{}) -> #simple_player{}.
simple_player(#player_profile{uid = Uid, name = Name, id = Id, self_description = SelfDescription}) ->
    #simple_player{uid = Uid, name = Name, id = Id, name_description = SelfDescription}.

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% See start_link/1 for details.
%%
%% @end
%%--------------------------------------------------------------------
-spec init(PlayerProfile) ->
    {ok, StateName, StateData} |
    {ok, StateName, StateData, timeout() | hibernate} |
    {stop, Reason} |
    ignore when

    PlayerProfile :: #player_profile{},
    StateName :: state_name(),
    StateData :: #state{},
    Reason :: term(). % generic term
init(#player_profile{lang = Lang} = PlayerProfile) ->
    LangMap = nls_server:get_lang_map(Lang),
%%    error_logger:info_msg("Player fsm initialized:~p~n", [PlayerProfile]),
    {ok, non_battle, #state{self = PlayerProfile, lang_map = LangMap, mail_box = #mailbox{}}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @end
%%--------------------------------------------------------------------
-spec state_name(Event, State) ->
    {next_state, NextStateName, NextState} |
    {next_state, NextStateName, NextState, timeout() | hibernate} |
    {stop, Reason, NewState} when

    Event :: term(), % generic term
    State :: #state{},
    NextStateName :: state_name(),
    NextState :: State,
    NewState :: State,
    Reason :: term(). % generic term
state_name(_Event, State) ->
    {next_state, state_name, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/[2,3], the instance of this function with
%% the same name as the current state name StateName is called to
%% handle the event.
%%
%% @end
%%--------------------------------------------------------------------
-spec state_name(Event, From, State) ->
    {next_state, NextStateName, NextState} |
    {next_state, NextStateName, NextState, timeout() | hibernate} |
    {reply, Reply, NextStateName, NextState} |
    {reply, Reply, NextStateName, NextState, timeout() | hibernate} |
    {stop, Reason, NewState} |
    {stop, Reason, Reply, NewState} when

    Event :: term(), % generic term
    Reply :: ok,

    From :: {pid(), term()}, % generic term
    State :: #state{},
    NextStateName :: state_name(),
    NextState :: State,
    Reason :: normal | term(), % generic term
    NewState :: State.
state_name(_Event, _From, State) ->
    Reply = ok,
    {reply, Reply, state_name, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_event(Event, StateName, StateData) ->
    {next_state, NextStateName, NewStateData} |
    {next_state, NextStateName, NewStateData, timeout() | hibernate} |
    {stop, Reason, NewStateData} when

    Event ::
    {go_direction, DispatcherPid, Direction} |
    {look_scene, DispatcherPid} |
    {look_target, DispatcherPid, LookArgs} |
    {response_content, NlsObjectList, DispatcherPid} |
    leave_scene |
    {switch_lang, DispatcherPid, TargetLang} |
    {logout, NotifyOkPid} |
    {append_message, Message, MailType} |
    stop,

    NlsObjectList :: [nls_server:nls_object()],
    DispatcherPid :: pid(),
    Direction :: direction:directions(),
    LookArgs :: binary(),
    NotifyOkPid :: pid(),
    TargetLang :: nls_server:support_lang(),
    Message :: mail_object(),
    MailType :: mail_type(),

    StateName :: state_name(),
    StateData :: #state{},
    NextStateName :: StateName,
    NewStateData :: StateData,
    Reason :: term(). % generic term
handle_event({go_direction, DispatcherPid, Direction}, StateName, #state{mail_box = MailBox, self = #player_profile{scene = CurSceneName, uid = Uid} = PlayerProfile} = State) ->
    {TargetSceneName, UpdatedMailBox} =
        case scene_fsm:go_direction(CurSceneName, Uid, Direction) of
            undefined ->
                Umb = do_response_content(State, [{nls, invalid_exit}], DispatcherPid),
                {CurSceneName, Umb};
            NewSceneName ->
                scene_fsm:enter(NewSceneName, DispatcherPid, simple_player(PlayerProfile), CurSceneName),
                {NewSceneName, MailBox}
        end,

    {next_state, StateName, State#state{mail_box = UpdatedMailBox, self = PlayerProfile#player_profile{scene = TargetSceneName}}};
handle_event({look_scene, DispatcherPid}, StateName, #state{self = #player_profile{scene = CurSceneName, uid = Uid}} = State) ->
    scene_fsm:look_scene(CurSceneName, Uid, DispatcherPid),
    {next_state, StateName, State};
handle_event({look_target, DispatcherPid, LookArgs}, StateName, #state{self = #player_profile{scene = CurSceneName} = PlayerProfile} = State) ->
    scene_fsm:look_target(CurSceneName, simple_player(PlayerProfile), DispatcherPid, LookArgs),
    {next_state, StateName, State};
handle_event({response_content, NlsObjectList, DispatcherPid}, StateName, State) ->
    UpdatedMailBox = do_response_content(State, NlsObjectList, DispatcherPid),
    {next_state, StateName, State#state{mail_box = UpdatedMailBox}};
handle_event(leave_scene, StateName, #state{self = #player_profile{scene = CurSceneName, uid = Uid}} = State) ->
    scene_fsm:leave(CurSceneName, Uid),
    {next_state, StateName, State};
handle_event({switch_lang, DispatcherPid, TargetLang}, StateName, #state{self = #player_profile{uid = Uid} = PlayerProfile} = State) ->
    TargetLangMap = nls_server:get_lang_map(TargetLang),
    UpdatedState = State#state{lang_map = TargetLangMap},
    UpdatedMailBox = do_response_content(UpdatedState, [{nls, lang_switched}], DispatcherPid),
    UpdatedPlayerProfile = PlayerProfile#player_profile{lang = TargetLang},
    redis_client_server:async_set(Uid, UpdatedPlayerProfile, true),
    {next_state, StateName, UpdatedState#state{self = UpdatedPlayerProfile, lang_map = TargetLangMap, mail_box = UpdatedMailBox}};
handle_event(logout, _StateName, #state{self = #player_profile{scene = CurSceneName, uid = Uid} = PlayerProfile} = State) ->
    scene_fsm:leave(CurSceneName, Uid),
    error_logger:info_msg("Logout PlayerProfile:~p~n", [PlayerProfile]),
    redis_client_server:set(Uid, PlayerProfile, true),
    {stop, normal, State};
handle_event({append_message, Message, MailType}, StateName, State) ->
    {next_state, StateName, append_message_priv(Message, MailType, State)};
handle_event(stop, _StateName, State) ->
    {stop, normal, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_sync_event(Event, From, StateName, StateData) ->
    {reply, Reply, NextStateName, NewStateData} |
    {reply, Reply, NextStateName, NewStateData, timeout() | hibernate} |
    {next_state, NextStateName, NewStateData} |
    {next_state, NextStateName, NewStateData, timeout() | hibernate} |
    {stop, Reason, Reply, NewStateData} |
    {stop, Reason, NewStateData} when

    Event :: get_lang |
    {being_looked, SrcCharacter} |
    current_scene_name,

    Reply :: Lang,

    Lang :: nls_server:support_lang(),
    SrcCharacter :: scene_fsm:scene_object(),

    From :: {pid(), Tag :: term()}, % generic term
    StateName :: state_name(),
    StateData :: #state{},
    NextStateName :: StateName,
    NewStateData :: StateData,
    Reason :: term(). % generic term
handle_sync_event(get_lang, _From, StateName, #state{self = #player_profile{lang = Lang}} = State) ->
    {reply, Lang, StateName, State};
handle_sync_event({being_looked, SrcCharacter}, _From, StateName, #state{self = #player_profile{uid = TargetFsmId, description = Description, self_description = SelfDescription}} = State) ->
    {SrcFsmId, SrcName} =
        case SrcCharacter of
            #simple_player{uid = SourceFsmId, name = SourceName} ->
                {SourceFsmId, SourceName};
            #simple_npc_fsm{npc_fsm_id = SourceFsmId, npc_name_nls_key = SourceName} ->
                {SourceFsmId, SourceName}
        end,
    ContentList = if
                      SrcFsmId == TargetFsmId ->
                          [SelfDescription, <<"\n">>];
                      true ->
                          [Description, <<"\n">>]
                  end,

    SceneMessage = [SrcName, {nls, being_looked}, <<"\n">>],
    {reply, ContentList, StateName, append_message_priv(SceneMessage, scene, State)};
handle_sync_event(current_scene_name, _From, StateName, #state{self = #player_profile{scene = CurrentSceneName}} = State) ->
    {reply, CurrentSceneName, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info, StateName, StateData) ->
    {next_state, NextStateName, NewStateData} |
    {next_state, NextStateName, NewStateData, timeout() | hibernate} |
    {stop, Reason, NewStateData} when

    Info :: term(), % generic term
    StateName :: state_name(),
    StateData :: #state{},
    NextStateName :: StateName,
    NewStateData :: StateData,
    Reason :: normal | term(). % generic term
handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored. If the gen_fsm is terminated
%% abnormally, it is restarted with the current state name and state data.
%%
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason, StateName, StateData) -> ok when
    Reason :: normal | shutdown | {shutdown, term()} | term(), % generic term
    StateName :: state_name(),
    StateData :: #state{}.
terminate(_Reason, _StateName, _StateData) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn, StateName, StateData, Extra) -> {ok, NextStateName, NewStateData} when
    OldVsn :: term() | {down, term()}, % generic term
    StateName :: state_name(),
    StateData :: #state{},
    Extra :: term(), % generic term
    NextStateName :: StateName,
    NewStateData :: StateData.
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is useful for customising the form and
%% appearance of the gen_server status for these cases.
%%
%% @spec format_status(Opt, StatusData) -> Status
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt, StatusData) -> Status when
    Opt :: 'normal' | 'terminate',
    StatusData :: [PDict | State],
    PDict :: [{Key :: term(), Value :: term()}], % generic term
    State :: #state{},
    Status :: term(). % generic term
format_status(Opt, StatusData) ->
    gen_fsm:format_status(Opt, StatusData).

%%%===================================================================
%%% Internal functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Implementation function for nls_server:response_content/3.
%% @see nls_server:response_content/3.
%%
%% @end
%%--------------------------------------------------------------------
-spec do_response_content(State, NlsObjectList, DispatcherPid) -> UpdatedMailBox when
    State :: #state{},
    NlsObjectList :: [nls_server:nls_object()],
    DispatcherPid :: pid(),
    UpdatedMailBox :: #mailbox{}.
do_response_content(#state{lang_map = LangMap, mail_box = #mailbox{scene = SceneMessages} = MailBox}, NlsObjectList, DispatcherPid) ->
    FinalNlsObjectList = case SceneMessages of
                             [] ->
                                 NlsObjectList;
                             _ ->
                                 lists:flatten([lists:reverse(SceneMessages), <<"\n">>, NlsObjectList])
                         end,
    nls_server:do_response_content(LangMap, FinalNlsObjectList, DispatcherPid),
    MailBox#mailbox{scene = []}.

%%--------------------------------------------------------------------
%% @doc
%% Append message.
%%
%% @end
%%--------------------------------------------------------------------
-spec append_message_priv(Message, MailType, State) -> UpdatedState when
    Message :: mail_object(),
    MailType :: mail_type(),
    State :: #state{},
    UpdatedState :: State.
append_message_priv(Message, battle, #state{mail_box = #mailbox{battle = SceneMessages} = MailBox} = State) ->
    UpdatedSceneMessages = [Message | SceneMessages],
    State#state{mail_box = MailBox#mailbox{battle = UpdatedSceneMessages}};
append_message_priv(Message, scene, #state{mail_box = #mailbox{scene = SceneMessages} = MailBox} = State) ->
    UpdatedSceneMessages = [Message | SceneMessages],
    State#state{mail_box = MailBox#mailbox{scene = UpdatedSceneMessages}};
append_message_priv(Message, other, #state{mail_box = #mailbox{other = SceneMessages} = MailBox} = State) ->
    UpdatedSceneMessages = [Message | SceneMessages],
    State#state{mail_box = MailBox#mailbox{other = UpdatedSceneMessages}}.