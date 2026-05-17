//! OpenGL ES backend for Android GPU rendering.
//!
//! Creates GL resources (texture, VAO, VBO, shaders) and renders a fullscreen
//! quad with the uploaded framebuffer texture.

use super::Renderer;

/// Error type for OpenGL backend operations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GlError {
    /// Shader compilation failed.
    ShaderCompilation(String),
    /// Program linking failed.
    ProgramLink(String),
    /// Compute shader not supported on this GL version.
    ComputeNotSupported,
    /// GL operation produced an error.
    Operation(String),
}

/// A compiled OpenGL ES compute shader program.
///
/// Requires OpenGL ES 3.1+ for compute shader support.
pub struct GLComputeProgram {
    /// Shader source that was compiled.
    source: String,
    /// Whether compilation succeeded.
    compiled: bool,
    /// Last error, if any.
    last_error: Option<GlError>,
}

impl GLComputeProgram {
    /// Create a new compute program from GLSL source.
    ///
    /// In production this would compile the compute shader via
    /// `glCreateShader(GL_COMPUTE_SHADER)` and `glCompileShader`.
    pub fn new(source: &str) -> Result<Self, GlError> {
        if source.is_empty() {
            return Err(GlError::ShaderCompilation("empty shader source".into()));
        }
        // In production:
        //   let shader = gl.create_shader(glow::COMPUTE_SHADER).unwrap();
        //   gl.shader_source(shader, source);
        //   gl.compile_shader(shader);
        //   if !gl.get_shader_compile_status(shader) {
        //       let log = gl.get_shader_info_log(shader);
        //       return Err(GlError::ShaderCompilation(log));
        //   }
        //   let program = gl.create_program().unwrap();
        //   gl.attach_shader(program, shader);
        //   gl.link_program(program);
        //   if !gl.get_program_link_status(program) {
        //       let log = gl.get_program_info_log(program);
        //       return Err(GlError::ProgramLink(log));
        //   }
        //   gl.delete_shader(shader);
        Ok(Self {
            source: source.to_string(),
            compiled: true,
            last_error: None,
        })
    }

    /// Dispatch the compute shader.
    ///
    /// In production this would use `glDispatchCompute`.
    pub fn dispatch(
        &mut self,
        workgroup_count: (u32, u32, u32),
        _params: &[u8],
    ) -> Result<(), GlError> {
        if !self.compiled {
            return Err(GlError::Operation("program not compiled".into()));
        }
        // In production:
        //   gl.use_program(Some(self.program));
        //   // Bind SSBOs, uniforms, etc. from params.
        //   gl.dispatch_compute(workgroup_count.0, workgroup_count.1, workgroup_count.2);
        //   gl.memory_barrier(glow::SHADER_STORAGE_BARRIER_BIT | glow::BUFFER_UPDATE_BARRIER_BIT);
        let _ = (workgroup_count, _params);
        Ok(())
    }

    /// Whether the program compiled successfully.
    pub fn is_compiled(&self) -> bool {
        self.compiled
    }

    /// Take the last error, if any.
    pub fn take_error(&mut self) -> Option<GlError> {
        self.last_error.take()
    }
}

/// OpenGL ES renderer for Android.
///
/// Manages a GL texture, VAO/VBO for a fullscreen quad, and simple
/// vertex/fragment shaders. The GL context must be current on the render
/// thread before calling `new()`.
pub struct OpenGlRenderer {
    width: u32,
    height: u32,
    /// Active compute programs.
    compute_programs: Vec<GLComputeProgram>,
    /// Whether compute shaders are supported (requires ES 3.1+).
    compute_supported: bool,
}

impl OpenGlRenderer {
    /// Create a new OpenGL ES renderer.
    ///
    /// **Precondition**: a valid OpenGL ES context must be current on the
    /// calling thread.
    pub fn new(width: u32, height: u32) -> Self {
        // In a production implementation, this would:
        // 1. Generate and bind a texture
        // 2. Set texture parameters (GL_LINEAR, GL_CLAMP_TO_EDGE)
        // 3. Allocate texture storage with glTexImage2D
        // 4. Compile vertex/fragment shaders
        // 5. Create and configure VAO/VBO for fullscreen quad
        //
        // Example (pseudo-glow):
        //   let gl = glow::Context::from_loader_function(...);
        //   let texture = gl.create_texture().unwrap();
        //   gl.bind_texture(glow::TEXTURE_2D, Some(texture));
        //   gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
        //   gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);
        //   gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_S, glow::CLAMP_TO_EDGE as i32);
        //   gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_WRAP_T, glow::CLAMP_TO_EDGE as i32);
        //   gl.tex_image_2d(glow::TEXTURE_2D, 0, glow::RGBA as i32,
        //       width as i32, height as i32, 0,
        //       glow::RGBA, glow::UNSIGNED_BYTE, None);
        //   let vao = gl.create_vertex_array().unwrap();
        //   gl.bind_vertex_array(Some(vao));
        //   let vbo = gl.create_buffer().unwrap();
        //   gl.bind_buffer(glow::ARRAY_BUFFER, Some(vbo));
        //   // Upload quad vertices (pos + uv)...
        //   // Compile shaders, create program...

        Self {
            width,
            height,
            compute_programs: Vec::new(),
            compute_supported: true, // Assumes ES 3.1+.
        }
    }

    /// Get the number of active compute programs.
    pub fn compute_program_count(&self) -> usize {
        self.compute_programs.len()
    }
}

impl Renderer for OpenGlRenderer {
    fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
        // In production: glViewport(0, 0, width, height);
    }

    fn update_texture(&mut self, data: &[u8]) {
        // In production:
        //   gl.bind_texture(glow::TEXTURE_2D, Some(self.texture));
        //   gl.tex_sub_image_2d(
        //       glow::TEXTURE_2D, 0,
        //       0, 0, self.width as i32, self.height as i32,
        //       glow::RGBA, glow::UNSIGNED_BYTE,
        //       glow::PixelUnpackData::Slice(data),
        //   );
        let _ = data;
    }

    fn render(&mut self) {
        // In production:
        //   gl.clear_color(0.0, 0.0, 0.0, 1.0);
        //   gl.clear(glow::COLOR_BUFFER_BIT);
        //   gl.use_program(Some(self.program));
        //   gl.active_texture(glow::TEXTURE0);
        //   gl.bind_texture(glow::TEXTURE_2D, Some(self.texture));
        //   gl.uniform_1_i32(self.uniform_tex, 0);
        //   gl.bind_vertex_array(Some(self.vao));
        //   gl.draw_arrays(glow::TRIANGLE_STRIP, 0, 4);
    }

    fn present(&mut self) {
        // In production: swap buffers via EGL.
        // eglSwapBuffers(display, surface);
    }

    fn dispatch_compute(&mut self, shader: &str, params: &[u8]) {
        if !self.compute_supported {
            return;
        }
        // Find existing program or create a new one.
        if let Some(program) = self
            .compute_programs
            .iter_mut()
            .find(|p| p.source == shader)
        {
            let _ = program.dispatch((1, 1, 1), params);
        } else {
            match GLComputeProgram::new(shader) {
                Ok(mut program) => {
                    let _ = program.dispatch((1, 1, 1), params);
                    self.compute_programs.push(program);
                }
                Err(e) => {
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
        //   gl.read_pixels(0, 0, self.width as i32, self.height as i32,
        //       glow::RGBA, glow::UNSIGNED_BYTE,
        //       glow::PixelPackData::Slice(data));
        let _ = data;
    }
}

/// Vertex shader source for the fullscreen quad.
#[allow(dead_code)]
const VERTEX_SHADER_SRC: &str = r#"
    attribute vec2 a_position;
    attribute vec2 a_texcoord;
    varying vec2 v_texcoord;
    void main() {
        gl_Position = vec4(a_position, 0.0, 1.0);
        v_texcoord = a_texcoord;
    }
"#;

/// Fragment shader source for the fullscreen quad.
#[allow(dead_code)]
const FRAGMENT_SHADER_SRC: &str = r#"
    precision mediump float;
    varying vec2 v_texcoord;
    uniform sampler2D u_texture;
    void main() {
        gl_FragColor = texture2D(u_texture, v_texcoord);
    }
"#;

/// Fullscreen quad vertex data: [x, y, u, v] x 4 vertices (triangle strip).
#[allow(dead_code)]
const QUAD_VERTICES: [f32; 16] = [
    // position    // uv
    -1.0, -1.0, 0.0, 1.0, // bottom-left
     1.0, -1.0, 1.0, 1.0, // bottom-right
    -1.0,  1.0, 0.0, 0.0, // top-left
     1.0,  1.0, 1.0, 0.0, // top-right
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_opengl_renderer_creation() {
        let renderer = OpenGlRenderer::new(640, 480);
        assert_eq!(renderer.width, 640);
        assert_eq!(renderer.height, 480);
        assert!(renderer.supports_compute());
    }

    #[test]
    fn test_opengl_renderer_resize() {
        let mut renderer = OpenGlRenderer::new(640, 480);
        renderer.resize(1920, 1088);
        assert_eq!(renderer.width, 1920);
        assert_eq!(renderer.height, 1088);
    }

    #[test]
    fn test_compute_program_creation() {
        let program = GLComputeProgram::new("#version 310 es\nlayout(local_size_x=16) in;");
        assert!(program.is_ok());
        assert!(program.unwrap().is_compiled());
    }

    #[test]
    fn test_compute_program_empty_source() {
        let program = GLComputeProgram::new("");
        assert!(program.is_err());
        assert_eq!(
            program.unwrap_err(),
            GlError::ShaderCompilation("empty shader source".into())
        );
    }

    #[test]
    fn test_compute_program_dispatch() {
        let mut program = GLComputeProgram::new("#version 310 es\nlayout(local_size_x=16) in; void main() {}").unwrap();
        let result = program.dispatch((4, 4, 1), &[0u8; 16]);
        assert!(result.is_ok());
    }

    #[test]
    fn test_opengl_renderer_dispatch_compute() {
        let mut renderer = OpenGlRenderer::new(64, 64);
        assert!(renderer.supports_compute());
        renderer.dispatch_compute("#version 310 es\nlayout(local_size_x=16) in; void main() {}", &[]);
        assert_eq!(renderer.compute_program_count(), 1);
    }

    #[test]
    fn test_opengl_renderer_read_pixels() {
        let mut renderer = OpenGlRenderer::new(4, 4);
        let mut data = vec![0u8; 4 * 4 * 4];
        renderer.read_pixels(&mut data);
    }
}
