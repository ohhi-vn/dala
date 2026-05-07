// build.rs - Handle ONNX Runtime linking for different platforms.

fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();

    match target_os.as_str() {
        "ios" => {
            // iOS: Link against ONNX Runtime static library
            // Expected at: ../onnxruntime-ios/lib/
            let lib_path = std::path::Path::new("../onnxruntime-ios/lib");
            if lib_path.exists() {
                println!("cargo:rustc-link-search=native={}", lib_path.display());
                println!("cargo:rustc-link-lib=static=onnxruntime");
            } else {
                println!(
                    "cargo:warning=ONNX Runtime iOS lib not found at {}. Skipping linking.",
                    lib_path.display()
                );
            }
        }
        "android" => {
            // Android: Link against ONNX Runtime shared library
            // Expected at: ../onnxruntime-android/jni/arm64-v8a/
            let lib_path = std::path::Path::new("../onnxruntime-android/jni/arm64-v8a");
            if lib_path.exists() {
                println!("cargo:rustc-link-search=native={}", lib_path.display());
                println!("cargo:rustc-link-lib=onnxruntime");
            } else {
                println!(
                    "cargo:warning=ONNX Runtime Android lib not found at {}. Skipping linking.",
                    lib_path.display()
                );
            }
        }
        "macos" => {
            // macOS (for testing): Link against ONNX Runtime
            let lib_path = std::path::Path::new("../onnxruntime-macos/lib");
            if lib_path.exists() {
                println!("cargo:rustc-link-search=native={}", lib_path.display());
                println!("cargo:rustc-link-lib=onnxruntime");
            } else {
                println!(
                    "cargo:warning=ONNX Runtime macOS lib not found at {}. Skipping linking.",
                    lib_path.display()
                );
            }
        }
        _ => {
            println!(
                "cargo:warning=ONNX Runtime: unsupported target OS '{}', skipping linking.",
                target_os
            );
        }
    }

    println!("cargo:rerun-if-env-changed=CARGO_CFG_TARGET_OS");
}
