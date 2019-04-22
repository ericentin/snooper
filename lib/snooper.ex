defmodule Snooper do
  import Macro

  defmacro snoop(call) do
    caller_module = __CALLER__.module

    case decompose_call(call) do
      :error ->
        raise_could_not_decompose(call)

      {remote, function, args} ->
        {blocks, args} = get_blocks(args, call)
        blocks = Enum.map(blocks, &to_snooped_block(&1, caller_module, args))
        to_snooped({remote, function, args}, blocks)

      {name, args} ->
        {blocks, args} = get_blocks(args, call)
        blocks = Enum.map(blocks, &to_snooped_block(&1, caller_module, args))
        to_snooped({name, args}, blocks)
    end
  end

  defmacro snoop(call, [{:do, _do_block} | _rest_blocks] = blocks) do
    caller_module = __CALLER__.module

    case decompose_call(call) do
      :error ->
        raise_could_not_decompose(call)

      {remote, function, args} ->
        blocks = Enum.map(blocks, &to_snooped_block(&1, caller_module, args))
        to_snooped({remote, function, args}, blocks)

      {name, args} ->
        blocks = Enum.map(blocks, &to_snooped_block(&1, caller_module, args))
        to_snooped({name, args}, blocks)
    end
  end

  defmacro snoop(call, blocks) do
    raise_could_not_decompose(quote do: snoop(unquote(call), unquote(blocks)))
  end

  defp raise_could_not_decompose(call) do
    raise "Snooper failed: could not decompose call: #{Macro.to_string(call)}"
  end

  defp get_blocks(args, call) do
    case List.pop_at(args, -1) do
      {[{:do, _do_block} | _rest_blocks] = blocks, args} ->
        {blocks, args}

      _ ->
        raise_could_not_decompose(call)
    end
  end

  defp to_snooped({remote, function, args}, blocks) do
    quote do
      require Logger
      unquote(remote).unquote(function)(unquote_splicing(args ++ [blocks]))
    end
  end

  defp to_snooped({name, args}, blocks) do
    quote do
      require Logger
      unquote(name)(unquote_splicing(args ++ [blocks]))
    end
  end

  defp to_snooped_block({block_name, block}, caller_module, args) do
    [{_name, _meta, _snooped_args} = signature | _rest_args] = args
    signature = Macro.to_string(signature)
    formatted_mfa = "#{caller_module}.#{signature}"

    before_block =
      quote bind_quoted: [formatted_mfa: formatted_mfa] do
        Logger.debug(fn ->
          "Entered function #{formatted_mfa} with bound args: #{inspect(binding())}."
        end)
      end

    {node_block, _line_max} =
      Macro.prewalk(block, 0, fn
        {_left, meta, _right} = item, line_max when is_list(meta) ->
          line = Keyword.get(meta, :line, 0)

          item_string = Macro.to_string(item)

          if line > line_max do
            new_block =
              quote do
                before_binding = binding()

                Logger.debug(fn ->
                  inspect({:before, unquote(line), unquote(item_string), before_binding})
                end)

                result = unquote(item)

                Logger.debug(fn ->
                  after_binding = binding()

                  inspect({:after, unquote(line), after_binding, result})
                end)

                result
              end

            {new_block, line}
          else
            {item, line_max}
          end

        other, line_max ->
          {other, line_max}
      end)

    after_block =
      quote bind_quoted: [formatted_mfa: formatted_mfa] do
        Logger.debug(fn ->
          "Leaving function #{formatted_mfa}."
        end)
      end

    block =
      quote do
        unquote(before_block)
        result = unquote(node_block)
        unquote(after_block)
        result
      end

    {block_name, block}
  end
end
