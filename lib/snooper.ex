defmodule Snooper do
  @moduledoc """
  This will be the documentation for Snooper eventually.
  """

  require Logger

  defmacro snoop(call) do
    do_snoop(call, __CALLER__.module, &get_blocks/2)
  end

  defmacro snoop(call, [{:do, _do_block} | _rest_blocks] = blocks) do
    do_snoop(call, __CALLER__.module, fn args, _call -> {blocks, args} end)
  end

  defp do_snoop(call, caller_module, blocks_args_fun) do
    case Macro.decompose_call(call) do
      :error ->
        raise_could_not_decompose(call)

      {remote, function, args} ->
        snoop_blocks(call, {remote, function}, args, blocks_args_fun, caller_module)

      {name, args} ->
        snoop_blocks(call, name, args, blocks_args_fun, caller_module)
    end
  end

  defp snoop_blocks(call, decomposed, args, blocks_args_fun, caller_module) do
    {blocks, args} = blocks_args_fun.(args, call)
    blocks = Enum.map(blocks, &to_snooped_block(&1, caller_module, args))

    to_snooped(decomposed, args, blocks)
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

  defp to_snooped({remote, function}, args, blocks) do
    quote do
      unquote(remote).unquote(function)(unquote_splicing(args ++ [blocks]))
    end
  end

  defp to_snooped(name, args, blocks) do
    quote do
      unquote(name)(unquote_splicing(args ++ [blocks]))
    end
  end

  defp to_snooped_block({block_name, block}, caller_module, args) do
    [{_name, _meta, _snooped_args} = signature | _rest_args] = args
    signature = Macro.to_string(signature)
    formatted_mfa = "#{caller_module}.#{signature}"
    run_id_var = Macro.var(:run_id, __MODULE__)
    mfa_hash = :erlang.phash2(formatted_mfa)

    {block_name,
     quote do
       unquote(run_id_var) = "#{unquote(mfa_hash)}:#{System.unique_integer([:positive])}"

       put_enter_log(unquote(run_id_var), unquote(formatted_mfa), binding())
       result = unquote(hook_block(block, run_id_var))
       put_leave_log(unquote(run_id_var), result)

       result
     end}
  end

  defp hook_block(block, run_id_var) do
    {node_block, _line_max} =
      Macro.prewalk(block, 0, fn
        {:->, _meta, _right} = item, line_max ->
          {item, line_max}

        {_left, meta, _right} = item, line_max ->
          line = Keyword.get(meta, :line, 0)

          if line > line_max do
            {quote do
               before_binding = binding()
               run_id = unquote(run_id_var)

               put_before_log(run_id, unquote(line), unquote(Macro.to_string(item)))
               result = unquote(item)
               put_after_log(run_id, unquote(line), before_binding, binding(), result)

               result
             end, line}
          else
            {item, line_max}
          end

        other, line_max ->
          {other, line_max}
      end)

    node_block
  end

  @doc false
  def put_enter_log(run_id, formatted_mfa, caller_binding) do
    bound_args_info =
      if caller_binding != [] do
        ", arg bindings: #{inspect(caller_binding, inspect_opts())}"
      end

    write(
      run_id,
      "Entered #{IO.ANSI.light_blue()}#{formatted_mfa}#{IO.ANSI.reset()}#{bound_args_info}\n"
    )
  end

  @doc false
  def put_leave_log(run_id, caller_result) do
    write(
      run_id,
      "Returning: #{inspect(caller_result, inspect_opts())}\n"
    )
  end

  @doc false
  def put_before_log(
        run_id,
        line,
        item_string
      ) do
    item_string =
      try do
        item_string
        |> Code.format_string!(line_length: 80)
        |> IO.iodata_to_binary()
      catch
        kind, payload ->
          Logger.warn(
            "Error during snoop id #{run_id} code formatting: #{
              Exception.format(kind, payload, __STACKTRACE__)
            }\nUsing unformatted version instead. Please report this issue."
          )

          item_string
      else
        item_string -> item_string
      end

    item_string =
      if String.contains?(item_string, "\n") do
        item_string = String.replace(item_string, "\n", "\n  ")
        ["\n  ", item_string]
      else
        item_string
      end

    item_string = "#{IO.ANSI.light_green()}#{item_string}#{IO.ANSI.reset()}"
    write(run_id, "Line #{line}: #{item_string}\n")
  end

  @doc false
  def put_after_log(
        run_id,
        line,
        before_binding,
        after_binding,
        result
      ) do
    new_keys = Keyword.keys(after_binding) -- Keyword.keys(before_binding)
    new_bindings = Keyword.take(after_binding, new_keys)

    bindings_info =
      if new_bindings != [] do
        ", new bindings: #{inspect(new_bindings, inspect_opts())}"
      else
        ""
      end

    old_keys = Keyword.keys(after_binding) -- new_keys

    changed_bindings =
      old_keys
      |> Enum.map(&{&1, Keyword.get(after_binding, &1)})
      |> Enum.filter(fn {key, value} ->
        Keyword.fetch!(before_binding, key) != value
      end)

    bindings_info =
      if changed_bindings != [] do
        bindings_info <>
          ", changed bindings: #{inspect(changed_bindings, inspect_opts())}"
      else
        bindings_info
      end

    if bindings_info != "" do
      write(
        run_id,
        "Line #{line} evaluated to: #{inspect(result, inspect_opts())}#{bindings_info}\n"
      )
    end
  end

  defp write(run_id, content) do
    IO.write(["[snoop_id:#{run_id}] ", content])
  end

  defp inspect_opts do
    [
      width: 80,
      pretty: true,
      syntax_colors: [
        reset: :reset,
        number: :yellow,
        atom: :light_cyan,
        string: :green,
        list: :red,
        boolean: :magenta,
        nil: :magenta,
        tuple: :blue,
        binary: :green,
        map: :light_blue
      ]
    ]
  end
end
