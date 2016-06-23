%% -------------------------------------------------------------------
%%
%% Copyright (c) 2016 Christopher S. Meiklejohn.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(ishikawa_sup).

-behaviour(supervisor).

-include("ishikawa.hrl").

-export([start_link/0]).

-export([init/1]).

-define(CHILD(I, Type, Timeout),
        {I, {I, start_link, []}, permanent, Timeout, Type, [I]}).
-define(CHILD(I, Type), ?CHILD(I, Type, 5000)).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = lists:flatten(
                 [
                 ?CHILD(ishikawa_backend, worker)
                 ]),

    %% Before initializing the partisan backend, be sure to configure it
    %% to use the proper ports.
    %%
    case os:getenv("PEER_PORT", "false") of
        "false" ->
            partisan_config:set(peer_port, random_port()),
            ok;
        PeerPort ->
            partisan_config:set(peer_port, list_to_integer(PeerPort)),
            ok
    end,

    Partisan = {partisan_sup,
                {partisan_sup, start_link, []},
                 permanent, infinity, supervisor, [partisan_sup]},

    RestartStrategy = {one_for_one, 10, 10},
    {ok, {RestartStrategy, Children ++ [Partisan]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%% @private
random_port() ->
    {ok, Socket} = gen_tcp:listen(0, []),
    {ok, {_, Port}} = inet:sockname(Socket),
    ok = gen_tcp:close(Socket),
    Port.
