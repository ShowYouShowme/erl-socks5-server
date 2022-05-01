% hello world program
-module(hello_world).
%%% The echo module provides a simple TCP echo server. Users can telnet
%%% into the server and the sever will echo back the lines that are input
%%% by the user.
-export([accept/0]).

%% Starts an echo server listening for incoming connections on
%% the given Port.
accept() ->
    Port = 8001,
    {ok, Socket} = gen_tcp:listen(Port, [binary, {active, true}, {packet, 0}, {reuseaddr, true}]),
    io:format("Echo server listening on port ~p~n", [Port]),
    server_loop(Socket).

%% Accepts incoming socket connections and passes then off to a separate Handler process
server_loop(Socket) ->
    {ok, Connection} = gen_tcp:accept(Socket),
    Handler = spawn(fun () -> echo_loop(Connection) end),
    gen_tcp:controlling_process(Connection, Handler),
    % io:format("New connection ~p~n", [Connection]),
    server_loop(Socket).


% TODO 如何同时关闭两个链接
% TODO Close 时，可以发送消息通知另一个进程来关闭socket
% TODO 收到消息时，可以把数据发给另一个进程，让另一个进度send，这样就只是在一个进程里面操作一个socket
% TODO 两个线程同时 read或者同时write 会出错
tunnel(Connection, To)->
    receive
        {tcp, Connection, Data} ->
            gen_tcp:send(To, Data),
            tunnel(Connection, To);
        {tcp_closed, Connection} ->
            gen_tcp:close(Connection),
            gen_tcp:close(To)
	        % io:format("tunnel closed ~p~n", [Connection])
    end.

create_tunnel(Connection, Ip2, Port) ->
    case gen_tcp:connect(Ip2, Port, [binary, {packet, raw}, {active, true}, {reuseaddr, true}]) of
        {ok, DestSocket} ->
            % io:format("connect success!\n"),
            % tunnel
            H1 = spawn(fun () -> tunnel(Connection, DestSocket) end),
            gen_tcp:controlling_process(Connection, H1),

            H2 = spawn(fun () -> tunnel(DestSocket,Connection) end),
            gen_tcp:controlling_process(DestSocket, H2);
        {error, Reason} ->
            gen_tcp:close(Connection),
            io:format("链接失败,reason : ~p ,关闭文件描述符\n", [Reason])
    end.

request(Connection)->
    receive
        {tcp, Connection, Data} ->
            % io:format("Data:~p\n",[Data]),
            Resp = <<5,0,0,1,0,0,0,0,0,0>>,
            gen_tcp:send(Connection, Resp),

            % RestLen = byte_size(Data) - 4,
            <<Ver, Cmd, Rsv, Atype, Rest/bitstring>> = Data,
            if 
                Atype == 1 ->
                    <<A1,A2,A3,A4,Port:16>> = Rest,
                    % 模式匹配
                    Ip = lists:flatten(io_lib:format("~p.~p.~p.~p",[A1,A2,A3,A4])),
                    io:format("Ver:~w Cmd:~w Rsv:~w Atype:~w IP:~p Port:~w \n",[Ver, Cmd, Rsv, Atype, Ip, Port]),
                    create_tunnel(Connection, Ip, Port);
                Atype == 3 ->
                    <<Len, HostBinary:Len/bytes, Port:16>> = Rest,
                    Host = binary_to_list(HostBinary),
                    io:format("Ver:~w Cmd:~w Rsv:~w Atype:~w Host:~p Port:~w \n",[Ver, Cmd, Rsv, Atype, Host, Port]),
                    create_tunnel(Connection, Host, Port);

                true ->
                    io:format("非法类型!\n")
            end;


	    {tcp_closed, Connection} ->
            gen_tcp:close(Connection),
	        io:format("Connection closed ~p~n", [Connection])
    end.

echo_loop(Connection) ->
    receive
        {tcp, Connection, Data} ->
            % <<Ver, Nmethods,_/bitstring>> = Data,
            % io:format("Ver:~p, method count:~p\n",[Ver, Nmethods]),
            Resp = <<5,0>>,
            gen_tcp:send(Connection, Resp),
            request(Connection);
	    {tcp_closed, Connection} ->
            gen_tcp:close(Connection),
            io:format("Connection closed ~p~n", [Connection])
    end.

