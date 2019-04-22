defmodule SnooperTest do
  use ExUnit.Case
  doctest Snooper
  import Snooper

  defmodule SnooperTestModule do
    # snoop(
    #   def test1 do
    #     1
    #     2
    #   end
    # )

    # snoop(def(test2, do: 2))

    # def test3 do
    #   1
    #   2
    # end
    # |> snoop

    # snoop(def test4, do: 1)

    # snoop(Kernel.def(test5, do: 1))

    snoop def test6(arg) do
      if arg == :fart do
        Module.concat(:badass, arg)
      else
        :loser
      end
    end

    # snoop Kernel.def(test7(_)) do
    #   1
    # end

    # snoop(1, 2)

    # snoop def test8(_), able: true do
    #   1
    # end
  end

  test "snoop snoop" do
    # assert SnooperTestModule.test1() == 2
    # assert SnooperTestModule.test2() == 2
    # assert SnooperTestModule.test3() == 2
    # assert SnooperTestModule.test4() == 1
    # assert SnooperTestModule.test5() == 1
    assert SnooperTestModule.test6(:fart) == :"Elixir.badass.fart"
    assert SnooperTestModule.test6(:poop) == :loser
    # assert SnooperTestModule.test7(nil) == 1
  end

  # test "Gives good error when call cannot be decomposed" do
  #   assert snoop_fail(quote do: snoop(foo)) ==
  #            "Snoop failed: could not decompose call: foo"

  #   assert snoop_fail(quote do: snoop(apple = banana)) ==
  #            "Snoop failed: could not snoop \"apple = banana\", are you sure it's a definition?"

  #   assert snoop_fail(quote do: snoop(def(a, do: 1))) ==
  #            "Snoop failed: could not snoop \"apple = banana\", are you sure it's a definition?"
  # end

  # defp snoop_fail(quoted) do
  #   try do
  #     assert_raise RuntimeError, fn -> Module.create(SnooperTestFailModule, quoted, __ENV__) end
  #   else
  #     %{message: message} -> message
  #   after
  #     :code.delete(SnooperTestFailModule)
  #     :code.purge(SnooperTestFailModule)
  #   end
  # end
end
