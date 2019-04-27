defmodule SnooperTest do
  use ExUnit.Case
  doctest Snooper

  import Snooper
  import ExUnit.CaptureLog

  defmodule SnooperTestModule do
    snoop(
      def test1 do
        2
      end
    )

    snoop(def(test2, do: 2))

    def test3 do
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
  end

  test "snoop doesn't interfere when it shouldn't" do
    capture_log(fn ->
      assert SnooperTestModule.test1() == 2
      assert SnooperTestModule.test2() == 2
      assert SnooperTestModule.test3() == 2
      assert SnooperTestModule.test4() == 1
      assert SnooperTestModule.test5() == 1
      assert SnooperTestModule.test6(:foo) == :"Elixir.awesome.foo"
      assert SnooperTestModule.test6(:baz) == :bar
      assert SnooperTestModule.test7(nil) == 1
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

  test "snoop output looks nice" do
    assert 10 == SnooperTestModule2.a_pointless_but_long_function("Hello Elixir")
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
