use rustler::{Binary, Encoder, Env, NifResult, Term};
use std::sync::Mutex;

#[cfg(target_os = "android")]
mod android;
mod common;
#[cfg(target_os = "ios")]
mod ios;
mod protocol;
mod tree;

use common::*;
use protocol::*;
use tree::*;

// Global tree for patch-based rendering
lazy_static::lazy_static! {
    static ref TREE: Mutex<Tree> = Mutex::new(Tree::new());
}

// Global environment for iOS callbacks (BLE events, etc.)
static mut GLOBAL_ENV: Option<Env<'static>> = None;
static mut ENV_INITIALIZED: bool = false;

// ============================================================================
// Helpers
// ============================================================================

fn atom<'a>(env: Env<'a>, name: &str) -> Term<'a> {
    rustler::types::atom::Atom::from_str(env, name)
        .unwrap()
        .to_term(env)
}

fn ok<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    Ok(atom(env, "ok"))
}

fn term_or_error<'a>(env: Env<'a>, opt: Option<Term<'a>>) -> NifResult<Term<'a>> {
    match opt {
        Some(t) => Ok(t),
        None => Ok(atom(env, "error")),
    }
}

// Cache the Erlang environment for use by ObjC callbacks
#[rustler::nif]
fn cache_env<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    unsafe {
        if !ENV_INITIALIZED {
            // Store the environment for later use by callbacks
            GLOBAL_ENV = Some(std::mem::transmute::<Env<'a>, Env<'static>>(env));
            ENV_INITIALIZED = true;
            // Register Bluetooth callbacks
            register_bluetooth_callbacks();
        }
    }
    ok(env)
}

// Register Bluetooth callbacks with Objective-C code
#[cfg(target_os = "ios")]
fn register_bluetooth_callbacks() {
    type BluetoothCallback = unsafe extern "C" fn(*const libc::c_char);

    unsafe extern "C" fn device_found_callback(
        identifier: *const libc::c_char,
        name: *const libc::c_char,
        rssi: libc::c_int,
        advertisement_data: *const libc::c_char,
    ) {
        // Send message to Elixir: {:bluetooth, :device_found, ...}
        eprintln!("[Dala BLE] Device found callback triggered");
        // Full implementation would use erl_nif API to send message to Elixir process
    }

    unsafe extern "C" fn device_connected_callback(identifier: *const libc::c_char) {
        eprintln!("[Dala BLE] Device connected callback triggered");
    }

    unsafe extern "C" fn device_connect_failed_callback(
        identifier: *const libc::c_char,
        error: *const libc::c_char,
    ) {
        eprintln!("[Dala BLE] Device connect failed callback triggered");
    }

    unsafe extern "C" fn device_disconnected_callback(identifier: *const libc::c_char) {
        eprintln!("[Dala BLE] Device disconnected callback triggered");
    }

    // Register callbacks with Objective-C
    extern "C" {
        fn DalaBluetoothSetDeviceFoundCallback(
            callback: unsafe extern "C" fn(
                *const libc::c_char,
                *const libc::c_char,
                libc::c_int,
                *const libc::c_char,
            ),
        );
        fn DalaBluetoothSetDeviceConnectedCallback(
            callback: unsafe extern "C" fn(*const libc::c_char),
        );
        fn DalaBluetoothSetDeviceConnectFailedCallback(
            callback: unsafe extern "C" fn(*const libc::c_char, *const libc::c_char),
        );
        fn DalaBluetoothSetDeviceDisconnectedCallback(
            callback: unsafe extern "C" fn(*const libc::c_char),
        );
    }

    unsafe {
        DalaBluetoothSetDeviceFoundCallback(device_found_callback);
        DalaBluetoothSetDeviceConnectedCallback(device_connected_callback);
        DalaBluetoothSetDeviceConnectFailedCallback(device_connect_failed_callback);
        DalaBluetoothSetDeviceDisconnectedCallback(device_disconnected_callback);
    }
}

#[cfg(not(target_os = "ios"))]
fn register_bluetooth_callbacks() {
    // No-op on non-iOS platforms
}

// Deliver webview eval result to Elixir
#[no_mangle]
pub extern "C" fn dala_deliver_webview_eval_result(json_utf8: *const std::ffi::c_char) {
    unsafe {
        if json_utf8.is_null() {
            return;
        }

        let json = {
            let cstr = std::ffi::CStr::from_ptr(json_utf8);
            match cstr.to_str() {
                Ok(s) => s.to_string(),
                Err(_) => return,
            }
        };

        eprintln!("[Dala] WebView eval result: {}", json);
    }
}

// ============================================================================
// Platform
// ============================================================================

#[rustler::nif]
fn platform<'a>(env: Env<'a>) -> Term<'a> {
    #[cfg(target_os = "ios")]
    return atom(env, "ios");

    #[cfg(target_os = "android")]
    return atom(env, "android");

    #[cfg(not(any(target_os = "ios", target_os = "android")))]
    return atom(env, "unknown");
}

// ============================================================================
// Logging
// ============================================================================

#[rustler::nif]
fn log<'a>(env: Env<'a>, msg: Term<'a>) -> NifResult<Term<'a>> {
    let msg_str: String = msg.decode()?;
    platform_log(&msg_str);
    ok(env)
}

#[rustler::nif]
fn log_level<'a>(env: Env<'a>, level: Term<'a>, msg: Term<'a>) -> NifResult<Term<'a>> {
    let level_str: String = level.decode()?;
    let msg_str: String = msg.decode()?;
    platform_log_with_level(&level_str, &msg_str);
    ok(env)
}

// ============================================================================
// UI / Rendering
// ============================================================================

#[rustler::nif]
fn set_transition<'a>(env: Env<'a>, transition: Term<'a>) -> NifResult<Term<'a>> {
    let s: String = transition.decode()?;
    set_transition_internal(&s);
    ok(env)
}

#[rustler::nif]
fn set_root_binary<'a>(env: Env<'a>, binary: Binary<'a>) -> NifResult<Term<'a>> {
    let bytes = binary.as_slice();
    let transition = get_transition_and_clear();

    let mut tree = TREE
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("tree lock poisoned")))?;

    decode_full_tree(&mut tree, bytes);

    platform_set_root_binary(bytes, &transition);

    ok(env)
}

#[rustler::nif]
fn set_taps<'a>(env: Env<'a>, _taps: Term<'a>) -> NifResult<Term<'a>> {
    ok(env)
}

#[rustler::nif]
fn register_tap<'a>(env: Env<'a>, _pid: Term<'a>) -> NifResult<Term<'a>> {
    let _handle = register_tap_internal();
    ok(env)
}

#[rustler::nif]
fn clear_taps<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    clear_taps_internal();
    ok(env)
}

#[rustler::nif]
fn exit_app<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    platform_exit_app();
    ok(env)
}

#[rustler::nif]
fn safe_area<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    let insets = platform_safe_area();
    Ok((insets.top, insets.right, insets.bottom, insets.left).encode(env))
}

// ============================================================================
// Incremental rendering (patch-based)
// ============================================================================

#[rustler::nif]
fn apply_patches<'a>(env: Env<'a>, binary: Binary<'a>) -> NifResult<Term<'a>> {
    let bytes = binary.as_slice();
    let mut tree = TREE
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("tree lock poisoned")))?;
    match decode_and_apply(&mut tree, bytes) {
        Ok(()) => ok(env),
        Err(msg) => {
            eprintln!("[Dala] apply_patches error: {}", msg);
            Err(rustler::Error::Term(Box::new(format!(
                "apply_patches: {}",
                msg
            ))))
        }
    }
}

// ============================================================================
// Device APIs — Haptic / Clipboard / Share
// ============================================================================

#[rustler::nif]
fn haptic<'a>(env: Env<'a>, _type: Term<'a>) -> NifResult<Term<'a>> {
    let _t: String = _type.decode()?;
    platform_haptic(&_t);
    ok(env)
}

#[rustler::nif]
fn clipboard_put<'a>(env: Env<'a>, text: Term<'a>) -> NifResult<Term<'a>> {
    let s: String = text.decode()?;
    platform_clipboard_put(&s);
    ok(env)
}

#[rustler::nif]
fn clipboard_get<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    let result = platform_clipboard_get(env);
    term_or_error(env, result)
}

#[rustler::nif]
fn share_text<'a>(env: Env<'a>, text: Term<'a>) -> NifResult<Term<'a>> {
    let s: String = text.decode()?;
    platform_share_text(&s);
    ok(env)
}

// ============================================================================
// Wakelock
// ============================================================================

#[rustler::nif]
fn wakelock_enable<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    #[cfg(target_os = "android")]
    {
        if let Some(mut jni_env) = crate::android::get_jni_env() {
            crate::common::platform_wakelock_enable_with_env(&mut jni_env);
            return ok(env);
        }
    }
    platform_wakelock_enable();
    ok(env)
}

#[rustler::nif]
fn wakelock_disable<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    #[cfg(target_os = "android")]
    {
        if let Some(mut jni_env) = crate::android::get_jni_env() {
            crate::common::platform_wakelock_disable_with_env(&mut jni_env);
            return ok(env);
        }
    }
    platform_wakelock_disable();
    ok(env)
}

#[rustler::nif]
fn wakelock_enabled<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    #[cfg(target_os = "android")]
    {
        if let Some(mut jni_env) = crate::android::get_jni_env() {
            let enabled = crate::common::platform_wakelock_enabled_with_env(&mut jni_env);
            return if enabled {
                Ok(atom(env, "true"))
            } else {
                Ok(atom(env, "false"))
            };
        }
    }
    let enabled = platform_wakelock_enabled();
    if enabled {
        Ok(atom(env, "true"))
    } else {
        Ok(atom(env, "false"))
    }
}
