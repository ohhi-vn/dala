# Bluetooth and WiFi Implementation Summary

## Overview
Full Bluetooth Low Energy (BLE) and WiFi support has been added to the Dala framework for both iOS and Android platforms.

## Files Created

### iOS (Bluetooth)
- `ios/DalaBluetoothManager.h` - Objective-C header with CBCentralManagerDelegate and CBPeripheralDelegate protocols
- `ios/DalaBluetoothManager.m` - Full CoreBluetooth implementation with device scanning, connection management, GATT operations, and notification handling
- `ios/DalaBluetoothCInterface.m` - C interface functions that Rust NIF calls via FFI
- `ios/DalaBluetooth.swift` - Swift bridge to ensure proper linking

### iOS (WiFi)
- Stubs in `ios.rs` with notes about iOS limitations (iOS doesn't expose WiFi scanning to apps)

### Android (Bluetooth)
- `android/src/main/java/com/example/dala/DalaBridge.java` - Complete Java bridge class with BLE operations, BluetoothGattCallback for async events
- `android/build.gradle` - Top-level Gradle build file
- `android/src/main/build.gradle` - Module-level Gradle build file
- `android/proguard-rules.pro` - ProGuard rules to preserve JNI methods

### Android (WiFi)
- Added to `DalaBridge.java`:
  - `getWifiInfo()` - Returns current connection info as JSON
  - `startWifiScan()` - Starts WiFi scan with permission checks
  - `setWifiEnabled(boolean)` - Enables/disables WiFi
  - BroadcastReceiver for async scan results

### Elixir Modules
- `lib/dala/bluetooth.ex` - Bluetooth module with full API documentation
- `lib/dala/wifi.ex` - WiFi module with network info and scanning API
- `test/dala/bluetooth_wifi_test.exs` - Basic tests for both modules

## Files Modified

### Core
- `lib/dala/native.ex` - Added NIF function declarations with `@spec` annotations for all Bluetooth and WiFi functions
- `lib/dala/permissions.ex` - Added `:bluetooth` and `:wifi` to permissions system

### Rust NIF
- `native/dala_nif/src/lib.rs` - Added Rust NIF implementations (calling platform-specific code)
- `native/dala_nif/src/common.rs` - Added platform dispatch functions and `atom` helper
- `native/dala_nif/src/ios.rs` - iOS implementations using FFI to call Objective-C
- `native/dala_nif/src/android.rs` - Android implementations using JNI
- `native/dala_nif/Cargo.toml` - Added dependencies (`objc`, `objc-foundation`, `jni`, `lazy_static`)

### iOS Integration
- `ios/DalaDemo-Bridging-Header.h` - Added C function declarations for Bluetooth interface

### Android Integration
- `android/src/main/AndroidManifest.xml` - Added Bluetooth and WiFi permissions
- `android/jni/rust/src/lib.rs` - Added JNI_OnLoad to cache JavaVM pointer

## Architecture

```
Elixir (Dala.Bluetooth / Dala.WiFi)
    ↓
Rust NIF (native/dala_nif/src/)
    ↓
Platform-specific bridge
    ↓
iOS: CoreBluetooth / Android: Android Bluetooth/Wifi APIs
```

## Key Features

### Bluetooth (BLE)
- **State checking**: Returns `powered_on`, `powered_off`, `unauthorized`, etc.
- **Scanning**: Supports filtering by service UUIDs and timeout
- **Connection management**: Connect/disconnect with callbacks
- **GATT operations**: Discover services, read/write characteristics, subscribe to notifications
- **Callback system**: Native delegates trigger callbacks → Rust → Elixir `handle_info` messages

### WiFi
- **Current network info**: SSID, BSSID, IP address, RSSI
- **Scanning**: Available on Android (iOS doesn't support this in public APIs)
- **Enable/disable**: Available on Android with proper permissions

## Permissions Required

### iOS (Info.plist)
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`

### Android (AndroidManifest.xml)
**Bluetooth:**
- `BLUETOOTH` (Android < 12)
- `BLUETOOTH_ADMIN` (Android < 12)
- `BLUETOOTH_SCAN` (Android 12+)
- `BLUETOOTH_CONNECT` (Android 12+)
- `ACCESS_FINE_LOCATION` or `ACCESS_COARSE_LOCATION` (for scanning on Android 6-11)

**WiFi:**
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_STATE`
- `ACCESS_FINE_LOCATION` or `ACCESS_COARSE_LOCATION` (for scanning)

## Usage Examples

### Bluetooth
```elixir
# Check state
state = Dala.Bluetooth.state()

# Start scanning
Dala.Bluetooth.start_scan(socket, services: ["180D"], timeout_ms: 10_000)

# Handle found device
def handle_info({:bluetooth, :device_found, %{id: id, name: name, rssi: rssi}}, socket) do
  # ...
end

# Connect and discover services
Dala.Bluetooth.connect(socket, device_id)
Dala.Bluetooth.discover_services(socket, device_id)

# Read/write characteristics
Dala.Bluetooth.read_characteristic(socket, device_id, service_uuid, char_uuid)
Dala.Bluetooth.write_characteristic(socket, device_id, service_uuid, char_uuid, <<1, 2, 3>>)

# Subscribe to notifications
Dala.Bluetooth.subscribe(socket, device_id, service_uuid, char_uuid)
```

### WiFi
```elixir
# Get current network info
network = Dala.WiFi.current_network()
# %{connected: true, ssid: "MyWiFi", bssid: "00:11:22:33:44:55", ip: "192.168.1.100", rssi: -45}

# Check if connected
Dala.WiFi.connected?()

# Scan (Android only)
Dala.WiFi.scan(socket)

# Get IP address
ip = Dala.WiFi.ip_address()
```

## Next Steps

1. **iOS**: Add the `.m` and `.swift` files to your Xcode project, link `CoreBluetooth.framework`
2. **Android**: Ensure Gradle files are properly integrated, call `DalaBridge.init(getApplicationContext())` from main activity
3. **Testing**: Test on physical devices (simulators have limited BLE support)
4. **Callbacks**: Complete callback delivery from Rust to Elixir if not already working
5. **Runtime permissions**: Request Bluetooth and location permissions at runtime on Android 6+

---

## NFC (Near Field Communication)

Added alongside Bluetooth/WiFi. Reads NDEF tags on both iOS and Android.

### Files Created

**iOS (NFC):**
- `ios/DalaNFCManager.h` — Header for `NFCNDEFReaderSession` wrapper
- `ios/DalaNFCManager.m` — Full CoreNFC implementation with NDEF record parsing
- `ios/DalaNFCCInterface.m` — C interface for Rust NIF FFI

**iOS (Motion):**
- `ios/DalaMotionManager.h` — Header for `CMMotionManager` wrapper
- `ios/DalaMotionManager.m` — Accelerometer + gyroscope implementation
- `ios/DalaMotionCInterface.m` — C interface for Rust NIF FFI

**Android (NFC + Motion):**
- `android/src/main/java/com/example/dala/DalaBridge.java` — Added:
  - Motion: `SensorManager`, `SensorEventListener`, `startMotionSensors()`, `stopMotionSensors()`, `isMotionAvailable()`
  - NFC: `NfcAdapter` foreground dispatch, `startNFCScan()`, `stopNFCScan()`, `handleNFCIntent()`, `isNFCAvailable()`
  - JNI callbacks: `nativeMotionData()`, `nativeNFCTagDiscovered()`, `nativeNFCError()`

**Elixir:**
- `lib/dala/hardware/nfc.ex` — NFC tag reading API (`available?/0`, `start_scan/2`, `stop_scan/1`)
- `lib/dala/ui/sensor/motion.ex` — Motion sensor API (`available?/0`, `start/2`, `stop/1`)
- `lib/dala/ui/scan.ex` — Unified parser for NFC/barcode payloads (`parse/1`)

**Rust NIF:**
- `native/dala_nif/src/lib.rs` — Added NIF functions: `motion_available`, `motion_start`, `motion_stop`, `nfc_available`, `nfc_start_scan`, `nfc_stop_scan`
- `native/dala_nif/src/ios.rs` — iOS motion + NFC via C FFI
- `native/dala_nif/src/android.rs` — Android motion + NFC via JNI, plus `nativeMotionData`, `nativeNFCTagDiscovered`, `nativeNFCError` JNI callbacks
- `native/dala_nif/src/common.rs` — Platform dispatch stubs

### Architecture

```
Elixir (Dala.Hardware.NFC / Dala.Ui.Sensor.Motion)
    ↓
Rust NIF (native/dala_nif/src/)
    ↓
Platform-specific bridge
    ↓
iOS: CoreNFC / CoreMotion → C FFI    Android: NfcAdapter / SensorManager → JNI
```

### Permissions Required

**iOS (Info.plist):**
- `NFCReaderUsageDescription` — "This app reads NFC tags"
- Add "Near Field Communication Tag Reading" capability in Xcode

**Android (AndroidManifest.xml):**
- `android.permission.NFC`
- Activity must forward `onNewIntent` to `DalaBridge.handleNFCIntent(intent)`

### `Dala.Ui.Scan` — Common Format Parser

`Dala.Ui.Scan.parse/1` auto-detects and parses 9 common NFC/barcode payload formats:

| Type | Raw example | Parsed `:value` |
|------|-------------|-----------------|
| `:url` | `https://example.com` | `"https://example.com"` |
| `:wifi` | `WIFI:T:WPA;S:MyNet;P:pass;;` | `%{ssid: "MyNet", password: "pass", security: :wpa, hidden: false}` |
| `:email` | `mailto:u@e.com?s=Hi` | `%{email: "u@e.com", subject: "Hi", body: ""}` |
| `:phone` | `tel:+1234567890` | `%{number: "+1234567890"}` |
| `:sms` | `smsto:+1234567890:hi` | `%{number: "+1234567890", message: "hi"}` |
| `:geo` | `geo:37.78,-122.40?q=GG` | `%{lat: 37.78, lon: -122.4, altitude: nil, query: "GG"}` |
| `:vcard` | `BEGIN:VCARD..END:VCARD` | `%{name, phone, email, org, title, url, address}` |
| `:vevent` | `BEGIN:VEVENT..END:VEVENT` | `%{summary, start, end, location, description}` |
| `:text` | `Hello world` | `"Hello world"` (fallback) |

Works with both NFC tag payloads and QR/barcode scan results.
