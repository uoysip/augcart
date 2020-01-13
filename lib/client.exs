defmodule Client do

  def run(args) do
    [server | tail] = args
    pid = locate_server(server)

    case pid do
      nil -> 
        IO.puts("Unable to connect to server.  Is it running?")
      pid ->
        execute_command([pid | tail])
    end

  end

  defp locate_server(server) do
    String.to_atom(server) 
    |> :rpc.call(Process, :whereis, [:server])
  end

  defp execute_command([server, "users"]) do
    send(server, {self(), :list_users})

    receive do
      {_pid, :ok, list} ->
        list |> Enum.join("\n") |> IO.puts
      _ ->
        IO.puts("Unknown response received")
    end

  end

  defp execute_command([server, "user", "add", username, password]) do
    send(server, {self(), :new_user, username, password})

    receive do
      {_pid, :ok, message} ->
        IO.puts(message)
      {_pid, :error, reason} ->
        IO.puts("Error: #{reason}")
      _ ->
        IO.puts("Unknown response received")
    end
  end

  defp execute_command([server, "list", "add", username, password, item]) do
    send(server, {self(), :add_item, username, password, item})

    receive do
      {_pid, :ok, message} ->
        IO.puts(message)
      {_pid, :error, reason} ->
        IO.puts("Error: #{reason}")
      _ ->
        IO.puts("Unknown response received")
    end

  end

  defp execute_command([server, "list", "del", username, password, item]) do
    send(server, {self(), :delete_item, username, password, item})

    receive do
      {_pid, :ok, message} ->
        IO.puts(message)
      {_pid, :error, reason} ->
        IO.puts("Error: #{reason}")
      _ ->
        IO.puts("Unknown response received")
    end
  end

  defp execute_command([server, "list", username, password]) do
    send(server, {self(), :shopping_list, username, password})

    receive do
      {_pid, :ok, items} ->
        items |> Enum.join("\n") |> IO.puts
      {_pid, :error, reason} ->
        IO.puts("Error: #{reason}")
      _ ->
        IO.puts("Unknown response received")
    end
  end

  defp execute_command([server, "clear"]) do
    send(server, {self(), :clear})

    receive do
      {_pid, :ok, message} ->
        IO.puts(message)
      _ ->
        IO.puts("Unknown response received")
    end
  end

  defp execute_command([server, "shutdown"]) do
    send(server, {self(), :exit})
    IO.puts("Server shutdown command sent")
  end

  defp execute_command(_) do

    IO.puts "Usage: ./client [COMMAND] [PARAMS]"
    IO.puts ""
    IO.puts "Commands"
    IO.puts ""
    IO.puts "  clear                      - Clear all data on the server"
    IO.puts "  list add USER PASS ITEM    - Add ITEM to USER shopping list"
    IO.puts "  list del USER PASS ITEM    - Remove ITEM from USER shopping list"
    IO.puts "  list USER PASS             - Show list for USER"
    IO.puts "  shutdown                   - Shut down the server"
    IO.puts "  user add USER PASS         - Add new user"
    IO.puts "  users                      - List users"
  end

end

Client.run(System.argv)
