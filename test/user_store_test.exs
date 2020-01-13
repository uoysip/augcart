defmodule UserStoreTest do

  use ExUnit.Case
  doctest UserStore

  describe "UserStore" do

    setup [:start_user_store, :flush_messages]

    test "stays alive after being spawned", context do
      Process.sleep(100)
      assert Process.alive?(context[:pid])
    end

  end

  describe ":add when the user doesn't already exist" do

    setup [:start_user_store, :flush_messages]

    test "replies with the correct message", context do
      u = random_user()
      send(context[:pid], {self(), :add, u[:username], u[:password]})
      assert_receive {pid, :added, %User{}}, 10000
    end

    test "returns a user with the correct username", context do
      u = random_user()
      send(context[:pid], {self(), :add, u[:username], u[:password]})
      assert_receive {pid, :added, %User{username: actual}}, 10000

      assert actual == u[:username]
    end

    test "returns a user with the correct, hashed password", context do
      u = random_user()
      send(context[:pid], {self(), :add, u[:username], u[:password]})
      assert_receive {pid, :added, %User{password: actual}}, 10000

      expected = :crypto.hash(:sha256, u[:password]) |> Base.encode16
      assert actual == expected
    end

    test "persists to disk", context do
      u = random_user()

      send(context[:pid], {self(), :add, u[:username], u[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      Process.exit(context[:pid], :kill)
      pid2 = spawn(UserStore, :start, [])

      send(pid2, {self(), :add, u[:username], u[:password]})
      assert_receive {^pid2, :error, "User already exists"}, 10000
    end

  end

  describe ":add when the user already exists" do

    setup [:start_user_store, :flush_messages]

    test "replies with the correct message", context do
      u = random_user()

      send(context[:pid], {self(), :add, u[:username], u[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      send(context[:pid], {self(), :add, u[:username], u[:password]})
      assert_receive {pid, :error, "User already exists"}, 10000
    end

  end

  describe ":list" do

    setup [:start_user_store, :flush_messages]

    test "is initially empty", context do
      send(context[:pid], {self(), :list})
      assert_receive {pid, :user_list, []}, 10000
    end

    test "contains the correct data after a user is added", context do
      u = random_user()
      username = u[:username]

      send(context[:pid], {self(), :add, u[:username], u[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      send(context[:pid], {self(), :list})
      assert_receive {pid, :user_list, [^username]}, 10000
    end

    test "returns a sorted list of usernames", context do

      u1 = random_user()
      send(context[:pid], {self(), :add, u1[:username], u1[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      send(context[:pid], {self(), :add, "alice", "password"})
      assert_receive {pid, :added, %User{}}, 10000

      send(context[:pid], {self(), :add, "zane", "password"})
      assert_receive {pid, :added, %User{}}, 10000

      u2 = random_user()
      send(context[:pid], {self(), :add, u2[:username], u2[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      expected = Enum.sort([u1[:username], u2[:username], "alice", "zane"])

      send(context[:pid], {self(), :list})
      assert_receive {pid, :user_list, ^expected}, 10000

    end

    test "is persisted to disk", context do

      u1 = random_user()
      u2 = random_user()
      u3 = random_user()

      send(context[:pid], {self(), :list})
      assert_receive {pid, :user_list, []}, 10000

      send(context[:pid], {self(), :add, u1[:username], u1[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      send(context[:pid], {self(), :add, u2[:username], u2[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      send(context[:pid], {self(), :add, u3[:username], u3[:password]})
      assert_receive {pid, :added, %User{}}, 10000

      expected = Enum.sort([u1[:username], u2[:username], u3[:username]])

      send(context[:pid], {self(), :list})
      assert_receive {pid, :user_list, ^expected}, 10000

      Process.exit(context[:pid], :kill)

      pid = spawn(UserStore, :start, [])
      send(pid, {self(), :list})
      assert_receive {^pid, :user_list, ^expected}, 10000
    end

  end

  describe ":authenticate when the user exists and has the right credentials" do

    setup [:start_user_store, :add_users, :flush_messages]

    test "replies with the correct message", context do
      [[username: username, password: password] | _] = context[:users]

      send(context[:pid], {self(), :authenticate, username, password})
      assert_receive {pid, :auth_success, ^username}, 10000
    end

  end

  describe ":authenticate when the user exists but has the wrong credentials" do
    setup [:start_user_store, :add_users, :flush_messages]

    test "replies with the correct message", context do
      [[username: username, password: password] | _] = context[:users]

      send(context[:pid], {self(), :authenticate, username, password <> "1"})
      assert_receive {pid, :auth_failed, ^username}, 10000
    end
  end

  describe ":authenticate when the user does not exist" do
    setup [:start_user_store, :add_users, :flush_messages]

    test "replies with the correct message", context do
      [[username: _, password: password] | _] = context[:users]

      send(context[:pid], {self(), :authenticate, "joe", password})
      assert_receive {pid, :auth_failed, "joe"}, 10000
    end
  end

  describe ":exit" do
    setup [:start_user_store, :flush_messages]

    test "terminates the UserStore process", context do
      assert Process.alive?(context[:pid])

      send(context[:pid], {self(), :exit})
      Process.sleep(100)

      refute Process.alive?(context[:pid])
    end
  end

  defp random_user() do
    id = Enum.shuffle(1..100000) |> hd
    [username: "user#{id}", password: "pass#{id}"]
  end

  # Randomly generate 5 users of the form {"userXXXX", "passXXXX"}
  # to prevent hard-coding of server responses to pass tests
  defp add_users(context) do
    users = 1..100000 
            |> Enum.shuffle
            |> Enum.take(5)
            |> Enum.map(&(
              [
                username: "user#{&1}",
                password: "pass#{&1}"
              ]))

    users
    |> Enum.each(fn data ->
      send(context[:pid], {self(), :add, data[:username], data[:password]})
      assert_receive {pid, :added, _}, 10000
    end)

    {:ok, [users: users]}
  end

  defp start_user_store(_context) do
    pid = spawn(UserStore, :start, [])
    send(pid, {self(), :clear})
    assert_receive {pid, :cleared}, 10000

    {:ok, [pid: pid]}
  end

  defp flush_messages(context) do
    receive do
      _ -> flush_messages(context)
    after 
      100 -> :ok
    end
  end

end
