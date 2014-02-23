defmodule WebDriver.Remote.Port do
  use GenServer.Behaviour

  defrecord State, root_url: "",
                   supervisor: nil,
                   session_supervisor: nil,
                   sessions: []

  def start_link config, sup do
    { :ok, _pid } = :gen_server.start_link {:local, config.name}, __MODULE__,
                        __MODULE__.State.new(supervisor: sup, root_url: config.root_url), [timeout: 30000]
  end

  def init state do
    send self(), { :start_session_supervisor, state.supervisor }
    { :ok, state, :hibernate }
  end

  def handle_call {:start_session, session_name}, _sender, state do
    {:ok, pid} = :supervisor.start_child state.session_supervisor, [session_name]
    {:reply, {:ok, pid}, state.sessions([session_name | state.sessions])}
  end

  def handle_call :sessions, _sender, state do
    {:reply, {:ok, state.sessions}, state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info {:start_session_supervisor, sup}, state do
    config = WebDriver.Session.State.new(root_url: state.root_url, browser: self)
    spec = Supervisor.Behaviour.worker(WebDriver.SessionSup,[config],[restart: :temporary])
    {:ok, pid} = :supervisor.start_child sup, spec
    {:noreply, state.session_supervisor(pid)}
  end

  def terminate _reason, state do
    :ok
  end
end