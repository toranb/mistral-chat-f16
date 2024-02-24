defmodule Chat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChatWeb.Telemetry,
      {Nx.Serving, serving: serving(), name: ChatServing},
      {DNSCluster, query: Application.get_env(:chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Chat.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Chat.Finch},
      # Start a worker by calling: Chat.Worker.start_link(arg)
      # {Chat.Worker, arg},
      # Start to serve requests, typically the last entry
      ChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def serving() do
    mistral = {:hf, "mistralai/Mistral-7B-Instruct-v0.2"}

    {:ok, model_info} = Bumblebee.load_model(mistral, backend: {EXLA.Backend, client: :host}, type: :bf16)
    {:ok, tokenizer} = Bumblebee.load_tokenizer(mistral)
    {:ok, generation_config} = Bumblebee.load_generation_config(mistral)
    generation_config = Bumblebee.configure(generation_config, max_new_tokens: 500, no_repeat_ngram_length: 5, strategy: %{type: :multinomial_sampling, top_p: 0.6})
    Bumblebee.Text.generation(model_info, tokenizer, generation_config, compile: [batch_size: 1, sequence_length: 4096], stream: true, defn_options: [compiler: EXLA, lazy_transfers: :always])
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
