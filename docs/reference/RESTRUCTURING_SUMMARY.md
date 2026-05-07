# Dala Library Restructuring Summary

## Overview
The `lib/dala/` folder has been restructured to group files by feature, improving code organization and maintainability.

## New Directory Structure

### Core Modules
- `app/` - Application lifecycle management
  - `app.ex` - Main application module

- `device/` - Device-specific functionality
  - `device.ex` - Generic device interface
  - `ios.ex` - iOS-specific implementations
  - `android.ex` - Android-specific implementations

- `screen/` - Screen management and navigation
  - `screen.ex` - Main screen module
  - `manager.ex` - Screen manager

### Feature Directories

#### Connectivity
- `connectivity/` - Network and distribution features
  - `wifi.ex` - WiFi connectivity
  - `dist.ex` - Distribution (Erlang node distribution)

#### Hardware
- `hardware/` - Hardware interaction
  - `bluetooth.ex` - Bluetooth Low Energy (BLE)
  - `biometric.ex` - Biometric authentication
  - `haptic.ex` - Haptic feedback
  - `scanner.ex` - Barcode/QR scanner

#### Media
- `media/` - Media handling
  - `audio.ex` - Audio playback/recording
  - `camera.ex` - Camera access
  - `photos.ex` - Photo library access

#### ML (Machine Learning)
- `ml/` - Machine learning integration
  - `ml.ex` - Main ML module
  - `config_helper.ex` - ML configuration
  - `core_ml.ex` - CoreML integration (iOS)
  - `emlx.ex` - MLX backend (Apple Silicon)
  - `nx.ex` - Nx numerical backend
  - `onnx.ex` - ONNX runtime
  - `example.ex` - ML example

#### Navigation
- `nav/` - Navigation state
  - `registry.ex` - Navigation registry

#### Platform
- `platform/` - Platform-specific services
  - `native.ex` - Native NIF interface
  - `native_logger.ex` - Native logging
  - `background.ex` - Background tasks
  - `clipboard.ex` - Clipboard access
  - `diag.ex` - Diagnostics
  - `linking.ex` - Deep linking
  - `live_view.ex` - Phoenix LiveView integration
  - `location.ex` - Location services
  - `notify.ex` - Notifications
  - `permissions.ex` - Permission management
  - `pubsub.ex` - PubSub messaging
  - `registry.ex` - System registry
  - `settings.ex` - App settings
  - `share.ex` - Share sheet
  - `state.ex` - Application state

#### Screen Management
- `screen/` - Screen lifecycle
  - `screen.ex` - Screen behavior
  - `manager.ex` - Screen manager

#### Setup
- `setup/` - Platform setup
  - `setup.ex` - Main setup module
  - `ios.ex` - iOS setup
  - `android.ex` - Android setup

#### Storage
- `storage/` - Data persistence
  - `storage.ex` - Main storage module
  - `files.ex` - File system access
  - `blob.ex` - Binary large objects
  - `apple.ex` - Apple-specific storage
  - `android.ex` - Android-specific storage

#### Test
- `test/` - Testing utilities
  - `test.ex` - Test helpers

#### Theme
- `theme/` - Theming system
  - `theme.ex` - Main theme module
  - `adaptive.ex` - Adaptive theme
  - `adaptive_watcher.ex` - Theme watcher
  - `birch.ex` - Birch theme
  - `citrus.ex` - Citrus theme
  - `dark.ex` - Dark theme
  - `light.ex` - Light theme
  - `obsidian.ex` - Obsidian theme

#### UI Components
- `ui/` - User interface components and rendering
  - `ui.ex` - Main UI module
  - `alert.ex` - Alert dialogs
  - `component.ex` - Component system
  - `component_registry.ex` - Component registry
  - `component_server.ex` - Component server
  - `diff.ex` - UI tree diffing
  - `list.ex` - List components
  - `motion.ex` - Motion/animation
  - `node.ex` - UI node structure
  - `renderer.ex` - UI renderer (binary protocol)
  - `sigil.ex` - Dala sigil (~dala)
  - `socket.ex` - UI socket
  - `style.ex` - Styling system
  - `webview.ex` - WebView component

#### Event System
- `event/` - Event handling
  - `event.ex` - Main event module
  - `address.ex` - Event addressing
  - `bridge.ex` - Event bridge
  - `component.ex` - Component events
  - `target.ex` - Event targets
  - `throttle.ex` - Event throttling
  - `trace.ex` - Event tracing

#### Spark DSL
- `spark/` - Spark declarative DSL
  - `dsl.ex` - Main DSL module
  - `pubsub.ex` - DSL pubsub
  - `transformers/` - DSL transformers
    - `generate_mount.ex` - Mount generation
    - `pubsub.ex` - Pubsub transformer
    - `render.ex` - Render transformer

## Key Changes

1. **Module Names Updated**: All module names now reflect their new paths (e.g., `Dala.Bluetooth` → `Dala.Hardware.Bluetooth`)

2. **Binary Protocol**: The renderer uses a custom binary protocol for efficient UI updates:
   - `Dala.Ui.Renderer` encodes `Dala.Ui.Node` trees to binary
   - Supports incremental patches via `Dala.Ui.Diff`
   - Zero-copy at BEAM/native boundary

3. **Feature Grouping**: Related functionality is now colocated:
   - Hardware features (BLE, camera, haptics) in `hardware/`
   - Media features (audio, photos) in `media/`
   - Platform services in `platform/`
   - UI components in `ui/`

4. **ML Integration**: Comprehensive ML support with multiple backends:
   - CoreML for iOS-native inference
   - ONNX for cross-platform models
   - Nx/MLX for pure Elixir ML

## Benefits

- **Improved Discoverability**: Features are grouped logically
- **Better Maintainability**: Related code is colocated
- **Clearer Dependencies**: Feature boundaries are explicit
- **Easier Testing**: Test files can mirror the structure
- **Scalability**: New features have obvious homes

## Migration Notes

- All module imports must be updated to reflect new paths
- The binary protocol in `Dala.Ui.Renderer` is backward compatible
- No breaking changes to the public API (only internal module paths)
- Tests should be updated to use new module paths
