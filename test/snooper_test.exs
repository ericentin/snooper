defmodule SnooperTest do
  use ExUnit.Case
  doctest Snooper

  import Snooper
  import ExUnit.CaptureIO

  defmodule SnooperTestModule2 do
    snoop def a_pointless_but_long_function(my_other_string) do
      some_string = "Hello World"
      some_other_string = "Hello Joe"

      a_long_string =
        [some_string, some_other_string, my_other_string]
        |> Stream.cycle()
        |> Enum.take(10)
        |> Enum.join(", ")

      a_long_string = String.replace(a_long_string, "World", "Erlang")

      matches = Regex.scan(~r/Hello/, a_long_string)

      unless Enum.all?(matches, &(["Hello"] == &1)) do
        raise "match not for Hello"
      end

      length(matches)
    end
  end

  defmodule SnooperTestModule do
    snoop(
      def test1 do
        2
      end
    )

    snoop(def(test2, do: 2))

    test3
    |> def do
      2
    end
    |> snoop

    snoop(def test4, do: 1)

    snoop(Kernel.def(test5, do: 1))

    snoop def test6(arg) do
      result =
        if arg == :foo do
          Module.concat(:awesome, arg)
        else
          :bar
        end

      result
    end

    snoop Kernel.def(test7(_)) do
      1
    end

    snoop def test8(arg) do
      case arg do
        :foo -> :oof
        :bar -> :rab
      end
    end
  end

  test "snoop doesn't interfere when it shouldn't" do
    capture_io(fn ->
      assert SnooperTestModule.test1() == 2
      assert SnooperTestModule.test2() == 2
      assert SnooperTestModule.test3() == 2
      assert SnooperTestModule.test4() == 1
      assert SnooperTestModule.test5() == 1
      assert SnooperTestModule.test6(:foo) == :"Elixir.awesome.foo"
      assert SnooperTestModule.test6(:baz) == :bar
      assert SnooperTestModule.test7(nil) == 1
      assert SnooperTestModule.test8(:foo) == :oof
      assert SnooperTestModule.test8(:bar) == :rab
    end)
  end

  test "Gives good error when call cannot be decomposed" do
    assert snoop_fail(quote do: snoop(1, 2)).message ==
             "Snooper failed: could not decompose call: snoop(1, 2)"
  end

  test "Doesn't fail when there's pre-block args" do
    assert snoop_fail(
             quote do
               snoop def test8(_), able: true do
                 1
               end
             end,
             CompileError
           ).description ==
             "undefined function def/3"
  end

  test "snoop output looks nice" do
    assert capture_io(fn ->
             assert 10 == SnooperTestModule2.a_pointless_but_long_function("Hello Elixir")
           end)
           |> String.split("\n")
           |> Enum.map(&String.replace(&1, ~r/\[snoop_id:\d*:\d*\] /, "")) ==
             [
               "Entered \e[94mElixir.SnooperTest.SnooperTestModule2.a_pointless_but_long_function(my_other_string)\e[0m, arg bindings: \e[31m[\e[0m\e[96mmy_other_string:\e[0m \e[32m\"Hello Elixir\"\e[0m\e[31m]\e[0m",
               "Line 10: \e[92msome_string = \"Hello World\"\e[0m",
               "Line 10 evaluated to: \e[32m\"Hello World\"\e[0m, new bindings: \e[31m[\e[0m\e[96msome_string:\e[0m \e[32m\"Hello World\"\e[0m\e[31m]\e[0m",
               "Line 11: \e[92msome_other_string = \"Hello Joe\"\e[0m",
               "Line 11 evaluated to: \e[32m\"Hello Joe\"\e[0m, new bindings: \e[31m[\e[0m\e[96msome_other_string:\e[0m \e[32m\"Hello Joe\"\e[0m\e[31m]\e[0m",
               "Line 13: \e[92m",
               "  a_long_string =",
               "    [some_string, some_other_string, my_other_string]",
               "    |> Stream.cycle()",
               "    |> Enum.take(10)",
               "    |> Enum.join(\", \")\e[0m",
               "Line 17: \e[92m",
               "  [some_string, some_other_string, my_other_string]",
               "  |> Stream.cycle()",
               "  |> Enum.take(10)",
               "  |> Enum.join(\", \")\e[0m",
               "Line 13 evaluated to: \e[32m\"Hello World, Hello Joe, Hello Elixir, Hello World, Hello Joe, Hello Elixir, Hello World, Hello Joe, Hello Elixir, Hello World\"\e[0m, new bindings: \e[31m[\e[0m",
               "  \e[96ma_long_string:\e[0m \e[32m\"Hello World, Hello Joe, Hello Elixir, Hello World, Hello Joe, Hello Elixir, Hello World, Hello Joe, Hello Elixir, Hello World\"\e[0m",
               "\e[31m]\e[0m",
               "Line 19: \e[92ma_long_string = String.replace(a_long_string, \"World\", \"Erlang\")\e[0m",
               "Line 19 evaluated to: \e[32m\"Hello Erlang, Hello Joe, Hello Elixir, Hello Erlang, Hello Joe, Hello Elixir, Hello Erlang, Hello Joe, Hello Elixir, Hello Erlang\"\e[0m, changed bindings: \e[31m[\e[0m",
               "  \e[96ma_long_string:\e[0m \e[32m\"Hello Erlang, Hello Joe, Hello Elixir, Hello Erlang, Hello Joe, Hello Elixir, Hello Erlang, Hello Joe, Hello Elixir, Hello Erlang\"\e[0m",
               "\e[31m]\e[0m",
               "Line 21: \e[92mmatches = Regex.scan(~r\"Hello\", a_long_string)\e[0m",
               "Line 21 evaluated to: \e[31m[\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "  \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m",
               "\e[31m]\e[0m, new bindings: \e[31m[\e[0m",
               "  \e[96mmatches:\e[0m \e[31m[\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m\e[31m,\e[0m",
               "    \e[31m[\e[0m\e[32m\"Hello\"\e[0m\e[31m]\e[0m",
               "  \e[31m]\e[0m",
               "\e[31m]\e[0m",
               "Line 23: \e[92m",
               "  unless(Enum.all?(matches, &([\"Hello\"] == &1))) do",
               "    raise(\"match not for Hello\")",
               "  end\e[0m",
               "Line 27: \e[92mlength(matches)\e[0m",
               "Returning: \e[33m10\e[0m",
               ""
             ]
  end

  defp snoop_fail(quoted, e \\ RuntimeError) do
    try do
      assert_raise e, fn -> Module.create(SnooperTestFailModule, quoted, __ENV__) end
    else
      e -> e
    after
      :code.delete(SnooperTestFailModule)
      :code.purge(SnooperTestFailModule)
    end
  end
end
