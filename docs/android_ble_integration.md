# Android BLE Integration Guide

## Overview

Dala now supports Android Bluetooth Low Energy (BLE) operations through JNI (Java Native Interface). The implementation consists of:

1. **Rust NIF (`dala/native/dala_nif/src/android.rs`)** - Rust code that exposes NIFs to Elixir
2. **Java Bridge (`dala/android/src/main/java/com/example/dala/DalaBridge.java`)** - Java class that interfaces with Android Bluetooth APIs
3. **JNI Callbacks** - Native methods called from Java back to Rust

## Architecture

```
Elixir (Dala.Bluetooth)
    ↓
Rust NIF (android.rs)
    ↓
Java Native Interface (JNI)
    ↓
DalaBridge.java
    ↓
Android Bluetooth APIs (BluetoothAdapter, BluetoothGatt, etc.)
```

## Features Implemented

- **bluetooth_state/0** - Get Bluetooth adapter state
- **bluetooth_start_scan/2** - Start BLE scan with optional service filters and timeout
- **bluetooth_stop_scan/0** - Stop ongoing BLE scan
- **bluetooth_connect/1** - Connect to a BLE device by MAC address
- **bluetooth_disconnect/1** - Disconnect from a BLE device
- **bluetooth_discover_services/1** - Discover GATT services on a connected device
- **bluetooth_read_characteristic/3** - Read a characteristic value
- **bluetooth_write_characteristic/4** - Write a characteristic value
- **bluetooth_subscribe/3** - Subscribe to characteristic notifications
- **bluetooth_unsubscribe/3** - Unsubscribe from characteristic notifications

## Setup Instructions

### 1. Add Permissions to AndroidManifest.xml

The `AndroidManifest.xml` in `dala/android/src/main/` already includes the required permissions:

- `BLUETOOTH` (for Android < 12)
- `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (for Android 12+)
- `ACCESS_FINE_LOCATION` (required for BLE scan on Android 6-11)

### 2. Initialize DalaBridge in Your Activity

In your main activity, initialize the DalaBridge with the application context:

```java
import com.example.dala.DalaBridge;

public class MainActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        DalaBridge.init(getApplicationContext());
    }
}
```

### 3. Request Runtime Permissions (Android 6+)

For Android 6 (API 23) and above, you need to request dangerous permissions at runtime:

```java
// Check and request Bluetooth permissions
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    // Android 12+
    if (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
        requestPermissions(new String[]{
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT
        }, REQUEST_BLUETOOTH);
    }
} else {
    // Android 6-11
    if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
        requestPermissions(new String[]{
            Manifest.permission.ACCESS_FINE_LOCATION
        }, REQUEST_LOCATION);
    }
}
```

## Usage from Elixir

```elixir
# Check Bluetooth state
case Dala.Bluetooth.state() do
  "powered_on" -> # Bluetooth is on
  "powered_off" -> # Bluetooth is off
  _ -> # Unknown state
end

# Start scanning for devices
Dala.Bluetooth.start_scan([], 10_000) # Scan for 10 seconds

# Connect to a device (use MAC address)
Dala.Bluetooth.connect("00:11:22:33:44:55")

# Discover services
Dala.Bluetooth.discover_services("00:11:22:33:44:55")

# Read a characteristic
Dala.Bluetooth.read_characteristic(
  "00:11:22:33:44:55",
  "0000180a-0000-1000-8000-00805f9b34fb", # Device Information Service
  "00002a29-0000-1000-8000-00805f9b34fb"  # Manufacturer Name String
)

# Write to a characteristic
Dala.Bluetooth.write_characteristic(
  "00:11:22:33:44:55",
  "some-service-uuid",
  "some-characteristic-uuid",
  <<1, 2, 3, 4>>
)

# Subscribe to notifications
Dala.Bluetooth.subscribe(
  "00:11:22:33:44:55",
  "some-service-uuid",
  "some-characteristic-uuid"
)
```

## Callback Mechanism

When BLE events occur (device found, connected, etc.), the Java code calls native JNI methods which are implemented in Rust (`android.rs`). Currently, these callbacks log to stderr (which appears in logcat).

To complete the integration, you need to:

1. Implement the message delivery from Rust to Elixir (similar to how `dala_nif` delivers other events)
2. Handle the callbacks in your Elixir application (e.g., via `handle_info/2` in your GenServer)

## Building

The Android project uses a standard Gradle build system. The Rust NIF is compiled using `cargo ndk` or similar tooling as part of the Dala build process.

## Troubleshooting

- **"Bluetooth not available"** - Check if the device has Bluetooth and if permissions are granted
- **"Permission denied"** - Ensure runtime permissions are granted for Android 6+
- **Scan not finding devices** - Check location services are enabled (Android 6-11)
- **GATT operations failing** - Verify the device is connected and services are discovered

## Files Modified/Created

- `dala/native/dala_nif/src/android.rs` - Added BLE JNI implementations
- `dala/native/dala_nif/src/common.rs` - Added `_with_env` variants for Android
- `dala/native/dala_nif/src/lib.rs` - Updated NIFs to use `_with_env` on Android
- `dala/android/src/main/java/com/example/dala/DalaBridge.java` - New Java bridge class
- `dala/android/src/main/AndroidManifest.xml` - Permissions and features
- `dala/android/build.gradle` - Top-level Gradle build file
- `dala/android/src/main/build.gradle` - Module-level Gradle build file
- `dala/android/proguard-rules.pro` - ProGuard rules to preserve JNI methods
