%%%-------------------------------------------------------------------
%%% @author Shuieryin
%%% @copyright (C) 2015, Shuieryin
%%% @doc
%%%
%%% Login gen_server. This server supports overall user login, logout,
%%% and register services as well as maintains logged in and registered uids.
%%%
%%% @end
%%% Created : 25. Aug 2015 9:11 PM
%%%-------------------------------------------------------------------
-module(login_server).
-author("Shuieryin").

-behaviour(gen_server).

%% API
-export([start_link/0,
    is_uid_registered/1,
    is_in_registration/1,
    register_uid/2,
    registration_done/2,
    delete_player/1,
    login/2,
    is_uid_logged_in/1,
    logout/2,
    is_id_registered/1]).

-define(R_REGISTERED_UIDS_SET, registered_uids_set).
-define(R_REGISTERED_IDS_SET, registered_ids_set).
-define(REGISTERING_UIDS_SET, registration_uids_set).
-define(LOGGED_IN_UIDS_SET, logged_in_uids_set).
-define(BORN_TYPES, born_types).

%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3,
    format_status/2]).

-define(SERVER, ?MODULE).

-type uid_set() :: gb_sets:iter(player_fsm:uid()).
-type state() :: #{?REGISTERING_UIDS_SET => uid_set(), ?R_REGISTERED_UIDS_SET => uid_set(), ?LOGGED_IN_UIDS_SET => uid_set(), ?BORN_TYPES => #{player_fsm:born_month() => player_fsm:born_type_info()}}.

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts server by setting module name as server name.
%%
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> gen:start_ret().
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%--------------------------------------------------------------------
%% @doc
%% Checks if uid has been registered.
%%
%% @end
%%--------------------------------------------------------------------
-spec is_uid_registered(Uid) -> boolean() when
    Uid :: player_fsm:uid().
is_uid_registered(Uid) ->
    gen_server:call(?MODULE, {is_uid_registered, Uid}).

%%--------------------------------------------------------------------
%% @doc
%% Checks if id has been registered.
%%
%% @end
%%--------------------------------------------------------------------
-spec is_id_registered(Id) -> boolean() when
    Id :: player_fsm:id().
is_id_registered(Id) ->
    gen_server:call(?MODULE, {is_id_registered, Id}).

%%--------------------------------------------------------------------
%% @doc
%% Checks if uid is in registration procedure.
%%
%% @end
%%--------------------------------------------------------------------
-spec is_in_registration(Uid) -> boolean() when
    Uid :: player_fsm:uid().
is_in_registration(Uid) ->
    gen_server:call(?MODULE, {is_in_registration, Uid}).

%%--------------------------------------------------------------------
%% @doc
%% Checks if uid is in registration procedure.
%%
%% @end
%%--------------------------------------------------------------------
-spec register_uid(DispatcherPid, Uid) -> ok when
    Uid :: player_fsm:uid(),
    DispatcherPid :: pid().
register_uid(DispatcherPid, Uid) ->
    gen_server:cast(?MODULE, {register_uid, DispatcherPid, Uid}).

%%--------------------------------------------------------------------
%% @doc
%% This function is only called by regsiter_fsm when registration
%% procedure is done. It adds uid to registered uid set, save to
%% redis immediately, and log user in.
%%
%% @end
%%--------------------------------------------------------------------
-spec registration_done(PlayerProfile, DispatcherPid) -> ok when
    PlayerProfile :: player_fsm:player_profile(),
    DispatcherPid :: pid().
registration_done(PlayerProfile, DispatcherPid) ->
    gen_server:cast(?MODULE, {registration_done, PlayerProfile, DispatcherPid}).

%%--------------------------------------------------------------------
%% @doc
%% This function deletes player in all states including redis. It logs
%% out player, delete player states from server state, and updates redis.
%%
%% @end
%%--------------------------------------------------------------------
-spec delete_player(Uid) -> ok when
    Uid :: player_fsm:uid().
delete_player(Uid) ->
    gen_server:call(?MODULE, {delete_user, Uid}).

%%--------------------------------------------------------------------
%% @doc
%% Logs user in by creating its own player_fsm process.
%%
%% @end
%%--------------------------------------------------------------------
-spec login(DispatcherPid, Uid) -> ok when
    DispatcherPid :: pid(),
    Uid :: player_fsm:uid().
login(DispatcherPid, Uid) ->
    gen_server:cast(?MODULE, {login, DispatcherPid, Uid}).

%%--------------------------------------------------------------------
%% @doc
%% Checks if uid has logged in.
%%
%% @end
%%--------------------------------------------------------------------
-spec is_uid_logged_in(Uid) -> boolean() when
    Uid :: player_fsm:uid().
is_uid_logged_in(Uid) ->
    gen_server:call(?MODULE, {is_uid_logged_in, Uid}).

%%--------------------------------------------------------------------
%% @doc
%% Logs user out by destroying its player_fsm process.
%%
%% @end
%%--------------------------------------------------------------------
-spec logout(DispatcherPid, Uid) -> ok when
    DispatcherPid :: pid(),
    Uid :: player_fsm:uid().
logout(DispatcherPid, Uid) ->
    gen_server:cast(?MODULE, {logout, DispatcherPid, Uid}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server by retrieves registered uid set from redis
%% and cache to a gb_set, and creates new gb_sets for registering uids
%% and logged in uids for caching.
%%
%% @end
%%--------------------------------------------------------------------
-spec init([]) ->
    {ok, State} |
    {ok, State, timeout() | hibernate} |
    {stop, Reason} |
    ignore when

    State :: state(),
    Reason :: term(). % generic term
init([]) ->
    io:format("~p starting...", [?MODULE]),
    RegisteredUidsSet =
        case redis_client_server:get(?R_REGISTERED_UIDS_SET) of
            undefined ->
                NewRegisteredUidsSet = gb_sets:new(),
                redis_client_server:set(?R_REGISTERED_UIDS_SET, NewRegisteredUidsSet, true),
                NewRegisteredUidsSet;
            UidSet ->
                error_logger:info_msg("Registered uid list:~p~n", [UidSet]),
                UidSet
        end,

    RegisteredIdsSet =
        case redis_client_server:get(?R_REGISTERED_IDS_SET) of
            undefined ->
                NewRegisteredIdsSet = gb_sets:new(),
                redis_client_server:set(?R_REGISTERED_UIDS_SET, NewRegisteredIdsSet, true),
                NewRegisteredIdsSet;
            IdSet ->
                error_logger:info_msg("Registered uid list:~p~n", [IdSet]),
                IdSet
        end,

    BornTypesMap = common_server:get_runtime_data([born_types]),
    State = #{?REGISTERING_UIDS_SET => gb_sets:new(), ?R_REGISTERED_UIDS_SET => RegisteredUidsSet, ?R_REGISTERED_IDS_SET => RegisteredIdsSet, ?LOGGED_IN_UIDS_SET => gb_sets:new(), ?BORN_TYPES => BornTypesMap},

    io:format("started~n"),
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request, From, State) ->
    {reply, Reply, NewState} |
    {reply, Reply, NewState, timeout() | hibernate} |
    {noreply, NewState} |
    {noreply, NewState, timeout() | hibernate} |
    {stop, Reason, Reply, NewState} |
    {stop, Reason, NewState} when

    Request :: {is_uid_registered | is_in_registration | delete_user, Uid},
    Reply :: IsUidRegistered | IsIdRegistered | IsInRegistration | IsUserLoggedIn | ok,

    Uid :: player_fsm:uid(),
    IsUidRegistered :: boolean(),
    IsIdRegistered :: boolean(),
    IsInRegistration :: boolean(),
    IsUserLoggedIn :: boolean(),

    From :: {pid(), Tag :: term()}, % generic term
    State :: state(),
    NewState :: State,
    Reason :: term(). % generic term
handle_call({is_uid_registered, Uid}, _From, #{?R_REGISTERED_UIDS_SET := RegisteredUidsSet} = State) ->
    {reply, gb_sets:is_element(Uid, RegisteredUidsSet), State};
handle_call({is_id_registered, Id}, _From, #{?R_REGISTERED_IDS_SET := RegisteredIdsSet} = State) ->
    {reply, gb_sets:is_element(Id, RegisteredIdsSet), State};
handle_call({is_in_registration, Uid}, _From, #{?REGISTERING_UIDS_SET := RegisteringUidsSet} = State) ->
    Result = gb_sets:is_element(Uid, RegisteringUidsSet),
    {reply, Result, State};
handle_call({delete_user, Uid}, _From, #{?R_REGISTERED_UIDS_SET := RegisteredUidsSet} = State) ->
    LoggedOutState = logout(internal, Uid, State),
    ok = cm:until_process_terminated(Uid, 20),
    UpdatedRegisteredUidsSet = gb_sets:delete(Uid, RegisteredUidsSet),

    redis_client_server:async_del([Uid], false),
    redis_client_server:async_set(?R_REGISTERED_UIDS_SET, UpdatedRegisteredUidsSet, true),

    {reply, ok, LoggedOutState#{?R_REGISTERED_UIDS_SET := UpdatedRegisteredUidsSet}};
handle_call({is_uid_logged_in, Uid}, _From, #{?LOGGED_IN_UIDS_SET := LoggedUidsSet} = State) ->
    {reply, gb_sets:is_element(Uid, LoggedUidsSet), State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request, State) ->
    {noreply, NewState} |
    {noreply, NewState, timeout() | hibernate} |
    {stop, Reason, NewState} when

    Request :: {registration_done, PlayerProfile, DispatcherPid} | {register_uid, DispatcherPid, Uid} | {login, DispatcherPid, Uid},
    DispatcherPid :: pid(),
    Uid :: player_fsm:uid(),
    PlayerProfile :: player_fsm:player_profile(),
    State :: state(),
    NewState :: State,
    Reason :: term(). % generic term
handle_cast({registration_done, #{uid := Uid, id := Id, born_month := BornMonth} = PlayerProfile, DispatcherPid}, #{?REGISTERING_UIDS_SET := RegisteringUidsSet, ?R_REGISTERED_UIDS_SET := RegisteredUidsSet, ?R_REGISTERED_IDS_SET := RegisteredIdsSet, ?BORN_TYPES := BornTypesMap} = State) ->
    UpdatedRegisteredUidsSet = gb_sets:add(Uid, RegisteredUidsSet),
    redis_client_server:async_set(?R_REGISTERED_UIDS_SET, UpdatedRegisteredUidsSet, false),

    UpdatedRegisteredIdsSet = gb_sets:add(Id, RegisteredIdsSet),
    redis_client_server:async_set(?R_REGISTERED_IDS_SET, UpdatedRegisteredIdsSet, false),

    BornType = maps:get(BornMonth, BornTypesMap),
    redis_client_server:set(Uid, PlayerProfile#{born_type => BornType}, true),

    UpdatedState = State#{
        ?R_REGISTERED_UIDS_SET := UpdatedRegisteredUidsSet,
        ?R_REGISTERED_IDS_SET := UpdatedRegisteredIdsSet,
        ?REGISTERING_UIDS_SET => gb_sets:del_element(Uid, RegisteringUidsSet)
    },

    login(DispatcherPid, Uid),
    {noreply, UpdatedState};
handle_cast({register_uid, DispatcherPid, Uid}, State) ->
    UpdatedState =
        case register_fsm_sup:add_child(DispatcherPid, Uid) of
            {ok, _} ->
                error_logger:info_msg("Started register fsm successfully.~nUid:~p~n", [Uid]),
                RegisteringUidsSet = maps:get(?REGISTERING_UIDS_SET, State),
                State#{?REGISTERING_UIDS_SET := gb_sets:add(Uid, RegisteringUidsSet)};
            {error, Reason} ->
                error_logger:error_msg("Failed to start register fsm.~nUid:~p~nReason:~p~n", [Uid, Reason]),
                State
        end,
    {noreply, UpdatedState};
handle_cast({login, DispatcherPid, Uid}, #{?LOGGED_IN_UIDS_SET := LoggedInUidsSet} = State) ->
    UpdatedLoggedInUidsSet =
        case gb_sets:is_element(Uid, LoggedInUidsSet) of
            false ->
                #{scene := CurSceneName, name := PlayerName, id := Id} = PlayerProfile = redis_client_server:get(Uid),
                player_fsm_sup:add_child(PlayerProfile),
                scene_fsm:enter(CurSceneName, Uid, PlayerName, Id, DispatcherPid),
                gb_sets:add(Uid, LoggedInUidsSet);
            _ ->
                player_fsm:response_content(Uid, [{nls, already_login}], DispatcherPid),
                LoggedInUidsSet
        end,

    {noreply, State#{?LOGGED_IN_UIDS_SET := UpdatedLoggedInUidsSet}};
handle_cast({logout, DispatcherPid, Uid}, State) ->
    UpdatedState = logout(internal, Uid, State),
    player_fsm:response_content(Uid, [{nls, already_logout}], DispatcherPid),
    {noreply, UpdatedState}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info | timeout(), State) ->
    {noreply, NewState} |
    {noreply, NewState, timeout() | hibernate} |
    {stop, Reason, NewState} when

    Info :: term(), % generic term
    State :: state(),
    NewState :: State,
    Reason :: term(). % generic term
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason, State) -> ok when
    Reason :: (normal | shutdown | {shutdown, term()} | term()), % generic term
    State :: state().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn, State, Extra) ->
    {ok, NewState} |
    {error, Reason} when

    OldVsn :: term() | {down, term()}, % generic term
    State :: state(),
    Extra :: term(), % generic term
    NewState :: State,
    Reason :: term(). % generic term
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

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
    State :: state(),
    Status :: term(). % generic term
format_status(Opt, StatusData) ->
    gen_server:format_status(Opt, StatusData).

%%%===================================================================
%%% Internal functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% This function is called by "delete_user" and "logout" from
%% handle_call/3 and handle_cast/2.
%%
%% Logs user out by destroying its player_fsm process.
%%
%% @end
%%--------------------------------------------------------------------
-spec logout(internal, Uid, State) -> UpdatedState when
    Uid :: player_fsm:uid(),
    State :: state(),
    UpdatedState :: State.
logout(internal, Uid, #{?LOGGED_IN_UIDS_SET := LoggedInUidsSet} = State) ->
    UpdatedLoggedInUidsSet =
        case gb_sets:is_element(Uid, LoggedInUidsSet) of
            false ->
                LoggedInUidsSet;
            _ ->
                spawn(player_fsm, logout, [Uid]),
                gb_sets:del_element(Uid, LoggedInUidsSet)
        end,
    State#{?LOGGED_IN_UIDS_SET := UpdatedLoggedInUidsSet}.