defmodule Bureaucrat.Helpers do
  alias Phoenix.Socket.{Broadcast, Message}

  @doc """
  Adds a conn to the generated documentation.

  The name of the test currently being executed will be used as a description for the example.
  """
  defmacro doc(conn) do
    quote bind_quoted: [conn: conn] do
      doc(conn, [])
    end
  end

  @doc """
  Adds a Phoenix.Socket.Message to the generated documentation.

  The name of the test currently being executed will be used as a description for the example.
  """
  defmacro doc_push(socket, event) do
    quote bind_quoted: [socket: socket, event: event] do
      ref = make_ref()
      message = %Message{event: event, topic: socket.topic, ref: ref, payload: Phoenix.ChannelTest.__stringify__(%{})}
      doc(message, [])
      send(socket.channel_pid, message)
      ref
    end
  end

  defmacro doc_push(socket, event, payload) do
    quote bind_quoted: [socket: socket, event: event, payload: payload] do
      ref = make_ref()
      message = %Message{event: event, topic: socket.topic, ref: ref, payload: Phoenix.ChannelTest.__stringify__(payload)}
      doc(message, [])
      send(socket.channel_pid, message)
      ref
    end
  end

  defmacro doc_broadcast_from(socket, event, message) do
    quote bind_quoted: [socket: socket, event: event, message: message] do
      %{pubsub_server: pubsub_server, topic: topic, transport_pid: transport_pid} = socket
      broadcast = %Broadcast{topic: topic, event: event, payload: message}
      doc(broadcast, [])
      Phoenix.Channel.Server.broadcast_from(pubsub_server, transport_pid, topic, event, message)
    end
  end

  defmacro doc_broadcast_from!(socket, event, message) do
    quote bind_quoted: [socket: socket, event: event, message: message] do
      %{pubsub_server: pubsub_server, topic: topic, transport_pid: transport_pid} = socket
      broadcast = %Broadcast{topic: topic, event: event, payload: message}
      doc(broadcast, [])
      Phoenix.Channel.Server.broadcast_from!(pubsub_server, transport_pid, topic, event, message)
    end
  end

  @doc """
  Adds a conn to the generated documentation

  The description, and additional options can be passed in the second argument:

  ## Examples

      conn = conn()
        |> get("/api/v1/products")
        |> doc("List all products")

      conn = conn()
        |> get("/api/v1/products")
        |> doc(description: "List all products", operation_id: "list_products")
  """
  defmacro doc(conn, desc) when is_binary(desc) do
    quote bind_quoted: [conn: conn, desc: desc] do
      doc(conn, description: desc)
    end
  end

  defmacro doc(conn, opts) when is_list(opts) do
    # __CALLER__returns a `Macro.Env` struct
    #   -> https://hexdocs.pm/elixir/Macro.Env.html
    mod = __CALLER__.module
    fun = __CALLER__.function |> elem(0) |> to_string
    # full path as binary
    file = __CALLER__.file
    line = __CALLER__.line

    titles = Application.get_env(:bureaucrat, :titles)

    opts =
      opts
      |> Keyword.put_new_lazy(:description, format_test_name(fun, opts[:description]))
      |> Keyword.put_new_lazy(:group_title, group_title_for(mod, titles, opts[:group_title]))
      |> Keyword.put_new_lazy(:module, get_value(mod, opts[:module]))
      |> Keyword.put_new_lazy(:file, get_value(file, opts[:file]))
      |> Keyword.put_new_lazy(:line, get_value(line, opts[:line]))

    quote bind_quoted: [conn: conn, opts: opts] do
      Bureaucrat.Recorder.doc(conn, opts)
      conn
    end
  end

  def get_value(value_from_caller, nil), do: value_from_caller

  def get_value(_value_from_caller, value_from_options), do: value_from_options

  def format_test_name("test " <> name, nil), do: name
  def format_test_name(_fun, _description), do: fn -> no_return() end

  def group_title_for(_mod, [], nil), do: nil

  def group_title_for(mod, [{other, path} | paths], nil) do
    if String.replace_suffix(to_string(mod), "Test", "") == to_string(other) do
      path
    else
      group_title_for(mod, paths)
    end
  end

  def group_title_for(_mod, _titles, group_title), do: group_title

  @doc """
  Helper function for adding the phoenix_controller and phoenix_action keys to
  the private map of the request that's coming from the test modules.

  For example:

  test "all items - unauthenticated", %{conn: conn} do
    conn
    |> get(item_path(conn, :index))
    |> plug_doc(module: __MODULE__, action: :index)
    |> doc()
    |> assert_unauthenticated()
  end

  The request from this test will never touch the controller that's being tested,
  because it is being piped through a plug that authenticates the user and redirects
  to another page. In this scenario, we use the plug_doc function.
  """
  def plug_doc(conn, module: module, action: action) do
    controller_name = module |> to_string |> String.trim("Test")

    conn
    |> Plug.Conn.put_private(:phoenix_controller, controller_name)
    |> Plug.Conn.put_private(:phoenix_action, action)
  end
end
