// dala_onnx - Cross-platform ONNX Runtime wrapper for Dala
// Placeholder implementation — real ONNX Runtime linking coming via build.rs.
// Thread-safe session tracking via Mutex (no `static mut` UB).

#![allow(unused)]

use std::ffi::c_char;
use std::ptr;
use std::sync::Mutex;

// ===========================================================================
// Session management (thread-safe)
// ===========================================================================

static SESSIONS: Mutex<Vec<u64>> = Mutex::new(Vec::new());
static NEXT_ID: Mutex<u64> = Mutex::new(1);

// ===========================================================================
// C ABI functions
// ===========================================================================

/// Create an ONNX session from model data.
/// Returns: session_id (u64) on success, 0 on failure.
#[no_mangle]
pub extern "C" fn ort_create_session(model_data: *const u8, model_len: usize) -> u64 {
    if model_data.is_null() {
        return 0;
    }
    let mut next_id = NEXT_ID.lock().unwrap();
    let id = *next_id;
    *next_id += 1;

    let mut sessions = SESSIONS.lock().unwrap();
    sessions.push(id);

    id
}

/// Destroy an ONNX session.
/// Returns: 0 on success, -1 if session not found.
#[no_mangle]
pub extern "C" fn ort_destroy_session(session_id: u64) -> i32 {
    let mut sessions = SESSIONS.lock().unwrap();
    if let Some(pos) = sessions.iter().position(|&id| id == session_id) {
        sessions.remove(pos);
        0
    } else {
        -1
    }
}

/// Run inference on a session.
/// Returns: 0 on success, negative on failure.
#[no_mangle]
pub extern "C" fn ort_run(
    _session_id: u64,
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
    0
}

/// Get input tensor shape for a session.
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

/// Get output tensor shape for a session.
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

/// Set execution provider for a session.
#[no_mangle]
pub extern "C" fn ort_set_execution_provider(_session_id: u64, _provider: *const c_char) -> i32 {
    // Placeholder: accept any provider without error.
    0
}

/// Return the number of active sessions.
#[no_mangle]
pub extern "C" fn ort_session_count() -> u64 {
    SESSIONS.lock().unwrap().len() as u64
}

/// Check whether ONNX Runtime is available and initialized.
/// Returns: 1 if available, 0 otherwise.
#[no_mangle]
pub extern "C" fn ort_is_available() -> i32 {
    // Placeholder: always available. Real implementation would verify
    // the native ONNX Runtime library loaded successfully.
    1
}

/// Get last error message.
#[no_mangle]
pub extern "C" fn ort_last_error() -> *const c_char {
    static MSG: &[u8] = b"ONNX Runtime not implemented (placeholder)\0";
    MSG.as_ptr() as *const c_char
}

/// Cleanup all resources.
#[no_mangle]
pub extern "C" fn ort_cleanup() {
    SESSIONS.lock().unwrap().clear();
}
