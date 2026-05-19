defmodule Dala.Hardware.Scanner do
  @compile {:nowarn_undefined, [:Nx]}
  @moduledoc """
  QR code and barcode scanner.

  Requires `:camera` permission (request via `Dala.Permissions.request/2`).

  Opens a full-screen camera preview. When a code is detected the view dismisses
  automatically and the result is delivered to `handle_info`:

      handle_info({:scan, :result, %{type: :qr, value: "https://...", parsed: %{type: :url, value: "https://..."}}}, socket)
      handle_info({:scan, :cancelled}, socket)

  The `parsed` field is produced by `Dala.Ui.Scan.parse/1` and contains a
  structured representation of the scanned value. See `Dala.Ui.Scan` for all
  supported formats (URL, WiFi, contact, email, phone, geo, text, calendar).

  iOS: `AVCaptureMetadataOutput`. Android: `CameraX` + ML Kit `BarcodeScanning`.

  > **Android dependency:** add to `app/build.gradle`:
  > `implementation 'com.google.mlkit:barcode-scanning:17.2.0'`
  > `implementation 'androidx.camera:camera-camera2:1.3.0'`
  > `implementation 'androidx.camera:camera-lifecycle:1.3.0'`
  > `implementation 'androidx.camera:camera-view:1.3.0'`

  ## Parsing scanned values

  Use `Dala.Ui.Scan.parse/1` to decode the raw value into a structured format:

      def handle_info({:scan, :result, %{value: raw} = result}, socket) do
        case Dala.Ui.Scan.parse(raw) do
          %{type: :url, value: url} ->
            # Open URL
          %{type: :wifi, value: %{ssid: ssid, password: pw}} ->
            # Connect to WiFi
          %{type: :vcard, value: %{name: name, phone: phone}} ->
            # Save contact
          %{type: :text, value: text} ->
            # Plain text
        end
        {:noreply, socket}
      end

  Or use `Dala.Ui.Scan.parse_direct/1` to parse a string directly without scanning.
  """

  @type format ::
          :qr
          | :ean13
          | :ean8
          | :code128
          | :code39
          | :upca
          | :upce
          | :pdf417
          | :aztec
          | :data_matrix

  @doc """
  Open the barcode scanner.

  Options:
    - `formats: [format]` — list of barcode formats to detect (default `[:qr]`)
  """
  @spec scan(Dala.Socket.t(), keyword()) :: Dala.Socket.t()
  def scan(socket, opts \\ []) do
    formats = Keyword.get(opts, :formats, [:qr]) |> Enum.map(&Atom.to_string/1)
    formats_json = :json.encode(formats)
    Dala.Platform.Native.scanner_scan(formats_json)
    socket
  end
end
