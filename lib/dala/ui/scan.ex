defmodule Dala.Ui.Scan do
  @moduledoc """
  Parsers for common NFC tag payloads and QR/barcode content.

  Takes a raw string from an NFC tag read or barcode scan and returns a
  structured map with `:type` and `:value` fields.

  ## Supported formats

  | Type | Example raw input | `:value` shape |
  |------|-------------------|-----------------|
  | `:url` | `https://example.com` | `String.t()` |
  | `:wifi` | `WIFI:T:WPA;S:MyNet;P:pass;H:true;;` | `%{ssid, password, security, hidden}` |
  | `:email` | `mailto:user@example.com` | `%{email, subject, body}` |
  | `:phone` | `tel:+1234567890` | `%{number}` |
  | `:sms` | `smsto:+1234567890:hello` | `%{number, message}` |
  | `:geo` | `geo:37.78,-122.40?q=Golden+Gate` | `%{lat, lon, query, altitude}` |
  | `:vcard` | `BEGIN:VCARD...END:VCARD` | `%{name, phone, email, org, title, url, address}` |
  | `:vevent` | `BEGIN:VEVENT...END:VEVENT` | `%{summary, start, end, location, description}` |
  | `:text` | `Hello world` | `String.t()` |

  ## Usage

      # Parse an NFC tag payload
      Dala.Ui.Scan.parse("WIFI:T:WPA;S:MyNet;P:secret;;")
      # => %{type: :wifi, value: %{ssid: "MyNet", password: "secret", security: :wpa, hidden: false}}

      # Parse a QR code value
      Dala.Ui.Scan.parse("https://example.com")
      # => %{type: :url, value: "https://example.com"}

      # Parse a vCard
      Dala.Ui.Scan.parse("BEGIN:VCARD\\nVERSION:3.0\\nFN:John Doe\\nTEL:+1234567890\\nEND:VCARD")
      # => %{type: :vcard, value: %{name: "John Doe", phone: "+1234567890", ...}}
  """

  @type parsed :: %{
          type: :url | :wifi | :email | :phone | :sms | :geo | :vcard | :vevent | :text,
          value: term()
        }

  @doc """
  Parse a raw NFC/barcode string into a structured format.

  Returns `%{type: atom, value: term()}` or `%{type: :text, value: raw}` as fallback.
  """
  @spec parse(String.t()) :: parsed()
  def parse(raw) when is_binary(raw) do
    cond do
      wifi?(raw) -> parse_wifi(raw)
      email?(raw) -> parse_email(raw)
      phone?(raw) -> parse_phone(raw)
      sms?(raw) -> parse_sms(raw)
      geo?(raw) -> parse_geo(raw)
      vcard?(raw) -> parse_vcard(raw)
      vevent?(raw) -> parse_vevent(raw)
      url?(raw) -> %{type: :url, value: raw}
      true -> %{type: :text, value: raw}
    end
  end

  # ── URL ──────────────────────────────────────────────────────────────────

  @url_schemes ["http://", "https://", "ftp://", "ftps://"]

  defp url?(raw) do
    Enum.any?(@url_schemes, &String.starts_with?(raw, &1))
  end

  # ── WiFi ─────────────────────────────────────────────────────────────────

  # Format: WIFI:T:<security>;S:<ssid>;P:<password>;H:<true|false>;;
  defp wifi?(raw) do
    String.starts_with?(String.upcase(raw), "WIFI:")
  end

  defp parse_wifi(raw) do
    rest = String.slice(raw, 5..-1//1)
    parts = String.split(rest, ";", trim: true)

    attrs =
      Enum.reduce(parts, %{}, fn part, acc ->
        case String.split(part, ":", parts: 2) do
          [key, value] -> Map.put(acc, String.downcase(key), value)
          _ -> acc
        end
      end)

    security =
      case String.upcase(Map.get(attrs, "t", "")) do
        "WPA" -> :wpa
        "WEP" -> :wep
        "NOPASS" -> :open
        _ -> :unknown
      end

    %{
      type: :wifi,
      value: %{
        ssid: Map.get(attrs, "s", ""),
        password: Map.get(attrs, "p", ""),
        security: security,
        hidden: String.upcase(Map.get(attrs, "h", "false")) == "TRUE"
      }
    }
  end

  # ── Email (mailto:) ──────────────────────────────────────────────────────

  defp email?(raw) do
    String.starts_with?(String.downcase(raw), "mailto:")
  end

  defp parse_email(raw) do
    rest = String.slice(raw, 7..-1//1)

    {email, params} =
      case String.split(rest, "?", parts: 2) do
        [e, p] -> {e, p}
        [e] -> {e, ""}
      end

    query = parse_query_string(params)

    %{
      type: :email,
      value: %{
        email: email,
        subject: Map.get(query, "subject", ""),
        body: Map.get(query, "body", "")
      }
    }
  end

  # ── Phone (tel:) ─────────────────────────────────────────────────────────

  defp phone?(raw) do
    String.starts_with?(String.downcase(raw), "tel:")
  end

  defp parse_phone(raw) do
    number = String.slice(raw, 4..-1//1)
    %{type: :phone, value: %{number: number}}
  end

  # ── SMS (smsto:) ─────────────────────────────────────────────────────────

  defp sms?(raw) do
    String.starts_with?(String.downcase(raw), "smsto:")
  end

  defp parse_sms(raw) do
    rest = String.slice(raw, 6..-1//1)

    case String.split(rest, ":", parts: 2) do
      [number, message] -> %{type: :sms, value: %{number: number, message: message}}
      [number] -> %{type: :sms, value: %{number: number, message: ""}}
    end
  end

  # ── Geo ──────────────────────────────────────────────────────────────────

  defp geo?(raw) do
    String.starts_with?(String.downcase(raw), "geo:")
  end

  defp parse_geo(raw) do
    rest = String.slice(raw, 4..-1//1)

    {coords, query} =
      case String.split(rest, "?", parts: 2) do
        [c, q] -> {c, q}
        [c] -> {c, ""}
      end

    params = parse_query_string(query)

    {lat, lon} =
      case String.split(coords, ",", parts: 3) do
        [la, lo | _] -> {parse_float(la), parse_float(lo)}
        _ -> {nil, nil}
      end

    altitude =
      case params do
        %{"altitude" => alt} -> parse_float(alt)
        _ -> nil
      end

    %{
      type: :geo,
      value: %{
        lat: lat,
        lon: lon,
        altitude: altitude,
        query: Map.get(params, "q", "")
      }
    }
  end

  # ── vCard ────────────────────────────────────────────────────────────────

  defp vcard?(raw) do
    String.contains?(String.upcase(raw), "BEGIN:VCARD")
  end

  defp parse_vcard(raw) do
    lines = String.split(raw, ~r/\r?\n/, trim: false)

    {name, phone, email, org, title, url, address} =
      Enum.reduce(lines, {"", "", "", "", "", "", ""}, fn line, {n, p, e, o, t, u, a} ->
        up = String.upcase(line)

        cond do
          String.starts_with?(up, "FN:") ->
            {String.slice(line, 3..-1//1), p, e, o, t, u, a}

          String.starts_with?(up, "N:") ->
            parts = String.split(String.slice(line, 2..-1//1), ";")
            name_val = Enum.join([Enum.at(parts, 1), Enum.at(parts, 0)] |> Enum.filter(& &1), " ")
            {name_val, p, e, o, t, u, a}

          String.starts_with?(up, "TEL") ->
            val = extract_vcard_value(line)
            {n, val, e, o, t, u, a}

          String.starts_with?(up, "EMAIL") ->
            val = extract_vcard_value(line)
            {n, p, val, o, t, u, a}

          String.starts_with?(up, "ORG:") ->
            {n, p, e, String.slice(line, 4..-1//1), t, u, a}

          String.starts_with?(up, "TITLE:") ->
            {n, p, e, o, String.slice(line, 6..-1//1), u, a}

          String.starts_with?(up, "URL:") ->
            {n, p, e, o, t, String.slice(line, 4..-1//1), a}

          String.starts_with?(up, "ADR") ->
            val = extract_vcard_value(line) |> String.replace(";", ", ")
            {n, p, e, o, t, u, val}

          true ->
            {n, p, e, o, t, u, a}
        end
      end)

    %{
      type: :vcard,
      value: %{
        name: name,
        phone: phone,
        email: email,
        org: org,
        title: title,
        url: url,
        address: address
      }
    }
  end

  defp extract_vcard_value(line) do
    case String.split(line, ":", parts: 2) do
      [_, value] -> value
      _ -> ""
    end
  end

  # ── VEvent (calendar) ────────────────────────────────────────────────────

  defp vevent?(raw) do
    String.contains?(String.upcase(raw), "BEGIN:VEVENT")
  end

  defp parse_vevent(raw) do
    lines = String.split(raw, ~r/\r?\n/, trim: false)

    {summary, start, end_, location, description} =
      Enum.reduce(lines, {"", "", "", "", ""}, fn line, {s, st, en, loc, desc} ->
        up = String.upcase(line)

        cond do
          String.starts_with?(up, "SUMMARY:") ->
            {String.slice(line, 8..-1//1), st, en, loc, desc}

          String.starts_with?(up, "DTSTART") ->
            val = extract_vcard_value(line)
            {s, val, en, loc, desc}

          String.starts_with?(up, "DTEND") ->
            val = extract_vcard_value(line)
            {s, st, val, loc, desc}

          String.starts_with?(up, "LOCATION:") ->
            {s, st, en, String.slice(line, 9..-1//1), desc}

          String.starts_with?(up, "DESCRIPTION:") ->
            {s, st, en, loc, String.slice(line, 12..-1//1)}

          true ->
            {s, st, en, loc, desc}
        end
      end)

    %{
      type: :vevent,
      value: %{
        summary: summary,
        start: start,
        end: end_,
        location: location,
        description: description
      }
    }
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp parse_query_string(""), do: %{}

  defp parse_query_string(query) do
    query
    |> String.split("&", trim: true)
    |> Enum.reduce(%{}, fn pair, acc ->
      case String.split(pair, "=", parts: 2) do
        [key, value] -> Map.put(acc, key, URI.decode(value))
        [key] -> Map.put(acc, key, "")
      end
    end)
  end

  defp parse_float(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error -> nil
    end
  end
end
