//! Rustler NIF bridge for the Dala GPU rendering runtime.
//!
//! Exposes `Dala.Gpu.Native` Elixir functions that create, command, and destroy
//! GPU surfaces backed by the `GpuRenderer` + render thread + GPU backend.

mod command;

use crate::{FrameBuffer, RenderCommand};
use rustler::{Binary, Encoder, Env, NifResult, ResourceArc, Term};
use std::sync::Mutex;

/// Resource type wrapping the GPU renderer so Rustler can pass it between NIF calls.
pub struct GpuSurface {
    renderer: Mutex<crate::GpuRenderer>,
    width: Mutex<u32>,
    height: Mutex<u32>,
}

impl GpuSurface {
    fn new(width: u32, height: u32) -> Self {
        Self {
            renderer: Mutex::new(crate::GpuRenderer::new(width, height)),
            width: Mutex::new(width),
            height: Mutex::new(height),
        }
    }
}

/// Create a new GPU surface.
#[rustler::nif]
fn surface_new<'a>(env: Env<'a>, width: u32, height: u32) -> NifResult<Term<'a>> {
    let surface = GpuSurface::new(width, height);
    let resource = ResourceArc::new(surface);
    Ok(resource.encode(env))
}

/// Destroy a GPU surface.
#[rustler::nif]
fn surface_destroy(surface: ResourceArc<GpuSurface>) -> NifResult<()> {
    drop(surface);
    Ok(())
}

/// Resize an existing GPU surface.
#[rustler::nif]
fn surface_resize(surface: ResourceArc<GpuSurface>, width: u32, height: u32) -> NifResult<()> {
    let mut w = surface.width.lock().unwrap();
    let mut h = surface.height.lock().unwrap();
    *w = width;
    *h = height;
    let renderer = surface.renderer.lock().unwrap();
    renderer.resize(width, height);
    Ok(())
}

/// Submit a binary-encoded command to the surface's command queue.
#[rustler::nif]
fn surface_command(surface: ResourceArc<GpuSurface>, cmd_binary: Binary) -> NifResult<()> {
    let cmd = command::decode_command(cmd_binary.as_slice());
    let renderer = surface.renderer.lock().unwrap();
    renderer.submit_command(cmd);
    Ok(())
}

/// Get the current pixel data as an RGBA8888 binary.
#[rustler::nif]
fn surface_get_pixels<'a>(env: Env<'a>, surface: ResourceArc<GpuSurface>) -> NifResult<Term<'a>> {
    let renderer = surface.renderer.lock().unwrap();
    let pixels = renderer.framebuffer_pixels();
    let bytes: &[u8] = &pixels;
    Ok(bytes.encode(env))
}

/// Set the pixel data directly from an RGBA8888 binary.
#[rustler::nif]
fn surface_set_pixels(surface: ResourceArc<GpuSurface>, rgba_data: Binary) -> NifResult<()> {
    let renderer = surface.renderer.lock().unwrap();
    renderer.with_back_buffer(|buf: &mut FrameBuffer| {
        let expected = (buf.width() * buf.height() * 4) as usize;
        let data = rgba_data.as_slice();
        let len = data.len().min(expected);
        buf.pixels_mut()[..len].copy_from_slice(&data[..len]);
    });
    Ok(())
}

/// Get the width of the surface.
#[rustler::nif]
fn surface_width(surface: ResourceArc<GpuSurface>) -> NifResult<u32> {
    let w = surface.width.lock().unwrap();
    Ok(*w)
}

/// Get the height of the surface.
#[rustler::nif]
fn surface_height(surface: ResourceArc<GpuSurface>) -> NifResult<u32> {
    let h = surface.height.lock().unwrap();
    Ok(*h)
}

/// Dispatch a compute shader on the GPU surface.
#[rustler::nif]
fn surface_dispatch_compute(
    surface: ResourceArc<GpuSurface>,
    shader_source: String,
    params_binary: Binary,
    workgroup_x: u32,
    workgroup_y: u32,
    workgroup_z: u32,
) -> NifResult<()> {
    let cmd = RenderCommand::DispatchCompute {
        shader_source,
        params: params_binary.as_slice().to_vec(),
        workgroup_count: (workgroup_x, workgroup_y, workgroup_z),
    };
    let renderer = surface.renderer.lock().unwrap();
    renderer.submit_command(cmd);
    Ok(())
}

/// Read pixel data back from the GPU surface.
#[rustler::nif]
fn surface_read_pixels<'a>(
    env: Env<'a>,
    surface: ResourceArc<GpuSurface>,
    x: u32,
    y: u32,
    w: u32,
    h: u32,
) -> NifResult<Term<'a>> {
    let cmd = RenderCommand::ReadPixels { x, y, w, h };
    let renderer = surface.renderer.lock().unwrap();
    renderer.submit_command(cmd);
    let pixels = renderer.framebuffer_pixels();
    let bytes: &[u8] = &pixels;
    Ok(bytes.encode(env))
}

/// Load or hot-reload a shader on the GPU surface.
#[rustler::nif]
fn surface_load_shader(
    surface: ResourceArc<GpuSurface>,
    name: String,
    source: String,
) -> NifResult<()> {
    let cmd = RenderCommand::LoadShader { name, source };
    let renderer = surface.renderer.lock().unwrap();
    renderer.submit_command(cmd);
    Ok(())
}

/// Set a uniform value on the GPU surface's current shader pipeline.
#[rustler::nif]
fn surface_set_uniform(
    surface: ResourceArc<GpuSurface>,
    name: String,
    data: Binary,
) -> NifResult<()> {
    let cmd = RenderCommand::SetUniform {
        name,
        data: data.as_slice().to_vec(),
    };
    let renderer = surface.renderer.lock().unwrap();
    renderer.submit_command(cmd);
    Ok(())
}

/// Check whether the GPU surface supports compute shaders.
#[rustler::nif]
fn surface_supports_compute(surface: ResourceArc<GpuSurface>) -> NifResult<bool> {
    let _surface = surface;
    #[cfg(any(
        all(target_os = "ios", feature = "metal"),
        all(target_os = "android", feature = "opengl")
    ))]
    {
        Ok(true)
    }
    #[cfg(not(any(
        all(target_os = "ios", feature = "metal"),
        all(target_os = "android", feature = "opengl")
    )))]
    {
        Ok(false)
    }
}

rustler::init!("Elixir.Dala.Gpu.Native", load = on_load);

fn on_load(env: Env, _info: Term) -> bool {
    #[allow(non_local_definitions)]
    let _ = rustler::resource!(GpuSurface, env);
    true
}
