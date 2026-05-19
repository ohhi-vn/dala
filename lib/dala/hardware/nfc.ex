defmodule Dala.Hardware.NFC do
  @compile {:nowarn_undefined, [:Nx]}
  @moduledoc """
  NFC (Near Field Communication) tag reading.

  Reads NDEF tags via the device's NFC reader. Requires the app to have
  NFC entitlement (iOS) or `android.permission.NFC` (Android).

  ## Events

  NFC events arrive as `handle_info` messages:

      handle_info({:nfc, :tag, %{tech: "Ndef", raw: "https://...", parsed: %{type: :url, value: "https://..."}}}, socket)
      handle_info({:nfc, :error, %{reason: "NFC is disabled"}}, socket)

  The `parsed` field is produced by `Dala.Ui.Scan.parse/1` and contains a
  structured representation of the payload. See `Dala.Ui.Scan` for all
  supported formats (URL, WiFi, contact, email, phone, geo, text, calendar).

  ## Platform notes

  - **iOS**: Uses `NFCNDEFReaderSession`. The system UI is shown automatically.
    Requires `NFCReaderUsageDescription` in Info.plist and the Near Field
    Communication Tag Reading capability.
  - **Android**: Uses `NfcAdapter` foreground dispatch. The hosting Activity
    must forward `onNewIntent` to `DalaBridge.handleNFCIntent(intent)`.
    Requires `android.permission.NFC` in AndroidManifest.xml.

  ## Usage

      # Start scanning
      Dala.Hardware.NFC.start_scan(socket, message: "Hold near a tag")

      # Stop scanning
      Dala.Hardware.NFC.stop_scan(socket)

      # Check availability
      Dala.Hardware.NFC.available?()

  ## Parsing tag payloads

  Use `Dala.Ui.Scan.parse/1` to decode the raw payload into a structured format:

      def handle_info({:nfc, :tag, %{raw: raw} = tag}, socket) do
        case Dala.Ui.Scan.parse(raw) do
          %{type: :url, value: url} ->
            # Open URL
          %{type: :wifi, value: %{ssid: ssid, password: pw}} ->
            # Connect to WiFi
          %{type: :text, value: text} ->
            # Plain text
        end
        {:noreply, socket}
      end
  """

  @doc """
  Check if NFC is available and enabled on this device.
  """
  @spec available?() :: boolean()
  def available? do
    Dala.Platform.Native.nfc_available()
  end

  @doc """
  Start an NFC scan. The OS presents the scanning UI.

  Options:
    - `message: String.t` — prompt shown in the iOS NFC scanner UI
      (default: "Hold near an NFC tag"). Ignored on Android.

  Tag reads arrive as `{:nfc, :tag, %{tech: String.t, raw: String.t, parsed: map}}`.
  The `parsed` field is `nil` if the payload format is not recognized by `Dala.Ui.Scan.parse/1`.
  Errors arrive as `{:nfc, :error, %{reason: String.t}}`.
  """
  @spec start_scan(Dala.Socket.t(), keyword()) :: Dala.Socket.t()
  def start_scan(socket, opts \\ []) do
    message = Keyword.get(opts, :message, "Hold near an NFC tag")
    Dala.Platform.Native.nfc_start_scan(message)
    socket
  end

  @doc """
  Stop the active NFC scan. Dismisses the iOS scanner UI.
  """
  @spec stop_scan(Dala.Socket.t()) :: Dala.Socket.t()
  def stop_scan(socket) do
    Dala.Platform.Native.nfc_stop_scan()
    socket
  end
end
