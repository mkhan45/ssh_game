defmodule TTT do
  defstruct [
    board: :array.new(size: 9, default: :empty),
    current_player: :x,
  ]

  def invert(:x), do: :o
  def invert(:o), do: :x

  def play(game, move) do
    if :array.get(move, game.board) == :empty do
      new_board = %TTT {
        board: :array.set(move, game.current_player, game.board),
        current_player: invert(game.current_player),
      }

      new_board
    else
      # don't change the game if it's an invalid move,
      # this will prompt the correct player again, since
      # current_player is unchanged
      game
    end
  end

  def display_cell(:empty), do: "_"
  def display_cell(:x), do: "X"
  def display_cell(:o), do: "O"

  def display(%TTT{board: board, current_player: p}) do
    display(board) <> "\n#{display_cell(p)}'s Turn"
  end

  def display(board) do
    board 
    |> :array.to_list 
    |> Enum.chunk_every(3)
    |> Enum.map(fn row -> Enum.map(row, &display_cell/1) end)
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.join("\n")
  end

  def inspect(game) do
    IO.puts(game |> display())
    game
  end

  def draw(game) do
    game.board |> :array.to_list |> Enum.count(& &1 != :empty) == 9
  end

  def winner(game) do
    board = :array.to_list(game.board)

    rows = board |> Enum.chunk_every(3)
    cols = 0..2 |> Enum.map(& board |> Enum.drop(&1) |> Enum.take_every(3))
    ldiag = 0..2 |> Enum.map(& :array.get(&1 * 4, game.board))
    rdiag = 0..2 |> Enum.map(& :array.get(2 + &1 * 2, game.board))

    [rows, cols, [ldiag, rdiag]]
    |> Enum.concat
    |> Enum.any?(fn group -> 
      (Enum.count(group, & &1 == :x) == 3) || (Enum.count(group, & &1 == :o) == 3)
    end)
  end
end
