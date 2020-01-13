defmodule ShoppingListStoreTest do

  use ExUnit.Case
  doctest ShoppingListStore

  describe "ShoppingListStore" do

    setup [:start_list_store, :flush_messages]

    test "stays alive after being spawned", context do
      Process.sleep(100)
      assert Process.alive?(context[:pid])
    end

  end

  describe ":add when the item doesn't already exist" do

    setup [:start_list_store, :flush_messages]

    test "replies with the correct message", context do
      item = random_item()
      user = random_username()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, _, _}, 10000
    end

    test "replies with a message containing the correct username", context do
      item = random_item()
      user = random_username()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, _}, 10000
    end

    test "replies with a message containing the correct item", context do
      item = random_item()
      user = random_username()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, _, ^item}, 10000
    end

    test "persists changes to disk", context do
      u1 = random_username()
      i1 = random_item()
      u2 = random_username()
      i2 = random_item()

      send(context[:pid], {self(), :add, u1, i1})
      assert_receive {pid, :added, ^u1, ^i1}, 10000

      send(context[:pid], {self(), :add, u2, i2})
      assert_receive {pid, :added, ^u2, ^i2}, 10000

      Process.exit(context[:pid], :kill)
      pid2 = spawn(ShoppingListStore, :start, [])

      send(pid2, {self(), :add, u1, i1})
      assert_receive {^pid2, :exists, ^u1, ^i1}, 10000

      send(pid2, {self(), :add, u2, i2})
      assert_receive {^pid2, :exists, ^u2, ^i2}, 10000

    end

  end

  describe ":add when the item already exists" do

    setup [:start_list_store, :flush_messages]

    test "replies with the correct message", context do
      item = random_item()
      user = random_username()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, ^item}, 10000

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :exists, ^user, ^item}, 10000
    end

    test "does not add the item again", context do
      item = random_item()
      user = random_username()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, ^item}, 10000

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :exists, ^user, ^item}, 10000

      send(context[:pid], {self(), :list, user})
      assert_receive {pid, :list, ^user, [^item]}, 10000
    end

  end

  describe ":list" do

    setup [:start_list_store, :flush_messages]

    test "is initially empty", context do
      user = random_username()
      send(context[:pid], {self(), :list, user})
      assert_receive {pid, :list, ^user, []}, 10000
    end

    test "contains the correct data after items are added", context do
      user = random_username()
      item = random_item()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, ^item}, 10000

      send(context[:pid], {self(), :list, user})
      assert_receive {pid, :list, ^user, [^item]}, 10000
    end

    test "returns a sorted list of items", context do

      user = random_username()
      i1 = random_item()
      i2 = random_item()
      i3 = random_item()

      send(context[:pid], {self(), :add, user, i1})
      assert_receive {pid, :added, ^user, ^i1}, 10000

      send(context[:pid], {self(), :add, user, i2})
      assert_receive {pid, :added, ^user, ^i2}, 10000

      send(context[:pid], {self(), :add, user, i3})
      assert_receive {pid, :added, ^user, ^i3}, 10000

      expected = Enum.sort([i1, i2, i3])

      send(context[:pid], {self(), :list, user})
      assert_receive {pid, :list, ^user, ^expected}, 10000

    end

    test "returns only list items for the specified user", context do

      u1 = random_username()
      u2 = random_username()
      i11 = random_item()
      i12 = random_item()
      i21 = random_item()
      i22 = random_item()

      send(context[:pid], {self(), :add, u1, i11})
      assert_receive {pid, :added, ^u1, ^i11}, 10000

      send(context[:pid], {self(), :add, u1, i12})
      assert_receive {pid, :added, ^u1, ^i12}, 10000

      send(context[:pid], {self(), :add, u2, i21})
      assert_receive {pid, :added, ^u2, ^i21}, 10000

      send(context[:pid], {self(), :add, u2, i22})
      assert_receive {pid, :added, ^u2, ^i22}, 10000

      expected1 = Enum.sort([i11, i12])
      expected2 = Enum.sort([i21, i22])

      send(context[:pid], {self(), :list, u1})
      assert_receive {pid, :list, ^u1, ^expected1}, 10000

      send(context[:pid], {self(), :list, u2})
      assert_receive {pid, :list, ^u2, ^expected2}, 10000

    end

    test "persists changes to disk", context do

      u1 = random_username()
      u2 = random_username()
      i11 = random_item()
      i12 = random_item()
      i21 = random_item()
      i22 = random_item()

      send(context[:pid], {self(), :add, u1, i11})
      assert_receive {pid, :added, ^u1, ^i11}, 10000

      send(context[:pid], {self(), :add, u1, i12})
      assert_receive {pid, :added, ^u1, ^i12}, 10000

      send(context[:pid], {self(), :add, u2, i21})
      assert_receive {pid, :added, ^u2, ^i21}, 10000

      send(context[:pid], {self(), :add, u2, i22})
      assert_receive {pid, :added, ^u2, ^i22}, 10000

      expected1 = Enum.sort([i11, i12])
      expected2 = Enum.sort([i21, i22])

      send(context[:pid], {self(), :list, u1})
      assert_receive {pid, :list, ^u1, ^expected1}, 10000

      send(context[:pid], {self(), :list, u2})
      assert_receive {pid, :list, ^u2, ^expected2}, 10000

      Process.exit(context[:pid], :kill)

      pid = spawn(ShoppingListStore, :start, [])

      send(pid, {self(), :list, u1})
      assert_receive {^pid, :list, ^u1, ^expected1}, 10000

      send(pid, {self(), :list, u2})
      assert_receive {^pid, :list, ^u2, ^expected2}, 10000
    end

  end

  describe ":delete when the user doesn't exist" do

    setup [:start_list_store, :flush_messages]

    test "returns the correct response", context do
      user = random_username()
      item = random_item()

      send(context[:pid], {self(), :delete, user, item})
      assert_receive {pid, :not_found, ^user, ^item}, 10000
    end

  end

  describe ":delete when the item doesn't exist" do

    setup [:start_list_store, :flush_messages]

    test "returns the correct response", context do
      user = random_username()
      item = random_item()
      item2 = random_item()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, ^item}, 10000

      send(context[:pid], {self(), :delete, user, item2})
      assert_receive {pid, :not_found, ^user, ^item2}, 10000
    end

  end

  describe ":delete when the item exists" do

    setup [:start_list_store, :flush_messages]

    test "returns the correct response", context do
      user = random_username()
      item = random_item()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, ^item}, 10000

      send(context[:pid], {self(), :delete, user, item})
      assert_receive {pid, :deleted, ^user, ^item}, 10000
    end

    test "does not allow an item to be deleted twice", context do
      user = random_username()
      item = random_item()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, ^item}, 10000

      send(context[:pid], {self(), :delete, user, item})
      assert_receive {pid, :deleted, ^user, ^item}, 10000

      send(context[:pid], {self(), :delete, user, item})
      assert_receive {pid, :not_found, ^user, ^item}, 10000
    end

    test "persists changes to disk", context do
      user = random_username()
      item = random_item()

      send(context[:pid], {self(), :add, user, item})
      assert_receive {pid, :added, ^user, ^item}, 10000

      Process.exit(context[:pid], :kill)
      pid2 = spawn(ShoppingListStore, :start, [])

      send(pid2, {self(), :delete, user, item})
      assert_receive {^pid2, :deleted, ^user, ^item}, 10000

      Process.exit(pid2, :kill)
      pid3 = spawn(ShoppingListStore, :start, [])

      send(pid3, {self(), :delete, user, item})
      assert_receive {^pid3, :not_found, ^user, ^item}, 10000

    end

  end

  describe ":clear" do

    setup [:start_list_store, :flush_messages]

    test "returns the correct response", context do
      send(context[:pid], {self(), :clear})
      assert_receive {pid, :cleared}, 10000
    end

    test "clears all lists", context do

      u1 = random_username()
      u2 = random_username()
      i11 = random_item()
      i12 = random_item()
      i21 = random_item()
      i22 = random_item()

      send(context[:pid], {self(), :add, u1, i11})
      assert_receive {pid, :added, ^u1, ^i11}, 10000

      send(context[:pid], {self(), :add, u1, i12})
      assert_receive {pid, :added, ^u1, ^i12}, 10000

      send(context[:pid], {self(), :add, u2, i21})
      assert_receive {pid, :added, ^u2, ^i21}, 10000

      send(context[:pid], {self(), :add, u2, i22})
      assert_receive {pid, :added, ^u2, ^i22}, 10000

      expected1 = Enum.sort([i11, i12])
      expected2 = Enum.sort([i21, i22])

      send(context[:pid], {self(), :list, u1})
      assert_receive {pid, :list, ^u1, ^expected1}, 10000

      send(context[:pid], {self(), :list, u2})
      assert_receive {pid, :list, ^u2, ^expected2}, 10000

      send(context[:pid], {self(), :clear})
      assert_receive {pid, :cleared}, 10000

      send(context[:pid], {self(), :list, u1})
      assert_receive {pid, :list, ^u1, []}, 10000

      send(context[:pid], {self(), :list, u2})
      assert_receive {pid, :list, ^u2, []}, 10000

    end

    test "persists changes to disk", context do

      u1 = random_username()
      u2 = random_username()
      i11 = random_item()
      i12 = random_item()
      i21 = random_item()
      i22 = random_item()

      send(context[:pid], {self(), :add, u1, i11})
      assert_receive {pid, :added, ^u1, ^i11}, 10000

      send(context[:pid], {self(), :add, u1, i12})
      assert_receive {pid, :added, ^u1, ^i12}, 10000

      send(context[:pid], {self(), :add, u2, i21})
      assert_receive {pid, :added, ^u2, ^i21}, 10000

      send(context[:pid], {self(), :add, u2, i22})
      assert_receive {pid, :added, ^u2, ^i22}, 10000

      expected1 = Enum.sort([i11, i12])
      expected2 = Enum.sort([i21, i22])

      send(context[:pid], {self(), :list, u1})
      assert_receive {pid, :list, ^u1, ^expected1}, 10000

      send(context[:pid], {self(), :list, u2})
      assert_receive {pid, :list, ^u2, ^expected2}, 10000

      Process.exit(context[:pid], :kill)
      pid2 = spawn(ShoppingListStore, :start, [])

      send(pid2, {self(), :list, u1})
      assert_receive {^pid2, :list, ^u1, ^expected1}, 10000

      send(pid2, {self(), :list, u2})
      assert_receive {^pid2, :list, ^u2, ^expected2}, 10000

      send(pid2, {self(), :clear})
      assert_receive {^pid2, :cleared}, 10000

      Process.exit(pid2, :kill)
      pid3 = spawn(ShoppingListStore, :start, [])

      send(pid3, {self(), :list, u1})
      assert_receive {^pid3, :list, ^u1, []}, 10000

      send(pid3, {self(), :list, u2})
      assert_receive {^pid3, :list, ^u2, []}, 10000

    end

  end

  describe ":exit" do
    setup [:start_list_store, :flush_messages]

    test "terminates the ShoppingListStore process", context do
      assert Process.alive?(context[:pid])

      send(context[:pid], {self(), :exit})
      Process.sleep(100)

      refute Process.alive?(context[:pid])
    end
  end

  defp random_username() do
    id = Enum.shuffle(1..100000) |> hd
    "user#{id}"
  end

  defp random_item() do
    id = Enum.shuffle(1..100000) |> hd
    "item#{id}"
  end

  defp start_list_store(_context) do
    pid = spawn(ShoppingListStore, :start, [])
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
