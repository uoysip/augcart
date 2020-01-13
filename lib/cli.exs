require Logger

defmodule CLI do

  def start() do
    Logger.info("Starting server.  Press Ctrl+C to exit...")

    Task.async(ShoppingListServer, :start, [])
    |> Task.await(:infinity)
  end

end

CLI.start()
