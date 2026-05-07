// onnx.rs - ONNX Runtime wrapper for Dala NIF
// Currently placeholder — real implementation will use dala_onnx crate.
// Thread-safe session tracking via Mutex (no `static mut` UB).

use std::ffi::{c_char, CStr};
use std::ptr;
use std::sync::Mutex;

// ===========================================================================
// Session management (thread-safe)
// ===========================================================================

static SESSIONS: Mutex<Vec<u64>> = Mutex::new(Vec::new());
static NEXT_ID: Mutex<u64> = Mutex::new(1);

// ===========================================================================
// Rust-level API (called from NIF functions in lib.rs)
// ===========================================================================

/// Create an ONNX session from model data.
/// Returns: session_id (u64) on success, 0 on failure.
pub fn create_session(_model_data: &[u8]) -> u64 {
    let mut next_id = NEXT_ID.lock().unwrap();
    let id = *next_id;
    *next_id += 1;

    let mut sessions = SESSIONS.lock().unwrap();
    sessions.push(id);

    id
}

/// Destroy an ONNX session.
/// Returns: 0 on success, -1 if session not found.
pub fn destroy_session(session_id: u64) -> i32 {
    let mut sessions = SESSIONS.lock().unwrap();
    if let Some(pos) = sessions.iter().position(|&id| id == session_id) {
        sessions.remove(pos);
        0
    } else {
        -1
    }
}

/// Run inference on a session.
/// Returns: Some(output_bytes) on success, None on failure.
/// Placeholder: echoes input as output.
pub fn run(_session_id: u64, input_data: &[u8]) -> Option<Vec<u8>> {
    Some(input_data.to_vec())
}

/// Check whether ONNX Runtime is available.
pub fn is_available() -> bool {
    // Placeholder: always available. Real implementation would
    // check that the native ONNX Runtime library is linked and initialized.
    true
}

/// Return the number of active sessions.
pub fn session_count() -> u64 {
    SESSIONS.lock().unwrap().len() as u64
}

// ===========================================================================
// C ABI functions (for direct native interop / dala_onnx compatibility)
// ===========================================================================

#[no_mangle]
pub extern "C" fn ort_create_session(model_data: *const u8, model_len: usize) -> u64 {
    if model_data.is_null() {
        return 0;
    }
    let data = unsafe { std::slice::from_raw_parts(model_data, model_len) };
    create_session(data)
}

#[no_mangle]
pub extern "C" fn ort_destroy_session(session_id: u64) -> i32 {
    destroy_session(session_id)
}

#[no_mangle]
pub extern "C" fn ort_run(
    session_id: u64,
    input_data: *const f32,
    input_len: usize,
    output_data: *mut f32,
    output_len: usize,
) -> i32 {
    if input_data.is_null() || output_data.is_null() {
        return -2;
    }
    unsafe {
        let input_slice = std::slice::from_raw_parts(input_data, input_len);
        let output_slice = std::slice::from_raw_parts_mut(output_data, output_len);
        let copy_len = input_len.min(output_len);
        output_slice[..copy_len].copy_from_slice(&input_slice[..copy_len]);
    }
    // Keep the session alive — real ONNX would reuse it.
    let _ = session_id;
    0
}

#[no_mangle]
pub extern "C" fn ort_input_shape(_session_id: u64, shape_out: *mut i64, max_dims: usize) -> i32 {
    if shape_out.is_null() || max_dims < 4 {
        return -2;
    }
    unsafe {
        let shape = [1i64, 3, 224, 224];
        ptr::copy_nonoverlapping(shape.as_ptr(), shape_out, 4);
    }
    4
}

#[no_mangle]
pub extern "C" fn ort_output_shape(_session_id: u64, shape_out: *mut i64, max_dims: usize) -> i32 {
    if shape_out.is_null() || max_dims < 2 {
        return -2;
    }
    unsafe {
        let shape = [1i64, 1000];
        ptr::copy_nonoverlapping(shape.as_ptr(), shape_out, 2);
    }
    2
}

#[no_mangle]
pub extern "C" fn ort_set_execution_provider(_session_id: u64, provider: *const c_char) -> i32 {
    if provider.is_null() {
        return -2;
    }
    let provider_str = unsafe { CStr::from_ptr(provider).to_string_lossy().into_owned() };
    match provider_str.as_str() {
        "coreml" | "nnapi" | "cpu" => 0,
        _ => -3,
    }
}

#[no_mangle]
pub extern "C" fn ort_session_count() -> u64 {
    session_count()
}

#[no_mangle]
pub extern "C" fn ort_is_available() -> i32 {
    if is_available() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn ort_last_error() -> *const c_char {
    static ERROR_MSG: &[u8] = b"ONNX Runtime not fully implemented (placeholder)\0";
    ERROR_MSG.as_ptr() as *const c_char
}

#[no_mangle]
pub extern "C" fn ort_cleanup() {
    SESSIONS.lock().unwrap().clear();
}
