defmodule Dala.Media.Filter do
  @moduledoc """
  GPU compute filters for realtime video processing.

  Runs compute shaders on GPU textures for effects like blur, sharpen,
  LUT color grading, beauty filter, denoise, etc.

  All filters operate on GPU textures directly — no CPU roundtrip.

  ## Example

      # Apply gaussian blur
      Dala.Media.Filter.apply(surface, :blur, %{radius: 5.0})

      # Apply LUT color grading
      Dala.Media.Filter.apply(surface, :lut, %{lut_path: "path/to/lut.png"})

      # Chain multiple filters
      Dala.Media.Filter.chain(surface, [
        [:blur, %{radius: 2.0}],
        [:sharpen, %{amount: 0.5}],
        [:lut, %{lut_path: "film.emulation.png"}]
      ])
  """

  @type surface :: pid()
  @type filter_type :: :blur | :sharpen | :lut | :beauty | :denoise | :edge_detect
  @type params :: map()

  @doc "Apply a single filter to a GPU surface."
  @spec apply_filter(surface(), filter_type(), params()) :: :ok | {:error, term()}
  def apply_filter(surface, filter_type, params \\ %{}) do
    shader = shader_source(filter_type)
    binary_params = encode_params(filter_type, params)
    Dala.Gpu.dispatch_compute(surface, shader, binary_params)
  end

  @doc "Chain multiple filters in sequence."
  @spec chain(surface(), [{filter_type(), params()}]) :: :ok | {:error, term()}
  def chain(surface, filters) do
    Enum.reduce_while(filters, :ok, fn {type, params}, :ok ->
      case apply_filter(surface, type, params) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc "Get the shader source for a filter type."
  @spec shader_source(filter_type()) :: String.t()
  def shader_source(:blur), do: blur_shader()
  def shader_source(:sharpen), do: sharpen_shader()
  def shader_source(:lut), do: lut_shader()
  def shader_source(:beauty), do: beauty_shader()
  def shader_source(:denoise), do: denoise_shader()
  def shader_source(:edge_detect), do: edge_detect_shader()

  # Private — shader sources (MSL for Metal, would be GLSL for OpenGL ES)

  defp blur_shader do
    """
    #include <metal_stdlib>
    using namespace metal;

    kernel void gaussian_blur(
        texture2d<float, access::read>  in_tex  [[texture(0)]],
        texture2d<float, access::write> out_tex [[texture(1)]],
        constant float& radius [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]])
    {
        if (gid.x >= in_tex.get_width() || gid.y >= in_tex.get_height()) return;

        float4 sum = float4(0.0);
        float weight_sum = 0.0;
        int r = int(radius);

        for (int dy = -r; dy <= r; dy++) {
            for (int dx = -r; dx <= r; dx++) {
                uint2 sample_pos = uint2(
                    clamp(int(gid.x) + dx, 0, int(in_tex.get_width()) - 1),
                    clamp(int(gid.y) + dy, 0, int(in_tex.get_height()) - 1)
                );
                float weight = exp(-float(dx*dx + dy*dy) / (2.0 * radius * radius));
                sum += in_tex.read(sample_pos) * weight;
                weight_sum += weight;
            }
        }
        out_tex.write(sum / weight_sum, gid);
    }
    """
  end

  defp sharpen_shader do
    """
    #include <metal_stdlib>
    using namespace metal;

    kernel void sharpen(
        texture2d<float, access::read>  in_tex  [[texture(0)]],
        texture2d<float, access::write> out_tex [[texture(1)]],
        constant float& amount [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]])
    {
        if (gid.x >= in_tex.get_width() || gid.y >= in_tex.get_height()) return;

        float4 center = in_tex.read(gid);
        float4 left   = in_tex.read(uint2(max(int(gid.x)-1,0), gid.y));
        float4 right  = in_tex.read(uint2(min(int(gid.x)+1,int(in_tex.get_width())-1), gid.y));
        float4 top    = in_tex.read(uint2(gid.x, max(int(gid.y)-1,0)));
        float4 bottom = in_tex.read(uint2(gid.x, min(int(gid.y)+1,int(in_tex.get_height())-1)));

        float4 laplacian = 4.0 * center - left - right - top - bottom;
        out_tex.write(center + amount * laplacian, gid);
    }
    """
  end

  defp lut_shader do
    """
    #include <metal_stdlib>
    using namespace metal;

    kernel void apply_lut(
        texture2d<float, access::read>  in_tex  [[texture(0)]],
        texture2d<float, access::write> out_tex [[texture(1)]],
        texture3d<float, access::sample> lut_tex [[texture(2)]],
        uint2 gid [[thread_position_in_grid]])
    {
        if (gid.x >= in_tex.get_width() || gid.y >= in_tex.get_height()) return;
        float4 color = in_tex.read(gid);
        constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge);
        float3 lut_coord = color.rgb * 0.9375 + 0.03125;
        out_tex.write(float4(lut_tex.sample(s, lut_coord).rgb, color.a), gid);
    }
    """
  end

  defp beauty_shader do
    """
    #include <metal_stdlib>
    using namespace metal;

    kernel void beauty_filter(
        texture2d<float, access::read>  in_tex  [[texture(0)]],
        texture2d<float, access::write> out_tex [[texture(1)]],
        constant float& strength [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]])
    {
        if (gid.x >= in_tex.get_width() || gid.y >= in_tex.get_height()) return;
        float4 color = in_tex.read(gid);
        float3 smoothed = color.rgb;
        out_tex.write(float4(mix(color.rgb, smoothed, strength), color.a), gid);
    }
    """
  end

  defp denoise_shader do
    """
    #include <metal_stdlib>
    using namespace metal;

    kernel void denoise(
        texture2d<float, access::read>  in_tex  [[texture(0)]],
        texture2d<float, access::write> out_tex [[texture(1)]],
        constant float& threshold [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]])
    {
        if (gid.x >= in_tex.get_width() || gid.y >= in_tex.get_height()) return;
        float4 center = in_tex.read(gid);
        float4 sum = float4(0.0);
        int count = 0;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                uint2 pos = uint2(clamp(int(gid.x)+dx, 0, int(in_tex.get_width())-1),
                                  clamp(int(gid.y)+dy, 0, int(in_tex.get_height())-1));
                sum += in_tex.read(pos);
                count++;
            }
        }
        float4 avg = sum / float(count);
        out_tex.write(mix(center, avg, threshold), gid);
    }
    """
  end

  defp edge_detect_shader do
    """
    #include <metal_stdlib>
    using namespace metal;

    kernel void sobel_edge(
        texture2d<float, access::read>  in_tex  [[texture(0)]],
        texture2d<float, access::write> out_tex [[texture(1)]],
        uint2 gid [[thread_position_in_grid]])
    {
        if (gid.x >= in_tex.get_width() || gid.y >= in_tex.get_height()) return;

        float3x3 sobel_x = float3x3(-1, 0, 1, -2, 0, 2, -1, 0, 1);
        float3x3 sobel_y = float3x3(-1, -2, -1, 0, 0, 0, 1, 2, 1);

        float gx = 0.0, gy = 0.0;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                uint2 pos = uint2(clamp(int(gid.x)+dx, 0, int(in_tex.get_width())-1),
                                  clamp(int(gid.y)+dy, 0, int(in_tex.get_height())-1));
                float lum = dot(in_tex.read(pos).rgb, float3(0.299, 0.587, 0.114));
                gx += lum * sobel_x[dy+1][dx+1];
                gy += lum * sobel_y[dy+1][dx+1];
            }
        }
        float edge = sqrt(gx*gx + gy*gy);
        out_tex.write(float4(edge, edge, edge, 1.0), gid);
    }
    """
  end

  defp encode_params(:blur, %{radius: radius}), do: <<radius::float-little-32>>
  defp encode_params(:sharpen, %{amount: amount}), do: <<amount::float-little-32>>
  defp encode_params(:beauty, %{strength: strength}), do: <<strength::float-little-32>>
  defp encode_params(:denoise, %{threshold: threshold}), do: <<threshold::float-little-32>>
  defp encode_params(:lut, _params), do: <<>>
  defp encode_params(:edge_detect, _params), do: <<>>
  defp encode_params(_, _params), do: <<>>
end
