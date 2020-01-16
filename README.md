# AugCart


AugCart is a multithreaded, highly scalable CLI shopping list server which supports (with the current configuration) up to 2,000,000+ concurrent users. Made possible with [Elixir](https://elixir-lang.org).

![Client CLI](https://i.imgur.com/N09Ojqy.png)

## Installation

``` bash
git clone https://github.com/uoysip/augcart.git
cd augcart
```

## How to Run

To start the server, type ```./server``` in the project directory. The administrator client can be accessed by typing ```./client``` with the correct commands and parameters:

```
Usage: ./client [COMMAND] [PARAMS]

Commands

  clear                      - Clear all data on the server
  list add USER PASS ITEM    - Add ITEM to USER shopping list
  list del USER PASS ITEM    - Remove ITEM from USER shopping list
  list USER PASS             - Show list for USER
  shutdown                   - Shut down the server
  user add USER PASS         - Add new user
  users                      - List users
	
```



## Tests

Includes robust test harnesses to ensure proper storage of data, handling of command edge-cases, user creation/deletion, addition/removal of items, and much more.

## License

This project is released under the MIT license, see the LICENSE file for details.
