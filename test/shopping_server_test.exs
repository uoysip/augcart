defmodule ShoppingListServerTest do

  use ExUnit.Case
  doctest ShoppingListServer

  describe "ShoppingListServer" do

    setup [:start_server, :flush_messages]

    test "stays alive after being spawned", ctx do
      Process.sleep(100)
      assert Process.alive?(ctx.pid)
    end

  end

  describe ":new_user when the user does not exist" do

    setup [:start_server, :flush_messages, :generate_random_data]

    test "returns the correct response", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      add_user(ctx.pid, username, password)

    end

    test "updates the list of users", ctx do
      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, []}, 10000

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      add_user(ctx.pid, username, password)

      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, [^username]}, 10000

    end

    test "persists to disk", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      add_user(ctx.pid, username, password)

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :new_user, username, password})
      assert_receive {pid, :error, "User already exists"}, 10000

    end

  end

  describe ":new_user when the user already exists" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users]

    test "returns the correct response", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword

      send(ctx.pid, {self(), :new_user, username, password})
      assert_receive {pid, :error, "User already exists"}, 10000
    end

    test "does not update the list of users", ctx do

      expected = ctx[:users] |> Enum.map(&(&1[:username])) |> Enum.sort

      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, ^expected}, 10000

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      send(ctx.pid, {self(), :new_user, username, password})
      assert_receive {pid, :error, "User already exists"}, 10000

      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, ^expected}, 10000

    end

    test "does not persist to disk", ctx do
      expected = ctx[:users] |> Enum.map(&(&1[:username])) |> Enum.sort

      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, ^expected}, 10000

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      send(ctx.pid, {self(), :new_user, username, password})
      assert_receive {pid, :error, "User already exists"}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :list_users})
      assert_receive {pid, :ok, ^expected}, 10000
    end

  end

  describe ":list_users when no users are present" do

    setup [:start_server, :flush_messages, :generate_random_data]

    test "returns an empty list", ctx do
      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, []}, 10000
    end

  end

  describe ":list_users when users are present" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users]

    test "returns a sorted list of users when non-empty", ctx do
      send(ctx.pid, {self(), :list_users})
      expected = ctx[:users] |> Enum.map(&(&1[:username])) |> Enum.sort
      assert_receive {pid, :ok, ^expected}, 10000
    end

  end

  describe ":shopping_list with valid credentials and an empty list" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users]

    test "returns an empty list", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, []}, 10000
    end

  end

  describe ":shopping_list with valid credentials and a non-empty list" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the user's list", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      items = ctx |> user1 |> items |> Enum.sort

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^items}, 10000
    end

  end

  describe ":shopping_list with invalid credentials" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do
      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword) <> "1"

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :error, "Authentication failed"}, 10000
    end

  end

  describe ":shopping_list with a non-existent user" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do
      send(ctx.pid, {self(), :shopping_list, "joe", "password"})
      assert_receive {pid, :error, "Authentication failed"}, 10000
    end

  end

  describe ":add_item with valid credentials and a non-existent item" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users]

    test "returns the correct response", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1

      add_item(ctx.pid, username, password, item)

    end

    test "updates the user's list", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1

      add_item(ctx.pid, username, password, item)

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, [^item]}, 10000

    end

    test "persists to disk", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1

      add_item(ctx.pid, username, password, item)

      pid2 = restart_server(ctx.pid)
      msg = "Item '#{item}' already exists"

      send(pid2, {self(), :add_item, username, password, item})
      assert_receive {pid, :error, ^msg}, 10000
    end

  end

  describe ":add_item with valid credentials and an existing item" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1

      msg = "Item '#{item}' already exists"

      send(ctx.pid, {self(), :add_item, username, password, item})
      assert_receive {pid, :error, ^msg}, 10000
    end

    test "does not update the user's list", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1
      items = ctx |> user1 |> items |> Enum.sort

      msg = "Item '#{item}' already exists"

      send(ctx.pid, {self(), :add_item, username, password, item})
      assert_receive {pid, :error, ^msg}, 10000

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^items}, 10000
    end

    test "does not persist to disk", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1
      items = ctx |> user1 |> items |> Enum.sort

      msg = "Item '#{item}' already exists"

      send(ctx.pid, {self(), :add_item, username, password, item})
      assert_receive {pid, :error, ^msg}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^items}, 10000
    end

  end

  describe ":add_item with invalid credentials" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users]

    test "returns the correct response", ctx do
      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword) <> "1"
      item = ctx |> user1 |> item1

      send(ctx.pid, {self(), :add_item, username, password, item})
      assert_receive {pid, :error, "Authentication failed"}, 10000
    end

    test "does not update the user's list", ctx do
      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword)
      item = ctx |> user1 |> item1

      send(ctx.pid, {self(), :add_item, username, password <> "1", item})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, []}, 10000
    end

    test "does not persist to disk", ctx do
      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword)
      item = ctx |> user1 |> item1

      send(ctx.pid, {self(), :add_item, username, password <> "1", item})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, []}, 10000
    end

  end

  describe ":add_item with a non-existent user" do

    setup [:start_server, :flush_messages, :generate_random_data]

    test "returns the correct response", ctx do
      send(ctx.pid, {self(), :add_item, "joe", "password", "item"})
      assert_receive {pid, :error, "Authentication failed"}, 10000
    end

    test "does not update the list of users", ctx do
      send(ctx.pid, {self(), :add_item, "joe", "password", "item"})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, []}, 10000
    end

    test "does not persist to disk", ctx do
      send(ctx.pid, {self(), :add_item, "joe", "password", "item"})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :list_users})
      assert_receive {pid, :ok, []}, 10000
    end

  end

  describe ":delete_item with valid credentials and an existing item" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1

      msg = "Item '#{item}' deleted from shopping list"

      send(ctx.pid, {self(), :delete_item, username, password, item})
      assert_receive {pid, :ok, ^msg}, 10000

    end

    test "removes the item from the user's list", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1

      expected = (ctx |> user1 |> items |> Enum.sort) -- [item]

      send(ctx.pid, {self(), :delete_item, username, password, item})
      assert_receive {pid, :ok, _}, 10000

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^expected}, 10000

    end

    test "persists to disk", ctx do

      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      item = ctx |> user1 |> item1

      expected = (ctx |> user1 |> items |> Enum.sort) -- [item]

      send(ctx.pid, {self(), :delete_item, username, password, item})
      assert_receive {pid, :ok, _}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^expected}, 10000
    end

  end

  describe ":delete_item with valid credentials and a non-existent item" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword

      send(ctx.pid, {self(), :delete_item, username, password, "apples"})
      assert_receive {pid, :error, "Item 'apples' not found"}, 10000
    end

    test "does not modify the user's list", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      expected = (ctx |> user1 |> items |> Enum.sort)

      send(ctx.pid, {self(), :delete_item, username, password, "apples"})
      assert_receive {pid, :error, "Item 'apples' not found"}, 10000

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^expected}, 10000
    end

    test "does not persist to disk", ctx do
      username = ctx |> user1 |> uname
      password = ctx |> user1 |> pword
      expected = (ctx |> user1 |> items |> Enum.sort)

      send(ctx.pid, {self(), :delete_item, username, password, "apples"})
      assert_receive {pid, :error, "Item 'apples' not found"}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^expected}, 10000
    end

  end

  describe ":delete_item with invalid credentials" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do
      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword) <> "1"
      item = ctx |> user1 |> item1

      send(ctx.pid, {self(), :delete_item, username, password, item})
      assert_receive {pid, :error, "Authentication failed"}, 10000
    end

    test "does not modify the user's list", ctx do
      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword)
      item = ctx |> user1 |> item1
      expected = (ctx |> user1 |> items |> Enum.sort)

      send(ctx.pid, {self(), :delete_item, username, password <> "1", item})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^expected}, 10000
    end

    test "does not persist to disk", ctx do
      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword)
      item = ctx |> user1 |> item1
      expected = (ctx |> user1 |> items |> Enum.sort)

      send(ctx.pid, {self(), :delete_item, username, password <> "1", item})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^expected}, 10000
    end

  end

  describe ":delete_item with a non-existent user" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do
      send(ctx.pid, {self(), :delete_item, "joe", "password", "item"})
      assert_receive {pid, :error, "Authentication failed"}, 10000
    end

    test "does not modify the user list", ctx do
      send(ctx.pid, {self(), :delete_item, "joe", "password", "item"})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      send(ctx.pid, {self(), :list_users})
      expected = ctx[:users] |> Enum.map(&(&1[:username])) |> Enum.sort
      assert_receive {pid, :ok, ^expected}, 10000
    end

    test "does not persist to disk", ctx do
      send(ctx.pid, {self(), :delete_item, "joe", "password", "item"})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :list_users})
      expected = ctx[:users] |> Enum.map(&(&1[:username])) |> Enum.sort
      assert_receive {pid, :ok, ^expected}, 10000
    end

  end

  describe ":clear" do

    setup [:start_server, :flush_messages, :generate_random_data, :add_users, :add_items]

    test "returns the correct response", ctx do
      send(ctx.pid, {self(), :clear})
      assert_receive {pid, :ok, "All data cleared"}, 10000
    end

    test "deletes all users", ctx do
      send(ctx.pid, {self(), :list_users})
      expected = ctx[:users] |> Enum.map(&(&1[:username])) |> Enum.sort
      assert_receive {pid, :ok, ^expected}, 10000

      send(ctx.pid, {self(), :clear})
      assert_receive {pid, :ok, "All data cleared"}, 10000

      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, []}, 10000
    end

    test "ensures a user's list is deleted, even if the user is added back", ctx do

      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword)
      items = ctx |> user1 |> items |> Enum.sort

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^items}, 10000

      send(ctx.pid, {self(), :clear})
      assert_receive {pid, :ok, "All data cleared"}, 10000

      send(ctx.pid, {self(), :list_users})
      assert_receive {pid, :ok, []}, 10000

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      add_user(ctx.pid, username, password)

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, []}, 10000

    end

    test "persists to disk", ctx do

      username = ctx |> user1 |> uname
      password = (ctx |> user1 |> pword)
      items = ctx |> user1 |> items |> Enum.sort

      send(ctx.pid, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, ^items}, 10000

      send(ctx.pid, {self(), :clear})
      assert_receive {pid, :ok, "All data cleared"}, 10000

      pid2 = restart_server(ctx.pid)

      send(pid2, {self(), :list_users})
      assert_receive {pid, :ok, []}, 10000

      send(pid2, {self(), :shopping_list, username, password})
      assert_receive {pid, :error, "Authentication failed"}, 10000

      add_user(pid2, username, password)

      send(pid2, {self(), :shopping_list, username, password})
      assert_receive {pid, :ok, []}, 10000

    end

  end

  describe ":exit" do
    setup [:start_server, :flush_messages]

    test "terminates the ShoppingListServer process", ctx do
      assert Process.alive?(ctx[:pid])

      send(ctx[:pid], {self(), :exit})
      Process.sleep(100)

      refute Process.alive?(ctx[:pid])
    end
  end

  defp generate_random_data(_ctx) do
    users = 1..100000
            |> Enum.shuffle
            |> Enum.take(5)
            |> Enum.map(&(
              [
                username: "user#{&1}",
                password: "pass#{&1}",
                items: 1..100000 
                |> Enum.shuffle 
                |> Enum.take(3) 
                |> Enum.map(fn (i) -> "item#{i}" end)
              ]))

    {:ok, [users: users]}
  end

  defp start_server(_ctx) do
    try do
      Process.unregister(:server)
    rescue
      _ -> nil
    end

    pid = spawn(ShoppingListServer, :start, [])
    send(pid, {self(), :clear})

    receive do
      {pid, :ok, "All data cleared"} -> {:ok, [pid: pid]}
        #assert_receive {pid, :ok, "All data cleared"}, 10000
    end

    #{:ok, [pid: pid]}
  end

  defp flush_messages(ctx) do
    receive do
      _ -> flush_messages(ctx)
    after 
      100 -> :ok
    end
  end

  defp add_user(svr, username, password) do
    send(svr, {self(), :new_user, username, password})
    assert_receive {svr, :ok, "User created successfully"}, 10000
  end

  defp add_item(svr, username, password, item) do
    send(svr, {self(), :add_item, username, password, item})
    msg = "Item '#{item}' added to shopping list"
    assert_receive {svr, :ok, ^msg}, 10000
  end

  defp add_users(ctx) do
    ctx[:users] 
    |> Enum.each(&add_user(ctx[:pid], &1[:username], &1[:password]))
    :ok
  end

  defp add_items(ctx) do
    ctx[:users] 
    |> Enum.each(fn u ->
      Enum.each(u[:items], &add_item(ctx[:pid], u[:username], u[:password], &1)) end)
    :ok
  end

  defp restart_server(pid) do
    Process.exit(pid, :kill)
    spawn(ShoppingListServer, :start, [])
  end

  def user1(ctx), do: ctx.users |> Enum.at(0)
  defp uname([username: un, password: _, items: _]), do: un
  defp pword([username: _, password: pw, items: _]), do: pw
  defp items([username: _, password: _, items: list]), do: list
  defp item1([username: _, password: _, items: list]), do: Enum.at(list, 0)

end
