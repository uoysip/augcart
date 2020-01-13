import User

defmodule UserStore do

  # Path to the user database file
  # Don't forget to create this directory if it doesn't exist
  @database_directory "db"

  # Name of the user database file
  @user_database "users.txt"

  # Note: you will spawn a process to run this store in
  # ShoppingListServer.  You do not need to spawn another process here
  def start() do
    
    # verify that the file exists
    unless File.exists?(user_database()) do
      File.touch(user_database())
    end

    loop()
  end

  defp loop() do
    # always check if the directory exists
    unless File.dir?(@database_directory) do 
      File.mkdir_p(@database_directory)
    end

    receive do
      # clear all shopping lists
      {caller, :clear} ->
        clear(caller)
        loop()

      # list usernames in the database
      {caller, :list} ->
        list(caller)
        loop()

      #add user
      {caller, :add, username, password} ->
        add(caller, username, password)
        loop()

      #authenticate user
      {caller, :authenticate, username, password} ->
        authenticate(caller, username, password)
        loop()

      #exit
      {caller, :exit} ->
        exit() # unnecessary i think

      # Always handle unmatched messages
      # Otherwise, they queue indefinitely
      _ ->
        loop()
    end 

  end

  # Path to the user database
  defp user_database(), do: Path.join(@database_directory, @user_database)

  # Use this function to hash your passwords
  defp hash_password(password) do
    hash = :crypto.hash(:sha256, password)
    Base.encode16(hash)
  end

  defp clear(caller) do
    File.rm_rf @database_directory
    send(caller, {self(), :cleared})
  end

  defp exit() do
    IO.puts("UserStore shutting down")
    Process.exit(self(), :normal)
  end
  
  # db/users.txt 
  defp list(caller) do
    unless File.exists?(user_database()) do
      File.touch(user_database())
      send(caller, {self(), :user_list, []})
    else
      # file = File.read!(user_database())
      # list = Enum.sort(List.delete(Enum.take_every(String.split(file, [":","\n"]), 2), ""))

      list = user_database()
        |> File.read!
        |> String.split([":","\n"])
        |> Enum.take_every(2)
        |> List.delete("")
        |> Enum.sort


      send(caller, {self(), :user_list, list})
    end
  end

  defp add(caller, username, password) do
    user = %User{username: username, password: hash_password(password)}

    # if the file doesnt exist
    unless File.exists?(user_database()) do
      File.write(user_database(), "#{user.username}:#{user.password}\n")
      send(caller, {self(), :added, user})
    else
      # split into a list, by newline
      list = user_database()
        |> File.read!
        |> String.split("\n")

      # if item exists then return
      if Enum.member?(list, "#{user.username}:#{user.password}") do
        send(caller, {self(), :error, "User already exists"})
      else
        listString = list
          |> List.insert_at(0, "#{user.username}:#{user.password}")
          |> Enum.join("\n")

        File.rm(user_database())
        File.write(user_database(), listString)
        send(caller, {self(), :added, user})
      end
    end
  end


  defp authenticate(caller, username, password) do
    user = %User{username: username, password: hash_password(password)}

    unless File.exists?(user_database()) do # if the file doesnt exist
      File.touch(user_database())
      send(caller, {self(), :auth_failed, username})
    else
      list = user_database()
        |> File.read!
        |> String.split("\n")

      if Enum.member?(list, "#{user.username}:#{user.password}") do
        send(caller, {self(), :auth_success, username})
      else
        send(caller, {self(), :auth_failed, username})
      end
    end

  end

end
