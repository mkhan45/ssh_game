defmodule GameMod do
  defmacro __using__(mod: game) do
    quote do
      @game unquote(game)
      @max_choice unquote(game).max_choice

      def init_state() do
        %unquote(game){}
      end
    end
  end
end

defmodule RoomStore do
  use GameMod, mod: ConnectFour

  def init() do
    IO.puts("Initializing RoomStore")
    :ets.new(:games, [:named_table, :public]) |> IO.inspect()
  end

  def add_game(id, pid) do
    game = %{state: init_state(), x: pid, o: nil}

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
  use GameMod, mod: ConnectFour

  defstruct status: :lobby

  def prompt_room(%Client{status: creating_or_joining} = client) do
    resp = IO.gets("Room # (0 to go back): ") |> to_string() |> String.trim() |> Integer.parse()
    case resp do
      {0, ""} ->
        choose_room(%Client{status: :lobby})

      {room_no, ""} ->
        case {RoomStore.game_exists(room_no), creating_or_joining} do
          {false, :joining} ->
            IO.puts("Room #{room_no} does not exist")
            prompt_room(client)

          {true, :joining} ->
            IO.puts("Joined room #{room_no}")
            {room_no, :joining}

          {false, :creating} ->
            IO.puts("Created room #{room_no}, waiting for other player")
            {room_no, :creating}

          {true, :creating} ->
            IO.puts("Room #{room_no} already exists")
            prompt_room(client)
        end

      _ ->
        IO.puts("Please enter a valid number")
        prompt_room(client)
    end
  end

  def choose_room(%Client{status: :lobby} = client) do
    rooms = :ets.tab2list(:games) 
            |> Stream.filter(fn {_, %{o: o}} -> o == nil end) 
            |> Stream.map(fn {id, _} -> id end)

    IO.puts(
      "Available Rooms:\r\n" <>
      "#{rooms |> Enum.join("\r\n")}\r\n"
    )

    resp = IO.gets(
      "1) Join a game\r\n" <>
      "2) Create a game\r\n" <>
      "> "
    ) |> to_string() |> String.trim() |> Integer.parse()

    case resp do
      {1, ""} -> prompt_room(%Client{status: :joining})
      {2, ""} -> prompt_room(%Client{status: :creating})
      _ ->
        IO.puts("Please enter either 1 or 2")
        choose_room(client)
    end
  end

  def prompt_move(player) do
    resp = IO.gets("Move for #{@game.display_cell(player)}: ")
    case resp do
      {:error, _} -> 
        :error
      _ ->
        case Integer.parse(resp |> to_string() |> String.trim()) do
          {move, ""} when 0 <= move and move <= @max_choice ->
            move

          _ ->
            IO.puts("Please enter an index from 0 to #{@max_choice}.")
            prompt_move(player)
        end
    end
  end

  defp game_loop(player, id) do
    receive do
      :error ->
        IO.puts("Game error, other player left?")
        RoomStore.remove_game(id)

      game ->
        IO.puts(game |> @game.display())

        cond do
          @game.winner(game) ->
            IO.puts("#{@game.display_cell(game.current_player |> @game.invert())} wins!")
            RoomStore.remove_game(id)

          @game.draw(game) ->
            IO.puts("Draw game")
            RoomStore.remove_game(id)

          game.current_player == player ->
            case prompt_move(player) do
              :error ->
                IO.puts("Exiting game")
                RoomStore.remove_game(id)
                for pid <- RoomStore.players(id) do
                  send(pid, :error)
                end
                Process.exit(self(), 0)
              move ->
                new_game_state = @game.play(game, move)
                for pid <- RoomStore.players(id) do
                  send(pid, new_game_state)
                end
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
      # auth_methods: 'none',
      auth_method_kb_interactive_data: {'SSH Connect 4', 'Enter Username', 'Username: ', true},
      pwdfun: fn _, _ -> true end,
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
