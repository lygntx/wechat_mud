#!/usr/bin/env escript
%% -*- erlang -*-
%%! -smp enable -sname generate_appup verbose

%% noinspection ErlangUnusedFunction
main(Args) ->
    try
        [Option | TailArgs] = Args,
        case list_to_atom(Option) of
            gen_appup ->
                [AppName, OldVsn] = TailArgs,
                start(AppName, OldVsn);
            rollback_vsn ->
                [AppName, OldVsn] = TailArgs,
                update_version(AppName, OldVsn)
        end
    catch
        _:Reason ->
            io:format("~tp~n", [Reason]),
            usage()
    end.

usage() ->
    io:format("usage: [gen_appup|rollback_vsn] [release-name] [version(x.x.x)]\n"),
    halt(1).

start(AppName, OldVsn) ->
    NewVsn = increase_vsn(OldVsn, 3, 1), %% will not modify version number in rebar.config and [app_name].app.src

    %% -------------------------get existing instructions - start-------------------------
    OldAppupPath = "ebin/" ++ AppName ++ ".appup",
    ExistingInstructions =
        case file:consult(OldAppupPath) of
            {ok, [{OldVsn, [{_, SrcInstructions}], [{_, []}]}]} ->
                update_existing_instruction_version(SrcInstructions, OldVsn, NewVsn, []);
            _ ->
                []
        end,
    %% -------------------------get existing instructions - end---------------------------

    %% -------------------------generate new instructions - start-------------------------
    BeamFolder = os:cmd("rebar3 path --app " ++ AppName),
    ModifiedFiles = string:tokens(os:cmd("git diff --name-only HEAD~0 --diff-filter=M | grep -E 'src.*\.erl'"), "\n"),
    ModifiedInstructions = generate_modified_instruction(modified, ModifiedFiles, OldVsn, NewVsn, BeamFolder, []),

    DeletedFiles = string:tokens(os:cmd("git diff --name-only HEAD~0 --diff-filter=D | grep -E 'src.*\.erl'"), "\n"),
    DeletedModifiedInstructions = generate_added_deleted_instruction(delete_module, DeletedFiles, ModifiedInstructions),

    AddedFiles = string:tokens(os:cmd("git ls-files --others --exclude-standard | grep -E 'src.*\.erl'; git diff --name-only HEAD~0 --diff-filter=A | grep -E 'src.*\.erl'"), "\n"),
    AddedDeletedModifiedInstructions = generate_added_deleted_instruction(add_module, AddedFiles, DeletedModifiedInstructions),
    %% -------------------------generate new instructions - end---------------------------

    FinalInstructions = ukeymerge(2, AddedDeletedModifiedInstructions, ExistingInstructions),

    case FinalInstructions of
        [] ->
            io:format("no_change");
        _ ->
            update_version(AppName, NewVsn),
            AppupContent = {NewVsn,
                [{OldVsn, FinalInstructions}],
                [{OldVsn, []}]},
            os:cmd("mkdir -p ebin"),
            AppupContentBin = io_lib:format("~tp.", [AppupContent]),
            file:write_file(OldAppupPath, AppupContentBin),
            file:write_file("config/" ++ AppName ++ ".appup", AppupContentBin),
            io:format("~tp", [NewVsn])
    end.

generate_added_deleted_instruction(_, [], InstructionList) ->
    InstructionList;
generate_added_deleted_instruction(Status, [SrcFilePath | Tail], AccInstructions) when add_module == Status orelse delete_module == Status ->
    ModNameStr = filename:rootname(filename:basename(SrcFilePath)),
    ModName = list_to_atom(ModNameStr),
    Instruction = {Status, ModName},
    generate_added_deleted_instruction(Status, Tail, [Instruction | AccInstructions]).

generate_modified_instruction(_, [], _, _, _, InstructionList) ->
    InstructionList;
generate_modified_instruction(modified, [SrcFilePath | Tail], OldVsn, NewVsn, BeamFolder, AccInstructions) ->
    ModNameStr = filename:rootname(filename:basename(SrcFilePath)),
    ModName = list_to_atom(ModNameStr),
    ModFileName = ModNameStr ++ ".beam",
    BeamFilePath = filename:join(BeamFolder, ModFileName),
    Instruction =
        case file:read_file(BeamFilePath) of
            {ok, Beam} ->
                {ok, {_, [{exports, Exports}, {attributes, Attributes}]}} = beam_lib:chunks(Beam, [exports, attributes]),
                Behaviour = proplists:get_value(behaviour, Attributes, []),
                case lists:member(supervisor, Behaviour) of
                    true ->
                        {update, ModName, supervisor};
                    _ ->
                        case lists:member({code_change, 3}, Exports) orelse lists:member({code_change, 4}, Exports) of
                            true ->
                                {update, ModName, {advanced, {OldVsn, NewVsn, []}}};
                            _ ->
                                {load_module, ModName}
                        end
                end;
            _ ->
                io:format("Could not read ~s\n", [BeamFilePath])
        end,
    generate_modified_instruction(modified, Tail, OldVsn, NewVsn, BeamFolder, [Instruction | AccInstructions]).

update_version(AppName, TargetVsn) ->
    RelVsnMarker = "release-version-marker",
    os:cmd("sed -i.bak 's/\".*\" %% " ++ RelVsnMarker ++ "/\"" ++ TargetVsn ++ "\" %% " ++ RelVsnMarker ++ "/1' src/" ++ AppName ++ ".app.src  ;\
        sed -i.bak 's/\".*\" %% " ++ RelVsnMarker ++ "/\"" ++ TargetVsn ++ "\" %% " ++ RelVsnMarker ++ "/1' rebar.config  ;\
        rm -f rebar.config.bak  ;\
        rm -f src/" ++ AppName ++ ".app.src.bak").

increase_vsn(SourceVersion, VersionDepth, Increment) ->
    string:join(increase_vsn(string:tokens(SourceVersion, "."), VersionDepth, Increment, 1, []), ".").
increase_vsn([], _, _, _, AccVersion) ->
    lists:reverse(AccVersion);
increase_vsn([CurDepthVersionNumStr | Tail], VersionDepth, Increment, CurDepth, AccVersion) ->
    UpdatedVersionNum =
        case CurDepth =:= VersionDepth of
            true ->
                integer_to_list(list_to_integer(CurDepthVersionNumStr) + Increment);
            _ ->
                CurDepthVersionNumStr
        end,
    increase_vsn(Tail, VersionDepth, Increment, CurDepth + 1, [UpdatedVersionNum | AccVersion]).

update_existing_instruction_version([], _, _, AccResult) ->
    AccResult;
update_existing_instruction_version([{update, ModName, {advanced, {_, _, []}}} | Tail], OldVsn, NewVsn, AccResult) ->
    update_existing_instruction_version(Tail, OldVsn, NewVsn, [{update, ModName, {advanced, {OldVsn, NewVsn, []}}} | AccResult]);
update_existing_instruction_version([Other | Tail], OldVsn, NewVsn, AccResult) ->
    update_existing_instruction_version(Tail, OldVsn, NewVsn, [Other | AccResult]).

ukeymerge(ElemPos, SrcList, MergeList) ->
    MergeMap = proplist_to_map(ElemPos, MergeList, #{}),
    FinalMap = proplist_to_map(ElemPos, SrcList, MergeMap),
    maps:values(FinalMap).

proplist_to_map(_, [], AccMap) ->
    AccMap;
proplist_to_map(ElemPos, [Value | Tail], AccMap) ->
    Key = erlang:element(ElemPos, Value),
    proplist_to_map(ElemPos, Tail, AccMap#{Key => Value}).