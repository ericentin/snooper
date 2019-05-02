# Snooper

Easily debug, inspect, and log a function's behavior on a line-by-line basis.

Use like so:

    defmodule SnooperReadme do
      import Snooper

      snoop def my_function(a, b) do
        c = a + b * a + b
        d = c * c
        {alpha, beta} = {c * d, c + d}
      end
    end

Gives colorized output like:

![Snooper output](https://raw.githubusercontent.com/ericentin/snooper/master/screenshot.png)

## Installation

The package can be installed by adding `snooper` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:snooper, "~> 0.1", only: [:dev, :test]}
  ]
end
```

You should also update your project's `.formatter.exs` to import the Snooper formatter configuration:

```elixir
[
  import_deps: [:snooper]
]
```

The docs can be found at [https://hexdocs.pm/snooper](https://hexdocs.pm/snooper).

