defmodule Game do
  @callback display_cell(atom) :: none
  @callback invert(atom) :: atom
  @callback play(term, integer) :: term
  @callback winner(term) :: boolean
  @callback max_choice :: integer
end
