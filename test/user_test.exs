defmodule UserTest do
  use ExUnit.Case
  doctest User
  describe "User struct" do

    test "allows the :username key" do
      assert User.__struct__ 
      |> Map.keys
      |> Enum.member?(:username)
    end

    test "allows the :password key" do
      assert User.__struct__ 
      |> Map.keys
      |> Enum.member?(:password)
    end

    test "does not allow any keys other than :username and :password" do

      valid_keys = [:__struct__, :password, :username]

      assert User.__struct__
      |> Map.keys 
      |> Enum.reject(&Enum.member?(valid_keys, &1))
      |> Enum.empty?
    end

    test "requires the :username key" do
      assert_raise(ArgumentError, fn -> 
        User.__struct__([password: "password"])
      end)
    end

    test "requires the :password key" do
      assert_raise(ArgumentError, fn -> 
        User.__struct__([username: "Joe"])
      end)
    end

    test "is valid with :username and :password keys" do
      user = %User{ username: "Joe", password: "password" }
      assert user.username == "Joe"
      assert user.password == "password"
    end
  end

end
