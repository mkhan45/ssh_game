defmodule RoomStore do
  def init() do
    IO.puts("Initializing RoomStore")
    :ets.new(:games, [:named_table, :public]) |> IO.inspect()
  end

  def add_game(id, pid) do
    game = %{state: %TTT{}, x: pid, o: nil}

    :ets.insert(
      :games, 
      {id, game}
    )
  end

  def remove_game(id) do
    :ets.delete(:games, id)
  end

  def add_player(id, pid) do
    [{_, game}] = :ets.lookup(:games, id)

    :ets.insert(
      :games,
      {id, Map.put(game, :o, pid)}
    )

    for pid <- players(id) do
      send(pid, game.state)
    end
  end

  def game_exists(id) do
    :ets.lookup(:games, id) != []
  end

  def players(id) do
    [{_, %{state: _, x: x, o: o}}] = :ets.lookup(:games, id)
    [x, o]
  end
end

defmodule Client do
  defstruct status: :lobby

  def prompt_room(%Client{status: :lobby} = client, creating_or_joining) do
    resp = IO.gets("Room # (0 to go back): ") |> to_string() |> String.trim() |> Integer.parse()
    case resp do
      {0, ""} ->
        choose_room(client)

      {room_no, ""} ->
        case {RoomStore.game_exists(room_no), creating_or_joining} do
          {false, :joining} ->
            IO.puts("Room #{room_no} does not exist")
            prompt_room(client, :joining)

          {true, :joining} ->
            IO.puts("Joined room #{room_no}")
            {room_no, :joining}

          {false, :creating} ->
            IO.puts("Created room #{room_no}, waiting for other player")
            {room_no, :creating}

          {true, :creating} ->
            IO.puts("Room #{room_no} already exists")
            prompt_room(client, :creating)
        end

      _ ->
        IO.puts("Please enter a valid number")
        prompt_room(client, creating_or_joining)
    end
  end

  def choose_room(%Client{status: :lobby} = client) do
    resp = IO.gets(
      "1) Join a game\n" <>
      "2) Create a game\n" <>
      "> "
    ) |> to_string() |> String.trim() |> Integer.parse()

    case resp do
      {1, ""} -> prompt_room(client, :joining)
      {2, ""} -> prompt_room(client, :creating)
      _ ->
        IO.puts("Please enter either 1 or 2")
        choose_room(client)
    end
  end

  def prompt_move(player) do
    move = IO.gets("Move for #{TTT.display_cell(player)}: ") |> to_string()
    case Integer.parse(move |> String.trim()) do
      {move, ""} when 0 <= move and move <= 8 ->
        move

      _ ->
        IO.puts("Please enter an index from 0 to 8.")
        prompt_move(player)
    end
  end

  defp game_loop(player, id) do
    receive do
      game ->
        IO.puts(game |> TTT.display())

        cond do
          TTT.winner(game) ->
            IO.puts("#{TTT.display_cell(game.current_player |> TTT.invert())} wins!")
            RoomStore.remove_game(id)

          TTT.draw(game) ->
            IO.puts("Draw game")
            RoomStore.remove_game(id)

          game.current_player == player ->
            move = prompt_move(player)
            new_game_state = TTT.play(game, move)
            for pid <- RoomStore.players(id) do
              send(pid, new_game_state)
            end
            game_loop(player, id)

          true ->
            game_loop(player, id)
        end
    end
  end

  def start_game_loop(:x, id) do
    RoomStore.add_game(id, self())
    game_loop(:x, id)
  end

  def join_game(id) do
    RoomStore.add_player(id, self())
    game_loop(:o, id)
  end
end

defmodule SSHServer do
  @behaviour :ssh_server_channel

  @impl true
  def init(_args) do
    {:ok, %{}}
  end

  @impl true
  def handle_msg(_msg, state) do
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _cm, {:data, _channel_id, _data_type, data}}, state) do
    send(state.port, {self(), {:command, data}})
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _cm, {:eof, _channel_id}}, state) do
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _cm, {:shell, _channel_id, _}}, state) do
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:pty, channel_id, _, _}}, state) do
    :ssh_connection.send(conn, channel_id, 0, "authenticated")
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg(msg, state) do
    IO.inspect(msg)
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    nil
  end

  def on_shell(_username, _peer_address) do
    spawn(fn ->
      client = %Client{}
      case Client.choose_room(client) do
        {room_no, :creating} ->
          Client.start_game_loop(:x, room_no)

        {room_no, :joining} ->
          Client.join_game(room_no)
      end
    end)
  end

  def start(port) do
    {:ok, _sshd} = :ssh.daemon(
      port, 
      system_dir: 'ssh_dir', 
      password: '',
      shell: &on_shell/2
    )
  end
end

defmodule SSHServer.Application do
  use Application

  def start(_type, _args) do
    RoomStore.init()

    children = [{Task, fn -> SSHServer.start(4000) end}]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
