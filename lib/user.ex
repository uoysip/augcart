defmodule User do
  @enforce_keys [:username, :password]
  defstruct [:username, :password]
end
