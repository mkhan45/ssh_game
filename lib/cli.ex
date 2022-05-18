defmodule CLI do
  defmacro loop(do: body) do
    quote do
      try do
        for _ <- Stream.repeatedly(fn -> nil end) do
            unquote(body)
        end
      catch
        :break -> :ok
      end
    end
  end

  def run_game(game) do
    IO.puts(game |> TTT.display())

    if TTT.winner(game) do
      winner = game.current_player |> TTT.invert() |> TTT.display_cell()
      IO.puts("#{winner} wins!")
    else
      move = IO.gets("Move for #{TTT.display_cell(game.current_player)}: ")
      case Integer.parse(move |> String.trim()) do
        {move, ""} when 0 <= move and move <= 8 -> 
          run_game(game |> TTT.play(move))

        _ ->
          IO.puts("Please enter an index from 0 to 8.")
          run_game(game)
      end
    end
  end

  def run() do
    IO.puts("Starting Game")
    loop do
      run_game(%TTT{})

      if IO.gets("Play Again? (Y/N)\r\n") |> String.trim() |> String.upcase() == "N" do
        throw :break
      end
    end
  end
end

defmodule Mix.Tasks.Cli do
  use Mix.Task

  @impl true
  def run(_args) do
    CLI.run()
  end
end
