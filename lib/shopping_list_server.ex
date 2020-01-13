defmodule ShoppingListServer do

  def start() do
    
    # Spawn a linked UserStore process
    users_pid = nil  
    
    # Spawn a linked ShoppingListStore process
    lists_pid = nil  

    # Leave this here
    Process.register(self(), :server)  

    # Start the message processing loop 
    loop(users_pid, lists_pid)
  end

  def loop(users, lists) do

    # For each request that is received, MUST spawn a new process
    # to handle it (either here, or in a helper method) so that the main
    # process can immediately return to processing incoming messages

  end

end
