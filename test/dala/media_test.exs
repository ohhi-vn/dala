defmodule Dala.MediaTest do
  use ExUnit.Case, async: true

  alias Dala.Media.{
    Clock,
    Subtitle,
    Filter,
    Animation,
    Adaptive,
  }

  describe "clock" do
    test "starts and stops ticking" do
      {:ok, clock} = Clock.start_link(target_fps: 60)
      assert Clock.drift(clock) == 0
      Clock.start_ticking(clock)
      Clock.stop_ticking(clock)
      stats = Clock.stats(clock)
      assert stats.target_fps == 60
    end

    test "subscribe and unsubscribe" do
      {:ok, clock} = Clock.start_link(target_fps: 60)
      Clock.subscribe(clock, self())
      Clock.unsubscribe(clock, self())
    end

    test "audio clock update" do
      {:ok, clock} = Clock.start_link(target_fps: 60)
      Clock.update_audio_clock(clock, 1_000_000)
      assert Clock.drift(clock) == 1_000_000
    end

    test "video frame report" do
      {:ok, clock} = Clock.start_link(target_fps: 60)
      Clock.update_audio_clock(clock, 1_000_000)
      Clock.report_video_frame(clock, 950_000)
      # Drift should be audio_clock - video_clock = 50000
      assert Clock.drift(clock) == 50_000
    end
  end

  describe "subtitle parsing" do
    test "parses valid SRT content" do
      srt = """
      1
      00:00:01,000 --> 00:00:04,000
      Hello world

      2
      00:00:05,500 --> 00:00:08,000
      Second subtitle
      """

      assert {:ok, cues} = Subtitle.parse_srt(srt)
      assert length(cues) == 2
      assert hd(cues).text == "Hello world"
      assert hd(cues).start_ms == 1_000
      assert hd(cues).end_ms == 4_000
    end

    test "parses SRT with multiline text" do
      srt = """
      1
      00:00:01,000 --> 00:00:04,000
      Line one
      Line two
      """

      assert {:ok, cues} = Subtitle.parse_srt(srt)
      assert hd(cues).text == "Line one\nLine two"
    end

    test "finds active cue" do
      cues = [
        %{id: 1, start_ms: 0, end_ms: 3000, text: "First", style: %{}},
        %{id: 2, start_ms: 3000, end_ms: 6000, text: "Second", style: %{}},
        %{id: 3, start_ms: 6000, end_ms: 9000, text: "Third", style: %{}},
      ]

      assert Subtitle.active_cue(cues, 1_500_000).text == "First"
      assert Subtitle.active_cue(cues, 4_500_000).text == "Second"
      assert Subtitle.active_cue(cues, 7_500_000).text == "Third"
      assert Subtitle.active_cue(cues, 10_000_000) == nil
    end

    test "gets cues in range" do
      cues = [
        %{id: 1, start_ms: 0, end_ms: 3000, text: "First", style: %{}},
        %{id: 2, start_ms: 3000, end_ms: 6000, text: "Second", style: %{}},
        %{id: 3, start_ms: 6000, end_ms: 9000, text: "Third", style: %{}},
      ]

      result = Subtitle.cues_in_range(cues, 2_000_000, 5_000_000)
      assert length(result) == 2
    end

    test "formats cue as overlay" do
      cue = %{id: 1, start_ms: 0, end_ms: 3000, text: "Hello", style: %{}}
      overlay = Subtitle.to_overlay(cue, position: {10, 20}, font_size: 32)
      assert overlay.text == "Hello"
      assert overlay.position == {10, 20}
      assert overlay.font_size == 32
    end

    test "parses WebVTT content" do
      vtt = """
      WEBVTT

      00:00:01.000 --> 00:00:04.000
      Hello from VTT

      00:00:05.500 --> 00:00:08.000
      Second VTT cue
      """

      assert {:ok, cues} = Subtitle.parse_vtt(vtt)
      assert length(cues) == 2
      assert hd(cues).text == "Hello from VTT"
    end

    test "rejects invalid VTT" do
      assert {:error, :invalid_vtt_header} = Subtitle.parse_vtt("NOT A VTT FILE")
    end
  end

  describe "filter" do
    test "returns shader sources for all filter types" do
      assert is_binary(Filter.shader_source(:blur))
      assert is_binary(Filter.shader_source(:sharpen))
      assert is_binary(Filter.shader_source(:lut))
      assert is_binary(Filter.shader_source(:beauty))
      assert is_binary(Filter.shader_source(:denoise))
      assert is_binary(Filter.shader_source(:edge_detect))
    end

    test "blur shader contains kernel function" do
      shader = Filter.shader_source(:blur)
      assert shader =~ "gaussian_blur"
      assert shader =~ "kernel"
    end

    test "edge detect shader contains sobel" do
      shader = Filter.shader_source(:edge_detect)
      assert shader =~ "sobel_edge"
      assert shader =~ "sobel_x"
      assert shader =~ "sobel_y"
    end

    test "encodes params correctly" do
      assert is_binary(Filter.apply_filter(nil, :blur, %{radius: 5.0}))
    end
  end

  describe "animation" do
    test "starts animation system" do
      {:ok, anim} = Animation.start_link([])
    end

    test "creates animation" do
      {:ok, anim} = Animation.start_link([])
      {:ok, id} = Animation.animate(anim, make_ref(), :opacity, %{
        from: 0.0,
        to: 1.0,
        duration_ms: 500,
        easing: :ease_in_out
      })
      assert is_reference(id)
    end

    test "cancels animation" do
      {:ok, anim} = Animation.start_link([])
      {:ok, id} = Animation.animate(anim, make_ref(), :opacity, %{
        from: 0.0,
        to: 1.0,
        duration_ms: 500,
      })
      assert :ok = Animation.cancel(anim, id)
    end

    test "cancels all animations for a node" do
      {:ok, anim} = Animation.start_link([])
      node_id = make_ref()
      Animation.animate(anim, node_id, :opacity, %{from: 0.0, to: 1.0, duration_ms: 500})
      Animation.animate(anim, node_id, :position, %{from: {0, 0}, to: {100, 200}, duration_ms: 500})
      assert :ok = Animation.cancel_all(anim, node_id)
    end
  end

  describe "adaptive bitrate" do
    test "starts with default config" do
      {:ok, adapter} = Adaptive.start_link([])
      assert Adaptive.get_state(adapter) == :stable
      assert Adaptive.recommended_bitrate(adapter) == 4_000_000
    end

    test "starts with custom config" do
      {:ok, adapter} = Adaptive.start_link(min_bitrate: 100_000, max_bitrate: 2_000_000)
      assert Adaptive.recommended_bitrate(adapter) == 2_000_000
    end

    test "reports stats without crashing" do
      {:ok, adapter} = Adaptive.start_link([])
      Adaptive.report_stats(adapter, %{
        bytes_received: 50000,
        packets_lost: 0,
        packets_received: 100,
        jitter_ms: 10,
        rtt_ms: 50,
      })
    end

    test "degrades on high packet loss" do
      {:ok, adapter} = Adaptive.start_link(adjustment_interval_ms: 0)

      # Report high packet loss
      for _ <- 1..5 do
        Adaptive.report_stats(adapter, %{
          bytes_received: 50000,
          packets_lost: 10,
          packets_received: 90,
          jitter_ms: 10,
          rtt_ms: 50,
        })
      end

      # Should have degraded
      assert Adaptive.recommended_bitrate(adapter) < 4_000_000
    end

    test "recommended resolution scales with bitrate" do
      {:ok, adapter} = Adaptive.start_link(adjustment_interval_ms: 0)

      # Force degradation
      for _ <- 1..10 do
        Adaptive.report_stats(adapter, %{
          bytes_received: 10000,
          packets_lost: 20,
          packets_received: 80,
          jitter_ms: 100,
          rtt_ms: 200,
        })
      end

      {w, h} = Adaptive.recommended_resolution(adapter)
      assert w <= 1920
      assert h <= 1080
    end

    test "diagnostic returns full info" do
      {:ok, adapter} = Adaptive.start_link([])
      diag = Adaptive.diagnostic(adapter)
      assert Map.has_key?(diag, :state)
      assert Map.has_key?(diag, :current_bitrate)
      assert Map.has_key?(diag, :resolution)
    end
  end
end
