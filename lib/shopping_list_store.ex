defmodule ShoppingListStore do

  # Path to the shopping list files (db/lists/*)
  # Don't forget to create this directory if it doesn't exist
  @database_directory Path.join("db", "lists")

  # Note: you will spawn a process to run this store in
  # ShoppingListServer.  You do not need to spawn another process here
  def start() do
    # Call your receive loop
    loop()
  end

  defp loop() do

    # always check for directory existence, as it may be deleted through the tests
    unless File.dir?(@database_directory) do 
      File.mkdir_p(@database_directory)
    end

    receive do

      # clear all shopping lists
      {caller, :clear} ->
        clear(caller)
        loop()

      # list items under username
      {caller, :list, username} ->
        list(caller, username)
        loop()

      # add item
      {caller, :add, username, item} ->
        add(caller, username, item)
        loop()

      # delete item
      {caller, :delete, username, item} ->
        delete(caller, username, item)
        loop()

      # exit
      {caller, :exit} ->
        exit()

      # Always handle unmatched messages
      # Otherwise, they queue indefinitely
      _ ->
        loop()
    end   
  end

  # Implemented for you
  defp clear(caller) do
    File.rm_rf @database_directory
    send(caller, {self(), :cleared})
  end

  defp exit() do
    IO.puts("ShoppingListStore shutting down")
  end

  # return a sorted list of items from the file
  defp list(caller, username) do
    unless File.exists?(user_db(username)) do
      File.touch(user_db(username))
      send(caller, {self(), :list, username, []})
    else
      # read contents of file, split into a list by new line, then return the sorted list
      file = File.read!(user_db(username))
      list = List.delete(Enum.sort(String.split(file, "\n")), "")
      send(caller, {self(), :list, username, list})
    end
  end

  # add the item to the users  shopping list
  defp add(caller, username, item) do
    # if file does not exist, create it and add the item
    unless File.exists?(user_db(username)) do
        File.touch(user_db(username))
        File.write(user_db(username), "#{item}\n")
        send(caller, {self(), :added, username, item})
    else  # if the file does exist
        list = user_db(username)
          |> File.read!
          |> String.split("\n")

        # if item exists then return as :exists
        if Enum.member?(list, item) do
          send(caller, {self(), :exists, username, item})
        else # add it if it does not exist
          listString = List.insert_at(list, 0, item)
            |> Enum.join("\n")

          File.rm(user_db(username))
          File.write(user_db(username), listString)
          send(caller, {self(), :added, username, item})
        end
      end
  end

  # read contents, split into a list, check if exists with Enum.member? then delete with List.delete
  defp delete(caller, username, item) do
    if !File.exists?(user_db(username)) do
      send(caller, {self(), :not_found, username, item})
    else
        list = user_db(username)
          |> File.read!
          |> String.split("\n")

      #if item exists then delete
      if Enum.member?(list, item) do
        listString = List.delete(list, item)
          |> Enum.join("\n")
          
        File.rm(user_db(username))
        File.write(user_db(username), listString)
        send(caller, {self(), :deleted, username, item})
      else
        send(caller, {self(), :not_found, username, item})
      end
    end

  end

  # Path to the shopping list file for the specified user
  # (db/lists/USERNAME.txt)
  defp user_db(username), do: Path.join(@database_directory, "#{username}.txt")

end
