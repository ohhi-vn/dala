# iOS Bluetooth/WiFi Setup for Dala

Automated setup for iOS Bluetooth and WiFi functionality in Dala apps.

## Quick Start

```bash
# Run the automated setup
mix dala.setup_ios_bluetooth

# Or with custom ios directory
mix dala.setup_ios_bluetooth /path/to/ios

# Dry run to see what would be done
mix dala.setup_ios_bluetooth --dry-run
```

## What It Does

The setup script automatically:

1. **Finds your Xcode project** - Searches for `.xcworkspace` or `.xcodeproj` in the ios/ directory
2. **Adds Bluetooth files** to your Xcode project:
   - `DalaBluetoothManager.h`
   - `DalaBluetoothManager.m`
   - `DalaBluetoothCInterface.m`
   - `DalaBluetooth.swift`
3. **Links CoreBluetooth.framework** - Required for Bluetooth functionality
4. **Updates Info.plist** - Adds required usage descriptions:
   - `NSBluetoothAlwaysUsageDescription`
   - `NSBluetoothPeripheralUsageDescription`

## Prerequisites

- Xcode project exists in the `ios/` directory
- Ruby is available (for modifying `project.pbxproj`)
- `plutil` is available (for modifying `Info.plist`)
- Bluetooth source files are present in `ios/` directory

## Files Created/Modified

### Script
- `scripts/ios_setup.sh` - Bash script that performs the setup

### Elixir Module
- `lib/dala/setup/ios.ex` - Elixir module with setup functions

### Mix Task
- `lib/mix/tasks/dala.setup_ios_bluetooth.ex` - Mix task for command-line usage

### Template
- `ios/DalaAppDelegate.swift.template` - Template showing how to initialize Bluetooth in your AppDelegate

## Usage in Elixir

```elixir
# Check if Bluetooth is ready
case Dala.Bluetooth.state() do
  :powered_on ->
    Dala.Bluetooth.start_scan(socket)
    
  :unauthorized ->
    # Permission will be requested automatically on first use
    Dala.Permissions.request(socket, :bluetooth)
    
  state ->
    IO.puts("Bluetooth state: #{state}")
end

# Handle Bluetooth events
def handle_info({:bluetooth, :device_found, device}, socket) do
  IO.puts("Found device: #{device.name}")
  {:noreply, socket}
end

def handle_info({:bluetooth, :device_connected, device}, socket) do
  IO.puts("Connected to: #{device.name}")
  {:noreply, socket}
end
```

## Manual Setup (if needed)

If the automated setup doesn't work for your project structure:

1. Add these files to your Xcode project:
   - `ios/DalaBluetoothManager.h`
   - `ios/DalaBluetoothManager.m`
   - `ios/DalaBluetoothCInterface.m`
   - `ios/DalaBluetooth.swift`

2. Link `CoreBluetooth.framework` in your project settings

3. Add to Info.plist:
   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>This app uses Bluetooth to connect to nearby devices.</string>
   <key>NSBluetoothPeripheralUsageDescription</key>
   <string>This app uses Bluetooth to connect to nearby devices.</string>
   ```

4. Initialize Bluetooth early in app lifecycle (see `ios/DalaAppDelegate.swift.template`)

## Troubleshooting

### "No Xcode project found"
- Ensure you have an Xcode project in the `ios/` directory
- The script looks for `.xcworkspace` first, then `.xcodeproj`

### "Bluetooth files not found"
- Verify the Bluetooth files exist in `ios/` directory
- Check that you're running the setup from the correct directory

### Setup fails with Ruby errors
- Ensure Ruby is installed and available in your PATH
- The script uses Ruby to modify the `project.pbxproj` file

## How It Works

The setup uses:
- **Ruby** to parse and modify the Xcode `project.pbxproj` file (adding source files and frameworks)
- **plutil** to modify `Info.plist` (adding usage description keys)
- **Bash** to orchestrate the entire process

## See Also

- `Dala.Bluetooth` module documentation
- `Dala.Setup.IOS` module for programmatic access
- `ios/DalaAppDelegate.swift.template` for AppDelegate integration
