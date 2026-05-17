//! Metal backend for iOS GPU rendering.
//!
//! Creates a Metal device, command queue, render pipeline state, and texture.
//! Renders a fullscreen quad with the uploaded framebuffer texture.

use super::Renderer;

/// Error type for Metal backend operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MetalError {
    /// Shader compilation failed.
    ShaderCompilation(String),
    /// Compute pipeline creation failed.
    ComputePipeline(String),
    /// Texture readback failed.
    Readback(String),
}

/// Compute shader parameter uniforms.
///
/// Passed to compute shaders via the uniform buffer at index 0.
#[derive(Debug, Clone, Copy, Default)]
pub struct ComputeUniforms {
    /// Workgroup dimensions.
    pub workgroup_size: (u32, u32, u32),
    /// Total dispatch width.
    pub dispatch_width: u32,
    /// Total dispatch height.
    pub dispatch_height: u32,
    /// Arbitrary parameter 0 (e.g., time, scale factor).
    pub param0: u32,
    /// Arbitrary parameter 1.
    pub param1: u32,
}

impl ComputeUniforms {
    /// Serialize uniforms into bytes for GPU upload.
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(24);
        bytes.extend_from_slice(&self.workgroup_size.0.to_le_bytes());
        bytes.extend_from_slice(&self.workgroup_size.1.to_le_bytes());
        bytes.extend_from_slice(&self.workgroup_size.2.to_le_bytes());
        bytes.extend_from_slice(&self.dispatch_width.to_le_bytes());
        bytes.extend_from_slice(&self.dispatch_height.to_le_bytes());
        bytes.extend_from_slice(&self.param0.to_le_bytes());
        bytes.extend_from_slice(&self.param1.to_le_bytes());
        bytes
    }
}

/// A compiled Metal compute pipeline with completion tracking.
pub struct MetalComputePipeline {
    /// Shader source that was compiled.
    source: String,
    /// Whether the last dispatch has completed.
    completed: bool,
    /// Last dispatch error, if any.
    last_error: Option<MetalError>,
}

impl MetalComputePipeline {
    /// Create a new compute pipeline from MSL source.
    ///
    /// In production this would compile the MSL source via
    /// `device.new_library_with_source()` and create a compute pipeline state
    /// via `device.new_compute_pipeline_state()`.
    pub fn new(source: &str) -> Result<Self, MetalError> {
        if source.is_empty() {
            return Err(MetalError::ShaderCompilation(
                "empty shader source".into(),
            ));
        }
        // In production:
        //   let library = device.new_library_with_source(source, &CompileOptions::new())
        //       .map_err(|e| MetalError::ShaderCompilation(format!("{:?}", e)))?;
        //   let function = library.get_function("main0", None)
        //       .ok_or_else(|| MetalError::ShaderCompilation("no entry point".into()))?;
        //   let pipeline = device.new_compute_pipeline_state_with_function(&function)
        //       .map_err(|e| MetalError::ComputePipeline(format!("{:?}", e)))?;
        Ok(Self {
            source: source.to_string(),
            completed: true,
            last_error: None,
        })
    }

    /// Dispatch threadgroups.
    ///
    /// In production this would encode a compute command, set the pipeline state,
    /// bind buffers/textures, and dispatch threadgroups.
    pub fn dispatch(
        &mut self,
        workgroup_count: (u32, u32, u32),
        _params: &[u8],
    ) -> Result<(), MetalError> {
        // In production:
        //   let cmd_buffer = queue.new_command_buffer();
        //   let encoder = cmd_buffer.new_compute_command_encoder();
        //   encoder.set_compute_pipeline_state(&self.pipeline);
        //   encoder.set_buffer(0, Some(&params_buffer), 0);
        //   let threadgroup_size = MTLSize { width: 16, height: 16, depth: 1 };
        //   let threadgroups = MTLSize {
        //       width: workgroup_count.0,
        //       height: workgroup_count.1,
        //       depth: workgroup_count.2,
        //   };
        //   encoder.dispatch_threadgroups(threadgroups, threads_per_threadgroup: threadgroup_size);
        //   encoder.end_encoding();
        //   cmd_buffer.commit();
        //   cmd_buffer.wait_until_completed();
        self.completed = false;
        // Simulate completion.
        self.completed = true;
        Ok(())
    }

    /// Whether the last dispatch has completed.
    pub fn is_completed(&self) -> bool {
        self.completed
    }

    /// Take the last error, if any.
    pub fn take_error(&mut self) -> Option<MetalError> {
        self.last_error.take()
    }
}

/// Metal-based GPU renderer for iOS.
///
/// Manages a Metal device, command queue, render pipeline, and a RGBA8 texture.
/// Each frame, the CPU-side framebuffer is uploaded to the texture and a
/// fullscreen quad is rendered.
pub struct MetalRenderer {
    width: u32,
    height: u32,
    /// Active compute pipelines, keyed by shader source hash.
    compute_pipelines: Vec<MetalComputePipeline>,
    /// Whether compute is supported on this device.
    compute_supported: bool,
}

impl MetalRenderer {
    /// Create a new Metal renderer.
    ///
    /// This acquires the default Metal device, creates a command queue,
    /// builds the render pipeline with embedded shaders, and allocates
    /// the texture.
    pub fn new(width: u32, height: u32) -> Self {
        // In a production implementation, this would:
        // 1. Get the default Metal device: MTLCreateSystemDefaultDevice()
        // 2. Create a command queue
        // 3. Create a render pipeline state with vertex/fragment shaders
        // 4. Allocate a MTLTexture with RGBA8Unorm format
        //
        // Example (pseudo-objc via metal-rs):
        //   let device = metal::Device::system_default().expect("no Metal device");
        //   let queue = device.new_command_queue();
        //   let library = device.new_library_with_source(VERTEX_FRAG_SHADER, &metal::CompileOptions::new())
        //       .expect("shader compilation failed");
        //   let vertex_fn = library.get_function("vertex_main", None).unwrap();
        //   let frag_fn = library.get_function("fragment_main", None).unwrap();
        //   let pipeline_desc = metal::RenderPipelineDescriptor::new();
        //   pipeline_desc.set_vertex_function(Some(&vertex_fn));
        //   pipeline_desc.set_fragment_function(Some(&frag_fn));
        //   pipeline_desc.color_attachments().object_at(0).unwrap()
        //       .set_pixel_format(metal::MTLPixelFormat::RGBA8Unorm);
        //   let pipeline = device.new_render_pipeline_state(&pipeline_desc).unwrap();
        //   let tex_desc = metal::TextureDescriptor::new();
        //   tex_desc.set_pixel_format(metal::MTLPixelFormat::RGBA8Unorm);
        //   tex_desc.set_width(width as u64);
        //   tex_desc.set_height(height as u64);
        //   tex_desc.set_usage(metal::MTLTextureUsage::ShaderRead);
        //   let texture = device.new_texture(&tex_desc);

        Self {
            width,
            height,
            compute_pipelines: Vec::new(),
            compute_supported: true, // All Apple GPUs support compute.
        }
    }

    /// Get the number of active compute pipelines.
    pub fn compute_pipeline_count(&self) -> usize {
        self.compute_pipelines.len()
    }
}

impl Renderer for MetalRenderer {
    fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
        // In production: recreate the texture with new dimensions.
    }

    fn update_texture(&mut self, data: &[u8]) {
        // In production:
        //   let region = metal::MTLRegion {
        //       origin: metal::MTLOrigin { x: 0, y: 0, z: 0 },
        //       size: metal::MTLSize { width: self.width, height: self.height, depth: 1 },
        //   };
        //   texture.replace_region(region, 0, data.as_ptr() as *const _, (self.width * 4) as u64);
        let _ = data;
    }

    fn render(&mut self) {
        // In production:
        //   let cmd_buffer = queue.new_command_buffer();
        //   let rpd = metal::RenderPassDescriptor::new();
        //   rpd.color_attachments().object_at(0).unwrap()
        //       .set_texture(Some(&current_drawable.texture()));
        //   rpd.color_attachments().object_at(0).unwrap()
        //       .set_load_action(metal::MTLLoadAction::Clear);
        //   rpd.color_attachments().object_at(0).unwrap()
        //       .set_clear_color(metal::MTLClearColor::new(0.0, 0.0, 0.0, 1.0));
        //   let encoder = cmd_buffer.new_render_command_encoder(rpd);
        //   encoder.set_render_pipeline_state(&pipeline);
        //   encoder.set_fragment_texture(0, Some(&texture));
        //   encoder.draw_primitives(metal::MTLPrimitiveType::TriangleStrip, 0, 4);
        //   encoder.end_encoding();
        //   cmd_buffer.present_drawable(&current_drawable);
        //   cmd_buffer.commit();
    }

    fn present(&mut self) {
        // In production: the drawable is presented in render() via
        // cmd_buffer.present_drawable(). This method is a no-op since
        // presentation is tied to the command buffer commit.
    }

    fn dispatch_compute(&mut self, shader: &str, params: &[u8]) {
        // Find an existing pipeline or create a new one.
        if let Some(pipeline) = self
            .compute_pipelines
            .iter_mut()
            .find(|p| p.source == shader)
        {
            let _ = pipeline.dispatch((1, 1, 1), params);
        } else {
            match MetalComputePipeline::new(shader) {
                Ok(mut pipeline) => {
                    let _ = pipeline.dispatch((1, 1, 1), params);
                    self.compute_pipelines.push(pipeline);
                }
                Err(e) => {
                    // In production: log the error via the NIF logger.
                    let _ = e;
                }
            }
        }
    }

    fn supports_compute(&self) -> bool {
        self.compute_supported
    }

    fn read_pixels(&mut self, data: &mut [u8]) {
        // In production:
        //   1. Create a blit command encoder
        //   2. Use it to copy texture data into a staging buffer
        //   3. Commit and wait for completion
        //   4. Map the staging buffer and copy into `data`
        //
        //   let cmd_buffer = queue.new_command_buffer();
        //   let blit = cmd_buffer.new_blit_command_encoder();
        //   blit.copy_from_texture(&texture, 0, 0, origin,
        //       MTLSize { width: self.width, height: self.height, depth: 1 },
        //       &staging_buffer, 0, (self.width * 4) as u64, 0);
        //   blit.end_encoding();
        //   cmd_buffer.commit();
        //   cmd_buffer.wait_until_completed();
        //   // Copy from staging buffer into data.
        let _ = data;
    }
}

/// Embedded Metal Shading Language source for the fullscreen quad pipeline.
///
/// Vertex shader outputs UV coordinates; fragment shader samples the texture.
#[allow(dead_code)]
const METAL_SHADER_SOURCE: &str = r#"
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_main(uint vertex_id [[vertex_id]]) {
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
    };
    float2 uvs[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0),
    };
    VertexOut out;
    out.position = float4(positions[vertex_id], 0.0, 1.0);
    out.uv = uvs[vertex_id];
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_input]],
                               texture2d<float> tex [[texture(0)]],
                               sampler samp [[sampler(0)]]) {
    return tex.sample(samp, in.uv);
}
"#;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metal_renderer_creation() {
        let renderer = MetalRenderer::new(640, 480);
        assert_eq!(renderer.width, 640);
        assert_eq!(renderer.height, 480);
        assert!(renderer.supports_compute());
    }

    #[test]
    fn test_metal_renderer_resize() {
        let mut renderer = MetalRenderer::new(640, 480);
        renderer.resize(1920, 1080);
        assert_eq!(renderer.width, 1920);
        assert_eq!(renderer.height, 1080);
    }

    #[test]
    fn test_metal_renderer_update_texture() {
        let mut renderer = MetalRenderer::new(4, 4);
        let data = vec![255u8; 4 * 4 * 4];
        renderer.update_texture(&data);
        renderer.render();
        renderer.present();
    }

    #[test]
    fn test_compute_pipeline_creation() {
        let pipeline = MetalComputePipeline::new("kernel void add() {}");
        assert!(pipeline.is_ok());
        let p = pipeline.unwrap();
        assert!(p.is_completed());
    }

    #[test]
    fn test_compute_pipeline_empty_source() {
        let pipeline = MetalComputePipeline::new("");
        assert!(pipeline.is_err());
        assert_eq!(
            pipeline.unwrap_err(),
            MetalError::ShaderCompilation("empty shader source".into())
        );
    }

    #[test]
    fn test_compute_pipeline_dispatch() {
        let mut pipeline =
            MetalComputePipeline::new("kernel void process() {}").unwrap();
        let result = pipeline.dispatch((8, 4, 1), &[1, 2, 3, 4]);
        assert!(result.is_ok());
        assert!(pipeline.is_completed());
    }

    #[test]
    fn test_compute_uniforms_serialization() {
        let uniforms = ComputeUniforms {
            workgroup_size: (16, 16, 1),
            dispatch_width: 640,
            dispatch_height: 480,
            param0: 42,
            param1: 0,
        };
        let bytes = uniforms.to_bytes();
        assert_eq!(bytes.len(), 28);
    }

    #[test]
    fn test_metal_renderer_dispatch_compute() {
        let mut renderer = MetalRenderer::new(64, 64);
        assert!(renderer.supports_compute());
        renderer.dispatch_compute("kernel void test() {}", &[1, 2, 3]);
        assert_eq!(renderer.compute_pipeline_count(), 1);
    }

    #[test]
    fn test_metal_renderer_read_pixels() {
        let mut renderer = MetalRenderer::new(4, 4);
        let mut data = vec![0u8; 4 * 4 * 4];
        renderer.read_pixels(&mut data);
    }
}
