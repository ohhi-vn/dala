//! Renderer backend trait and factory.

pub mod buffer;

#[cfg(all(target_os = "ios", feature = "metal"))]
mod metal;
#[cfg(all(target_os = "android", feature = "opengl"))]
mod opengl;

/// Trait for GPU rendering backends.
///
/// Each backend manages its own GPU resources (textures, shaders, pipeline state)
/// and provides a common interface for the render thread.
pub trait Renderer: Send {
    /// Resize GPU resources (textures, viewport, etc.).
    fn resize(&mut self, width: u32, height: u32);

    /// Upload pixel data to the GPU texture.
    ///
    /// `data` must be `width * height * 4` bytes (RGBA8888).
    fn update_texture(&mut self, data: &[u8]);

    /// Render the fullscreen quad with the uploaded texture.
    fn render(&mut self);

    /// Present the rendered frame to the display.
    fn present(&mut self);

    /// Dispatch a compute shader.
    ///
    /// `shader` is the shader source code (MSL for Metal, GLSL compute for OpenGL ES).
    /// `params` is opaque parameter data passed to the shader.
    ///
    /// Default implementation is a no-op.
    fn dispatch_compute(&mut self, _shader: &str, _params: &[u8]) {
        // no-op
    }

    /// Whether this backend supports compute shaders.
    ///
    /// Default is `false`.
    fn supports_compute(&self) -> bool {
        false
    }

    /// Read back GPU texture data into the provided buffer.
    ///
    /// `data` must be large enough to hold the requested region.
    /// Default implementation is a no-op.
    fn read_pixels(&mut self, _data: &mut [u8]) {
        // no-op
    }
}

/// Which backend was compiled in.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Backend {
    /// Metal backend (iOS).
    Metal,
    /// OpenGL ES backend (Android).
    OpenGL,
    /// No GPU backend available (stub).
    Stub,
}

/// Create the appropriate GPU backend for the current platform.
#[cfg(all(target_os = "ios", feature = "metal"))]
pub fn create_backend(width: u32, height: u32) -> Box<dyn Renderer> {
    Box::new(metal::MetalRenderer::new(width, height))
}

#[cfg(all(target_os = "android", feature = "opengl"))]
pub fn create_backend(width: u32, height: u32) -> Box<dyn Renderer> {
    Box::new(opengl::OpenGlRenderer::new(width, height))
}

/// Fallback stub backend when no GPU backend is available.
#[cfg(not(any(
    all(target_os = "ios", feature = "metal"),
    all(target_os = "android", feature = "opengl")
)))]
pub fn create_backend(width: u32, height: u32) -> Box<dyn Renderer> {
    Box::new(StubRenderer { width, height })
}

/// A no-op renderer for testing and platforms without GPU support.
pub struct StubRenderer {
    width: u32,
    height: u32,
}

impl Renderer for StubRenderer {
    fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }

    fn update_texture(&mut self, _data: &[u8]) {
        // no-op
    }

    fn render(&mut self) {
        // no-op
    }

    fn present(&mut self) {
        // no-op
    }

    fn dispatch_compute(&mut self, _shader: &str, _params: &[u8]) {
        // no-op
    }

    fn supports_compute(&self) -> bool {
        false
    }

    fn read_pixels(&mut self, _data: &mut [u8]) {
        // no-op
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stub_renderer_default_compute() {
        let mut renderer = StubRenderer {
            width: 640,
            height: 480,
        };
        assert!(!renderer.supports_compute());
        renderer.dispatch_compute("kernel void test()", &[1, 2, 3]);
        let mut buf = vec![0u8; 16];
        renderer.read_pixels(&mut buf);
    }
}
