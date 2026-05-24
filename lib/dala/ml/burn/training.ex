defmodule Dala.ML.Burn.Training do
  @moduledoc """
  Training callbacks and utilities for ExBurn models in Dala.

  Provides Dala-specific training callbacks and helpers that integrate
  with the ExBurn training loop.

  ## Callbacks

  - `Dala.ML.Burn.Training.LoggingCallback` — Logs metrics after each epoch
  - `Dala.ML.Burn.Training.EarlyStoppingCallback` — Stops training when val loss plateaus
  - `Dala.ML.Burn.Training.CheckpointCallback` — Saves model checkpoints

  ## Usage

      model = Dala.ML.Burn.compile(axon_model, loss: :cross_entropy, optimizer: :adam)

      callbacks = [
        &Dala.ML.Burn.Training.LoggingCallback.log/1,
        Dala.ML.Burn.Training.EarlyStoppingCallback.wait(5, 1.0e-4),
        Dala.ML.Burn.Training.CheckpointCallback.every(5, "checkpoints/")
      ]

      trained = Dala.ML.Burn.fit(model, {train_x, train_y},
        epochs: 50,
        batch_size: 32,
        validation_data: {val_x, val_y},
        callbacks: callbacks,
        lr_schedule: {:cosine, 0.001, 1.0e-5},
        clip_norm: 1.0
      )
  """

  @doc """
  Creates a logging callback that prints training metrics after each epoch.
  """
  @spec logging_callback() :: (map() -> map())
  def logging_callback do
    &ExBurn.Training.LoggingCallback.log/1
  end

  @doc """
  Creates an early stopping callback.

  ## Parameters

  * `patience` — Number of epochs to wait for improvement before stopping
  * `min_delta` — Minimum improvement to reset the patience counter
  """
  @spec early_stopping_callback(pos_integer(), float()) :: (map() -> map())
  def early_stopping_callback(patience, min_delta \\ 1.0e-4) do
    ExBurn.Training.EarlyStoppingCallback.wait(patience, min_delta)
  end

  @doc """
  Creates a checkpoint callback that saves model state at intervals.

  ## Parameters

  * `interval` — Save a checkpoint every N epochs
  * `dir` — Directory to save checkpoints in
  """
  @spec checkpoint_callback(pos_integer(), Path.t()) :: (map() -> map())
  def checkpoint_callback(interval, dir) do
    ExBurn.Training.CheckpointCallback.every(interval, dir)
  end

  @doc """
  Creates a Dala-specific callback that reports training progress
  to the Dala screen via `handle_info`.

  The callback sends `{:training_progress, epoch, loss, val_loss}` to
  the calling process, which can be handled in `handle_info/2`.

  ## Usage

      # In your screen module:
      callbacks = [
        Dala.ML.Burn.Training.screen_callback(self())
      ]

      # Handle progress updates:
      def handle_info({:training_progress, epoch, loss, val_loss}, socket) do
        {:noreply, assign(socket, epoch: epoch, loss: loss, val_loss: val_loss)}
      end
  """
  @spec screen_callback(pid()) :: (map() -> map())
  def screen_callback(screen_pid) do
    fn
      %{epoch: epoch, loss: loss} = metrics ->
        val_loss = Map.get(metrics, :val_loss)
        send(screen_pid, {:training_progress, epoch, loss, val_loss})
        metrics

      metrics ->
        metrics
    end
  end

  @doc """
  Creates a callback that stores training history in an Agent.

  Returns `{callback_fn, agent_pid}`. Call `get_history/1` on the agent
  to retrieve the full training history.

  ## Usage

      {callback, agent} = Dala.ML.Burn.Training.history_callback()
      callbacks = [callback]

      # After training:
      history = Dala.ML.Burn.Training.get_history(agent)
      # [%{epoch: 1, loss: 0.5, val_loss: 0.4}, ...]
  """
  @spec history_callback() :: {(map() -> map()), pid()}
  def history_callback do
    {:ok, pid} = Agent.start_link(fn -> [] end)

    callback = fn metrics ->
      Agent.update(pid, fn history ->
        epoch_metrics = %{
          epoch: Map.get(metrics, :epoch),
          loss: Map.get(metrics, :loss),
          val_loss: Map.get(metrics, :val_loss)
        }

        [epoch_metrics | history]
      end)

      metrics
    end

    {callback, pid}
  end

  @doc """
  Retrieves the full training history from a history callback agent.
  """
  @spec get_history(pid()) :: [map()]
  def get_history(agent_pid) do
    Agent.get(agent_pid, &Enum.reverse/1)
  end

  @doc """
  Convenience function to train with a progress-reporting callback.

  Automatically sets up screen callback and returns the trained model.
  """
  @spec fit_with_progress(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) ::
          {ExBurn.Model.t(), [map()]}
  def fit_with_progress(%ExBurn.Model{} = model, data, opts \\ []) do
    {history_cb, agent} = history_callback()
    verbose = Keyword.get(opts, :verbose, true)

    callbacks =
      [history_cb] ++
        (if verbose, do: [logging_callback()], else: []) ++
        Keyword.get(opts, :callbacks, [])

    opts = Keyword.put(opts, :callbacks, callbacks)
    trained = Dala.ML.Burn.fit(model, data, opts)
    history = get_history(agent)
    {trained, history}
  end
end
