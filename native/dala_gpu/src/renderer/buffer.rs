//! GPU buffer abstraction.
//!
//! Provides a unified interface for CPU-visible (staging) and GPU-local buffers,
//! with support for vertex, index, uniform, and storage usage modes.
//!
//! These types are placeholders for the Phase 2 GPU buffer abstraction.
//! They are not yet wired into the render thread.

#![allow(dead_code)]

/// How a GPU buffer is intended to be used.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BufferUsage {
    /// Vertex buffer: holds vertex attribute data (positions, UVs, colors, etc.).
    Vertex,
    /// Index buffer: holds element indices for indexed drawing.
    Index,
    /// Uniform buffer: read-only shader constants, small and frequently updated.
    Uniform,
    /// Storage buffer: read/write shared memory for compute shaders.
    Storage,
    /// Staging buffer: CPU-visible, used to transfer data to GPU-local buffers.
    Staging,
}

/// Trait for GPU-accessible buffers.
///
/// Implemented by `StagingBuffer` (CPU-visible) and `DeviceBuffer` (GPU-local).
pub trait GpuBuffer {
    /// Write data into the buffer, starting at offset 0.
    ///
    /// # Panics
    /// Panics if `data.len()` exceeds the buffer capacity.
    fn write(&mut self, data: &[u8]);

    /// Read the entire buffer contents into `data`.
    ///
    /// # Panics
    /// Panics if `data.len()` does not match the buffer length.
    fn read(&self, data: &mut [u8]);

    /// Current logical size of the buffer in bytes.
    fn len(&self) -> usize;

    /// Whether the buffer is empty.
    fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Intended usage of this buffer.
    fn usage(&self) -> BufferUsage;
}

/// A CPU-visible buffer for staging data before GPU upload.
///
/// In a production implementation this would be a persistently-mapped
/// GPU buffer or a `MTLBuffer` with `storageModeShared`.
pub struct StagingBuffer {
    data: Vec<u8>,
    usage: BufferUsage,
}

impl StagingBuffer {
    /// Create a new staging buffer with the given capacity and usage.
    pub fn with_capacity(capacity: usize, usage: BufferUsage) -> Self {
        Self {
            data: Vec::with_capacity(capacity),
            usage,
        }
    }

    /// Create a new staging buffer initialized with the given data.
    pub fn from_data(data: Vec<u8>, usage: BufferUsage) -> Self {
        Self { data, usage }
    }
}

impl GpuBuffer for StagingBuffer {
    fn write(&mut self, data: &[u8]) {
        self.data.clear();
        self.data.extend_from_slice(data);
    }

    fn read(&self, data: &mut [u8]) {
        assert_eq!(data.len(), self.data.len(), "read size mismatch");
        data.copy_from_slice(&self.data);
    }

    fn len(&self) -> usize {
        self.data.len()
    }

    fn usage(&self) -> BufferUsage {
        self.usage
    }
}

/// A GPU-local buffer optimized for device-side access.
///
/// In a production implementation this would wrap a `MTLBuffer` with
/// `storageModePrivate` or a GL buffer with `GL_STATIC_DRAW`.
pub struct DeviceBuffer {
    size: usize,
    usage: BufferUsage,
    // In production: device-specific handle (MTLBuffer, GLuint, etc.)
}

impl DeviceBuffer {
    /// Create a new GPU-local buffer with the given size and usage.
    pub fn new(size: usize, usage: BufferUsage) -> Self {
        Self { size, usage }
    }

    /// Upload data from a staging buffer into this device buffer.
    ///
    /// In production this would issue a GPU copy command (Metal: blit command
    /// encoder; GL: `glBufferSubData` or `glCopyBufferSubData`).
    pub fn upload_from(&mut self, staging: &StagingBuffer) {
        assert!(
            staging.len() <= self.size,
            "staging data exceeds device buffer capacity"
        );
        self.size = staging.len();
        // In production: issue GPU copy command here.
    }
}

impl GpuBuffer for DeviceBuffer {
    fn write(&mut self, data: &[u8]) {
        assert!(data.len() <= self.size, "write exceeds buffer capacity");
        // In production: map GPU buffer or use staging intermediate.
        let _ = data;
    }

    fn read(&self, data: &mut [u8]) {
        assert_eq!(data.len(), self.size, "read size mismatch");
        // In production: readback via blit encoder or glReadPixels.
    }

    fn len(&self) -> usize {
        self.size
    }

    fn usage(&self) -> BufferUsage {
        self.usage
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_staging_buffer_write_read() {
        let mut buf = StagingBuffer::with_capacity(64, BufferUsage::Vertex);
        assert!(buf.is_empty());

        let input = vec![1u8; 32];
        buf.write(&input);
        assert_eq!(buf.len(), 32);
        assert_eq!(buf.usage(), BufferUsage::Vertex);

        let mut output = vec![0u8; 32];
        buf.read(&mut output);
        assert_eq!(input, output);
    }

    #[test]
    fn test_staging_buffer_from_data() {
        let data = vec![10u8, 20, 30, 40];
        let buf = StagingBuffer::from_data(data.clone(), BufferUsage::Uniform);
        assert_eq!(buf.len(), 4);
        assert_eq!(buf.usage(), BufferUsage::Uniform);
    }

    #[test]
    fn test_device_buffer_creation() {
        let buf = DeviceBuffer::new(1024, BufferUsage::Storage);
        assert_eq!(buf.len(), 1024);
        assert_eq!(buf.usage(), BufferUsage::Storage);
    }

    #[test]
    fn test_device_buffer_upload_from() {
        let staging = StagingBuffer::from_data(vec![42u8; 64], BufferUsage::Staging);
        let mut device = DeviceBuffer::new(128, BufferUsage::Vertex);
        device.upload_from(&staging);
        assert_eq!(device.len(), 64);
    }

    #[test]
    fn test_buffer_usage_values() {
        assert_ne!(BufferUsage::Vertex, BufferUsage::Index);
        assert_ne!(BufferUsage::Uniform, BufferUsage::Storage);
    }
}
