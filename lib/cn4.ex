defmodule ConnectFour do
  @width 7
  @height 6

  defstruct [
    board: :array.new(size: @width * @height, default: :empty),
    current_player: :x,
  ]

  def invert(:x), do: :o
  def invert(:o), do: :x

  defp get(board, r, c), do: :array.get(r * @width + c, board)
  defp set(board, r, c, v), do: :array.set((r * @width + c), v, board)

  def nth_row(%ConnectFour{board: board}, n) do
    board |> :array.to_list() |> Enum.slice(n * @width, @width)
  end

  def nth_col(%ConnectFour{board: board}, n) do
    Enum.map(0..(@height-1), fn r -> board |> get(r, n) end)
  end

  def play(game, move) do
    col = nth_col(game, move)
    if List.first(col) != :empty do
      game
    else
      r = (col |> Enum.find_index(& &1 != :empty))
      r = (if r == nil, do: @height - 1, else: r - 1)

      %ConnectFour{
        board: game.board |> set(r, move, game.current_player),
        current_player: invert(game.current_player),
      }
    end
  end

  def display_cell(:empty), do: "."
  def display_cell(:x), do: "X"
  def display_cell(:o), do: "O"

  def display(%ConnectFour{board: board, current_player: p}) do
    display(board) <> "\r\n#{display_cell(p)}'s Turn"
  end

  def display(board) do
    (0..(@width - 1) |> Enum.join(" ")) <> "\n"
    <>
    (board 
    |> :array.to_list 
    |> Enum.chunk_every(@width)
    |> Enum.map(fn row -> Enum.map(row, &display_cell/1) end)
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.join("\r\n"))
    <> "\n" <>
    (0..(@width - 1) |> Enum.join(" "))
  end

  def inspect(game) do
    IO.puts(game |> display())
    game
  end

  def draw(game) do
    game.board |> :array.to_list |> Enum.count(& &1 != :empty) == @width * @height
  end

  def winner(game) do
    board = :array.to_list(game.board)

    rows = board |> Enum.chunk_every(@width)
    cols = 0..(@width - 1) |> Enum.map(& nth_col(game, &1))

    ldiags =
      for r <- 0..2, c <- 0..3 do
        ((r * @width + c)..(@width * @height - 1) // 8)
        |> Enum.map(& :array.get(&1, game.board))
      end

    rdiags =
      for r <- 0..2, c <- 3..(@width - 1) do
        ((r * @width + c)..(@width * @height - 1) // 6)
        |> Enum.map(& :array.get(&1, game.board))
      end

    [rows, cols, ldiags, rdiags]
    |> Enum.concat()
    |> Enum.map(& Enum.chunk_every(&1, 4, 1))
    |> Enum.concat()
    |> Enum.any?(fn group -> 
      (Enum.count(group, & &1 == :x) == 4) || (Enum.count(group, & &1 == :o) == 4)
    end)
  end
end
