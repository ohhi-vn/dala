package com.example.dala;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.net.wifi.ScanResult;
import android.content.BroadcastReceiver;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.app.Activity;
import android.app.PendingIntent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.Ndef;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * DalaBridge - Java bridge class for Dala framework Android integration.
 * Handles Bluetooth Low Energy (BLE) operations and other native functionality.
 */
public class DalaBridge {
    private static final String TAG = "DalaBridge";

    private static Context appContext;
    private static BluetoothManager bluetoothManager;
    private static BluetoothAdapter bluetoothAdapter;
    private static BluetoothLeScanner bleScanner;
    private static Handler mainHandler;

    // Store GATT connections by device ID (MAC address)
    private static Map<String, BluetoothGatt> gattConnections = new HashMap<>();

    // Scan callback
    private static ScanCallback scanCallback;
    private static boolean isScanning = false;

    // Motion sensors
    private static SensorManager sensorManager;
    private static Sensor accelerometer;
    private static Sensor gyroscope;
    private static boolean motionRunning = false;
    private static Handler motionHandler;
    private static final Object motionLock = new Object();
    private static float lastAx, lastAy, lastAz;
    private static float lastGx, lastGy, lastGz;
    private static long lastMotionTimestamp;
    private static int motionIntervalMs = 100;
    private static boolean wantAccel = false;
    private static boolean wantGyro = false;

    // NFC
    private static NfcAdapter nfcAdapter;
    private static boolean nfcScanning = false;

    // Native function declarations (implemented in Rust NIF)
    private static native void nativeBluetoothDeviceFound(String deviceId, String name, int rssi);
    private static native void nativeBluetoothStateChanged(String state);
    private static native void nativeBluetoothConnected(String deviceId);
    private static native void nativeBluetoothDisconnected(String deviceId);
    private static native void nativeBluetoothServicesDiscovered(String deviceId, String servicesJson);
    private static native void nativeBluetoothCharacteristicRead(String deviceId, String service, String characteristic, byte[] value);
    private static native void nativeBluetoothCharacteristicWritten(String deviceId, String service, String characteristic);
    private static native void nativeBluetoothNotificationReceived(String deviceId, String service, String characteristic, byte[] value);

    // Motion sensor native methods
    private static native void nativeMotionData(float ax, float ay, float az, float gx, float gy, float gz, long timestamp);

    // NFC native methods
    private static native void nativeNFCTagDiscovered(String tech, String payload);
    private static native void nativeNFCError(String error);

    /**
     * Initialize the bridge with application context.
     * Call this from your main activity or application class.
     */
    public static void init(Context context) {
        appContext = context.getApplicationContext();
        bluetoothManager = (BluetoothManager) appContext.getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetoothManager != null) {
            bluetoothAdapter = bluetoothManager.getAdapter();
        }
        mainHandler = new Handler(Looper.getMainLooper());

        // Initialize sensor manager
        sensorManager = (SensorManager) appContext.getSystemService(Context.SENSOR_SERVICE);

        Log.i(TAG, "DalaBridge initialized");
    }

    // ========================================================================
    // UI Rendering
    // ========================================================================

    /**
     * Set the root UI tree from binary data.
     * Called from the Rust NIF via JNI to push rendered UI trees to the native side.
     *
     * @param data       Binary-encoded UI tree (Dala binary protocol v3)
     * @param transition Navigation transition type (e.g. "none", "push", "pop")
     */
    public static void setRootFromBinary(byte[] data, String transition) {
        Log.i(TAG, "setRootFromBinary: " + data.length + " bytes, transition=" + transition);
        // TODO: Decode binary protocol and update the Android UI tree.
        // This requires a DalaViewModel equivalent on Android that can
        // observe the decoded node tree and trigger Compose re-rendering.
        //
        // For now, this method serves as the JNI bridge endpoint so that
        // the Rust NIF can successfully deliver binary data to the Java side.
        // The actual Compose rendering integration is tracked separately.
    }

    // ========================================================================
    // Bluetooth State
    // ========================================================================

    public static String bluetoothGetState() {
        if (bluetoothAdapter == null) {
            return "unsupported";
        }
        int state = bluetoothAdapter.getState();
        switch (state) {
            case BluetoothAdapter.STATE_OFF:
                return "powered_off";
            case BluetoothAdapter.STATE_TURNING_ON:
                return "turning_on";
            case BluetoothAdapter.STATE_ON:
                return "powered_on";
            case BluetoothAdapter.STATE_TURNING_OFF:
                return "turning_off";
            default:
                return "unknown";
        }
    }

    // ========================================================================
    // BLE Scanning
    // ========================================================================

    public static void bluetoothStartScan(List<String> serviceUuids, long timeoutMs) {
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled()) {
            Log.e(TAG, "Bluetooth not available or not enabled");
            return;
        }

        bleScanner = bluetoothAdapter.getBluetoothLeScanner();
        if (bleScanner == null) {
            Log.e(TAG, "BluetoothLeScanner not available");
            return;
        }

        // Build scan filters from service UUIDs
        List<ScanFilter> filters = new ArrayList<>();
        if (serviceUuids != null && !serviceUuids.isEmpty()) {
            for (String uuid : serviceUuids) {
                try {
                    ScanFilter filter = new ScanFilter.Builder()
                            .setServiceUuid(new ParcelUuid(UUID.fromString(uuid)))
                            .build();
                    filters.add(filter);
                } catch (IllegalArgumentException e) {
                    Log.e(TAG, "Invalid UUID: " + uuid, e);
                }
            }
        }

        // Scan settings
        ScanSettings settings = new ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build();

        // Create scan callback
        scanCallback = new ScanCallback() {
            @Override
            public void onScanResult(int callbackType, ScanResult result) {
                BluetoothDevice device = result.getDevice();
                String deviceId = device.getAddress();
                String name = device.getName();
                int rssi = result.getRssi();

                Log.d(TAG, "Device found: " + deviceId + " (" + name + "), RSSI: " + rssi);
                nativeBluetoothDeviceFound(deviceId, name != null ? name : "", rssi);
            }

            @Override
            public void onScanFailed(int errorCode) {
                Log.e(TAG, "Scan failed with error code: " + errorCode);
                isScanning = false;
            }
        };

        // Start scan
        try {
            bleScanner.startScan(filters, settings, scanCallback);
            isScanning = true;
            Log.i(TAG, "BLE scan started");

            // Stop scan after timeout
            if (timeoutMs > 0) {
                mainHandler.postDelayed(() -> {
                    bluetoothStopScan();
                }, timeoutMs);
            }
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for BLE scan", e);
        }
    }

    public static void bluetoothStopScan() {
        if (bleScanner == null || scanCallback == null || !isScanning) {
            return;
        }

        try {
            bleScanner.stopScan(scanCallback);
            isScanning = false;
            Log.i(TAG, "BLE scan stopped");
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for stopping BLE scan", e);
        }
    }

    // ========================================================================
    // GATT Connection
    // ========================================================================

    public static void bluetoothConnect(String deviceId) {
        if (bluetoothAdapter == null) {
            Log.e(TAG, "Bluetooth not available");
            return;
        }

        BluetoothDevice device = bluetoothAdapter.getRemoteDevice(deviceId);
        if (device == null) {
            Log.e(TAG, "Device not found: " + deviceId);
            return;
        }

        // Create GATT callback
        BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
            @Override
            public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
                String devId = gatt.getDevice().getAddress();
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.i(TAG, "Connected to " + devId);
                    gattConnections.put(devId, gatt);
                    nativeBluetoothConnected(devId);

                    // Discover services
                    gatt.discoverServices();
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    Log.i(TAG, "Disconnected from " + devId);
                    gattConnections.remove(devId);
                    gatt.close();
                    nativeBluetoothDisconnected(devId);
                }
            }

            @Override
            public void onServicesDiscovered(BluetoothGatt gatt, int status) {
                String devId = gatt.getDevice().getAddress();
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.i(TAG, "Services discovered for " + devId);
                    // Build services JSON
                    StringBuilder json = new StringBuilder("[");
                    List<BluetoothGattService> services = gatt.getServices();
                    for (int i = 0; i < services.size(); i++) {
                        BluetoothGattService service = services.get(i);
                        if (i > 0) json.append(",");
                        json.append("\"").append(service.getUuid().toString()).append("\"");
                    }
                    json.append("]");
                    nativeBluetoothServicesDiscovered(devId, json.toString());
                } else {
                    Log.e(TAG, "Service discovery failed for " + devId + ", status: " + status);
                }
            }

            @Override
            public void onCharacteristicRead(BluetoothGatt gatt,
                                             BluetoothGattCharacteristic characteristic,
                                             int status) {
                String devId = gatt.getDevice().getAddress();
                UUID serviceUuid = characteristic.getService().getUuid();
                UUID charUuid = characteristic.getUuid();
                byte[] value = characteristic.getValue();

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "Characteristic read: " + charUuid);
                    nativeBluetoothCharacteristicRead(devId, serviceUuid.toString(),
                                                     charUuid.toString(), value);
                } else {
                    Log.e(TAG, "Characteristic read failed: " + charUuid + ", status: " + status);
                }
            }

            @Override
            public void onCharacteristicWrite(BluetoothGatt gatt,
                                              BluetoothGattCharacteristic characteristic,
                                              int status) {
                String devId = gatt.getDevice().getAddress();
                UUID serviceUuid = characteristic.getService().getUuid();
                UUID charUuid = characteristic.getUuid();

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "Characteristic written: " + charUuid);
                    nativeBluetoothCharacteristicWritten(devId, serviceUuid.toString(),
                                                        charUuid.toString());
                } else {
                    Log.e(TAG, "Characteristic write failed: " + charUuid + ", status: " + status);
                }
            }

            @Override
            public void onCharacteristicChanged(BluetoothGatt gatt,
                                               BluetoothGattCharacteristic characteristic) {
                String devId = gatt.getDevice().getAddress();
                UUID serviceUuid = characteristic.getService().getUuid();
                UUID charUuid = characteristic.getUuid();
                byte[] value = characteristic.getValue();

                Log.d(TAG, "Notification received: " + charUuid);
                nativeBluetoothNotificationReceived(devId, serviceUuid.toString(),
                                                   charUuid.toString(), value);
            }
        };

        // Connect to GATT server
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(appContext, false, gattCallback, BluetoothDevice.TRANSPORT_LE);
            } else {
                device.connectGatt(appContext, false, gattCallback);
            }
            Log.i(TAG, "Connecting to " + deviceId);
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for GATT connection", e);
        }
    }

    public static void bluetoothDisconnect(String deviceId) {
        BluetoothGatt gatt = gattConnections.get(deviceId);
        if (gatt != null) {
            try {
                gatt.disconnect();
                Log.i(TAG, "Disconnecting from " + deviceId);
            } catch (SecurityException e) {
                Log.e(TAG, "Permission denied for disconnect", e);
            }
        }
    }

    // ========================================================================
    // GATT Operations
    // ========================================================================

    public static void bluetoothDiscoverServices(String deviceId) {
        BluetoothGatt gatt = gattConnections.get(deviceId);
        if (gatt != null) {
            gatt.discoverServices();
            Log.i(TAG, "Discovering services for " + deviceId);
        } else {
            Log.e(TAG, "No GATT connection for " + deviceId);
        }
    }

    public static void bluetoothReadCharacteristic(String deviceId, String serviceUuid, String characteristicUuid) {
        BluetoothGatt gatt = gattConnections.get(deviceId);
        if (gatt == null) {
            Log.e(TAG, "No GATT connection for " + deviceId);
            return;
        }

        BluetoothGattService service = gatt.getService(UUID.fromString(serviceUuid));
        if (service == null) {
            Log.e(TAG, "Service not found: " + serviceUuid);
            return;
        }

        BluetoothGattCharacteristic characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid));
        if (characteristic == null) {
            Log.e(TAG, "Characteristic not found: " + characteristicUuid);
            return;
        }

        try {
            gatt.readCharacteristic(characteristic);
            Log.d(TAG, "Reading characteristic " + characteristicUuid);
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for read", e);
        }
    }

    public static void bluetoothWriteCharacteristic(String deviceId, String serviceUuid,
                                                   String characteristicUuid, byte[] value) {
        BluetoothGatt gatt = gattConnections.get(deviceId);
        if (gatt == null) {
            Log.e(TAG, "No GATT connection for " + deviceId);
            return;
        }

        BluetoothGattService service = gatt.getService(UUID.fromString(serviceUuid));
        if (service == null) {
            Log.e(TAG, "Service not found: " + serviceUuid);
            return;
        }

        BluetoothGattCharacteristic characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid));
        if (characteristic == null) {
            Log.e(TAG, "Characteristic not found: " + characteristicUuid);
            return;
        }

        try {
            characteristic.setValue(value);
            gatt.writeCharacteristic(characteristic);
            Log.d(TAG, "Writing characteristic " + characteristicUuid);
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for write", e);
        }
    }

    public static void bluetoothSubscribe(String deviceId, String serviceUuid, String characteristicUuid) {
        BluetoothGatt gatt = gattConnections.get(deviceId);
        if (gatt == null) {
            Log.e(TAG, "No GATT connection for " + deviceId);
            return;
        }

        BluetoothGattService service = gatt.getService(UUID.fromString(serviceUuid));
        if (service == null) {
            Log.e(TAG, "Service not found: " + serviceUuid);
            return;
        }

        BluetoothGattCharacteristic characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid));
        if (characteristic == null) {
            Log.e(TAG, "Characteristic not found: " + characteristicUuid);
            return;
        }

        try {
            // Enable notifications locally
            gatt.setCharacteristicNotification(characteristic, true);

            // Write to descriptor to enable notifications on the device
            // This is typically the Client Characteristic Configuration Descriptor (0x2902)
            BluetoothGattDescriptor descriptor = characteristic.getDescriptor(
                    UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"));
            if (descriptor != null) {
                descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                gatt.writeDescriptor(descriptor);
            }

            Log.d(TAG, "Subscribed to characteristic " + characteristicUuid);
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for subscribe", e);
        }
    }

    public static void bluetoothUnsubscribe(String deviceId, String serviceUuid, String characteristicUuid) {
        BluetoothGatt gatt = gattConnections.get(deviceId);
        if (gatt == null) {
            Log.e(TAG, "No GATT connection for " + deviceId);
            return;
        }

        BluetoothGattService service = gatt.getService(UUID.fromString(serviceUuid));
        if (service == null) {
            Log.e(TAG, "Service not found: " + serviceUuid);
            return;
        }

        BluetoothGattCharacteristic characteristic = service.getCharacteristic(UUID.fromString(characteristicUuid));
        if (characteristic == null) {
            Log.e(TAG, "Characteristic not found: " + characteristicUuid);
            return;
        }

        try {
            gatt.setCharacteristicNotification(characteristic, false);

            BluetoothGattDescriptor descriptor = characteristic.getDescriptor(
                    UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"));
            if (descriptor != null) {
                descriptor.setValue(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE);
                gatt.writeDescriptor(descriptor);
            }

            Log.d(TAG, "Unsubscribed from characteristic " + characteristicUuid);
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for unsubscribe", e);
        }
    }

    // ============================================================================
    // WiFi Methods
    // ============================================================================

    private static WifiManager wifiManager;
    private static BroadcastReceiver wifiScanReceiver;

    private static WifiManager getWifiManager() {
        if (wifiManager == null) {
            wifiManager = (WifiManager) context.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        }
        return wifiManager;
    }

    /**
     * Get current WiFi connection info as JSON string
     * Returns: {"connected": boolean, "ssid": string, "bssid": string, "ip": string, "rssi": int}
     */
    public static String getWifiInfo() {
        WifiManager wm = getWifiManager();
        if (wm == null) {
            return "{\"connected\": false}";
        }

        try {
            WifiInfo info = wm.getConnectionInfo();
            if (info == null || info.getNetworkId() == -1) {
                return "{\"connected\": false}";
            }

            String ssid = info.getSSID();
            // SSID is often returned with quotes, remove them
            if (ssid != null && ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid = ssid.substring(1, ssid.length() - 1);
            }

            String bssid = info.getBSSID();
            int ip = info.getIpAddress();
            int rssi = info.getRssi();

            // Convert IP from int to string
            String ipStr = String.format("%d.%d.%d.%d",
                    (ip & 0xff),
                    ((ip >> 8) & 0xff),
                    ((ip >> 16) & 0xff),
                    ((ip >> 24) & 0xff));

            return String.format(
                    "{\"connected\": true, \"ssid\": \"%s\", \"bssid\": \"%s\", \"ip\": \"%s\", \"rssi\": %d}",
                    ssid != null ? ssid : "",
                    bssid != null ? bssid : "",
                    ipStr,
                    rssi
            );
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for getWifiInfo", e);
            return "{\"connected\": false, \"error\": \"permission_denied\"}";
        }
    }

    /**
     * Start WiFi scan
     * Requires ACCESS_FINE_LOCATION or ACCESS_COARSE_LOCATION permission
     */
    public static void startWifiScan() {
        WifiManager wm = getWifiManager();
        if (wm == null) {
            Log.e(TAG, "WifiManager is null");
            return;
        }

        try {
            // Check if we have location permission (required for scan results on Android 6+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED &&
                    context.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED) {
                    Log.e(TAG, "Location permission required for WiFi scan");
                    return;
                }
            }

            // Register broadcast receiver for scan results if not already registered
            if (wifiScanReceiver == null) {
                wifiScanReceiver = new BroadcastReceiver() {
                    @Override
                    public void onReceive(Context context, Intent intent) {
                        String action = intent.getAction();
                        if (WifiManager.SCAN_RESULTS_AVAILABLE_ACTION.equals(action)) {
                            boolean success = intent.getBooleanExtra(WifiManager.EXTRA_RESULTS_UPDATED, false);
                            if (success) {
                                List<android.net.wifi.ScanResult> results = wm.getScanResults();
                                Log.d(TAG, "WiFi scan complete, found " + results.size() + " networks");
                                // TODO: Send results back to Elixir via callback
                                // For now, just log them
                                for (android.net.wifi.ScanResult result : results) {
                                    Log.d(TAG, "  SSID: " + result.SSID + ", BSSID: " + result.BSSID + ", RSSI: " + result.level);
                                }
                            } else {
                                Log.d(TAG, "WiFi scan failed");
                            }
                        }
                    }
                };
                IntentFilter filter = new IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION);
                context.registerReceiver(wifiScanReceiver, filter);
            }

            boolean success = wm.startScan();
            Log.d(TAG, "WiFi scan started: " + success);
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for startWifiScan", e);
        }
    }

    /**
     * Enable or disable WiFi
     * Requires CHANGE_WIFI_STATE permission
     */
    public static void setWifiEnabled(boolean enabled) {
        WifiManager wm = getWifiManager();
        if (wm == null) {
            Log.e(TAG, "WifiManager is null");
            return;
        }

        try {
            boolean success = wm.setWifiEnabled(enabled);
            Log.d(TAG, "WiFi " + (enabled ? "enabled" : "disabled") + ": " + success);
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for setWifiEnabled", e);
        }
    }

    // ========================================================================
    // Locale / Language / Region
    // ========================================================================

    /**
     * Get the current locale identifier (e.g. "en_US", "fr_FR").
     * Uses Locale.getDefault().toString().
     */
    public static String getLocale() {
        try {
            java.util.Locale locale = java.util.Locale.getDefault();
            String localeStr = locale.toString();
            Log.d(TAG, "getLocale: " + localeStr);
            return localeStr;
        } catch (Exception e) {
            Log.e(TAG, "Error getting locale", e);
            return "";
        }
    }

    /**
     * Get the current language code (e.g. "en", "fr").
     * Uses Locale.getDefault().getLanguage().
     */
    public static String getLanguage() {
        try {
            java.util.Locale locale = java.util.Locale.getDefault();
            String lang = locale.getLanguage();
            Log.d(TAG, "getLanguage: " + lang);
            return lang;
        } catch (Exception e) {
            Log.e(TAG, "Error getting language", e);
            return "";
        }
    }

    /**
     * Get the current region/country code (e.g. "US", "FR").
     * Uses Locale.getDefault().getCountry().
     */
    public static String getRegion() {
        try {
            java.util.Locale locale = java.util.Locale.getDefault();
            String country = locale.getCountry();
            Log.d(TAG, "getRegion: " + country);
            return country;
        } catch (Exception e) {
            Log.e(TAG, "Error getting region", e);
            return "";
        }
    }

    // ========================================================================
    // Wakelock
    // ========================================================================

    private static PowerManager.WakeLock wakeLock = null;

    /**
     * Enable wakelock to keep the screen on
     * Requires WAKE_LOCK permission
     */
    public static void wakelockEnable() {
        try {
            Context context = getContext();
            if (context == null) {
                Log.e(TAG, "Context is null in wakelockEnable");
                return;
            }
            PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (pm == null) {
                Log.e(TAG, "PowerManager is null");
                return;
            }
            if (wakeLock == null) {
                wakeLock = pm.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP,
                        "Dala::WakeLock");
            }
            if (!wakeLock.isHeld()) {
                wakeLock.acquire();
                Log.d(TAG, "Wakelock enabled");
            }
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied for wakelockEnable", e);
        }
    }

    /**
     * Disable wakelock to allow the screen to sleep
     */
    public static void wakelockDisable() {
        if (wakeLock != null && wakeLock.isHeld()) {
            try {
                wakeLock.release();
                Log.d(TAG, "Wakelock disabled");
            } catch (Exception e) {
                Log.e(TAG, "Error releasing wakelock", e);
            }
        }
    }

    /**
     * Check if wakelock is currently enabled
     */
    public static boolean wakelockIsEnabled() {
        return wakeLock != null && wakeLock.isHeld();
    }

    // ========================================================================
    // Motion Sensors (Accelerometer / Gyroscope)
    // ========================================================================

    public static boolean isMotionAvailable() {
        if (sensorManager == null) {
            sensorManager = (SensorManager) appContext.getSystemService(Context.SENSOR_SERVICE);
        }
        if (sensorManager == null) return false;
        return sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null ||
               sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null;
    }

    public static void startMotionSensors(List<String> sensors, int intervalMs) {
        if (sensorManager == null) {
            sensorManager = (SensorManager) appContext.getSystemService(Context.SENSOR_SERVICE);
        }
        if (sensorManager == null) {
            Log.e(TAG, "SensorManager not available");
            return;
        }

        synchronized (motionLock) {
            motionIntervalMs = intervalMs;
            wantAccel = sensors.contains("accelerometer");
            wantGyro = sensors.contains("gyro");

            if (motionRunning) {
                stopMotionSensors();
            }

            final int delayUs = intervalMs * 1000; // convert ms to microseconds

            if (wantAccel) {
                accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
                if (accelerometer != null) {
                    sensorManager.registerListener(motionEventListener, accelerometer, delayUs);
                }
            }

            if (wantGyro) {
                gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
                if (gyroscope != null) {
                    sensorManager.registerListener(motionEventListener, gyroscope, delayUs);
                }
            }

            motionRunning = true;
            Log.i(TAG, "Motion sensors started (interval=" + intervalMs + "ms)");
        }
    }

    public static void stopMotionSensors() {
        synchronized (motionLock) {
            sensorManager.unregisterListener(motionEventListener);
            motionRunning = false;
            Log.i(TAG, "Motion sensors stopped");
        }
    }

    private static final SensorEventListener motionEventListener = new SensorEventListener() {
        @Override
        public void onSensorChanged(SensorEvent event) {
            synchronized (motionLock) {
                long now = System.currentTimeMillis();
                if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
                    lastAx = event.values[0];
                    lastAy = event.values[1];
                    lastAz = event.values[2];
                    lastMotionTimestamp = now;
                } else if (event.sensor.getType() == Sensor.TYPE_GYROSCOPE) {
                    lastGx = event.values[0];
                    lastGy = event.values[1];
                    lastGz = event.values[2];
                    lastMotionTimestamp = now;
                }
                // Deliver combined data at interval
                nativeMotionData(lastAx, lastAy, lastAz, lastGx, lastGy, lastGz, lastMotionTimestamp);
            }
        }

        @Override
        public void onAccuracyChanged(Sensor sensor, int accuracy) {
            // Not needed
        }
    };

    // ========================================================================
    // NFC
    // ========================================================================

    public static boolean isNFCAvailable() {
        if (nfcAdapter == null) {
            nfcAdapter = NfcAdapter.getDefaultAdapter(appContext);
        }
        return nfcAdapter != null && nfcAdapter.isEnabled();
    }

    public static void startNFCScan(Activity activity) {
        if (nfcAdapter == null) {
            nfcAdapter = NfcAdapter.getDefaultAdapter(appContext);
        }
        if (nfcAdapter == null) {
            Log.e(TAG, "NFC not available");
            nativeNFCError("NFC not available on this device");
            return;
        }
        if (!nfcAdapter.isEnabled()) {
            Log.e(TAG, "NFC is disabled");
            nativeNFCError("NFC is disabled");
            return;
        }

        try {
            IntentFilter ndefFilter = new IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED);
            try {
                ndefFilter.addDataType("*/*");
            } catch (IntentFilter.MalformedMimeTypeException e) {
                Log.e(TAG, "Failed to add MIME type", e);
            }
            nfcAdapter.enableForegroundDispatch(activity,
                PendingIntent.getActivity(activity, 0, new Intent(activity, activity.getClass()).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                    PendingIntent.FLAG_MUTABLE),
                new IntentFilter[]{ndefFilter},
                null);
            nfcScanning = true;
            Log.i(TAG, "NFC scan started");
        } catch (Exception e) {
            Log.e(TAG, "Failed to start NFC scan", e);
            nativeNFCError(e.getMessage());
        }
    }

    public static void stopNFCScan(Activity activity) {
        if (nfcAdapter != null && nfcScanning) {
            nfcAdapter.disableForegroundDispatch(activity);
            nfcScanning = false;
            Log.i(TAG, "NFC scan stopped");
        }
    }

    public static void handleNFCIntent(Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        if (NfcAdapter.ACTION_NDEF_DISCOVERED.equals(action) ||
            NfcAdapter.ACTION_TAG_DISCOVERED.equals(action) ||
            NfcAdapter.ACTION_TECH_DISCOVERED.equals(action)) {
            Tag tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
            if (tag != null) {
                String[] techList = tag.getTechList();
                String tech = techList.length > 0 ? techList[0] : "unknown";
                tech = tech.substring(tech.lastIndexOf('.') + 1);

                // Try to read NDEF data
                Ndef ndef = Ndef.get(tag);
                String payload = "";
                if (ndef != null) {
                    try {
                        ndef.connect();
                        NdefMessage msg = ndef.getNdefMessage();
                        if (msg != null && msg.getRecords().length > 0) {
                            byte[] payloadBytes = msg.getRecords()[0].getPayload();
                            payload = new String(payloadBytes, "UTF-8");
                        }
                        ndef.close();
                    } catch (Exception e) {
                        Log.e(TAG, "Failed to read NDEF", e);
                    }
                }
                nativeNFCTagDiscovered(tech, payload);
            }
        }
    }
}
