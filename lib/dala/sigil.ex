defmodule Dala.Sigil do
  @moduledoc """
  Public API for sigil operations.

  This module provides the `~dala` sigil for declarative native UI.

  ## Examples

      import Dala.Sigil

      # Self-closing
      ~dala(<Text text="Hello" />)
      #=> %{type: :text, props: %{text: "Hello"}, children: []}

      # Nested layout
      ~dala\"\"\"
      <Column padding={:space_md}>
        <Text text="Title" text_size={:xl} />
        <Button title="OK" on_tap={fn -> send(self(), :ok) end} />
      </Column>
      \"\"\"
  """

  import Dala.Ui.Sigil
end
