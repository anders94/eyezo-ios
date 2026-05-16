# Video Browser - iOS Client

A lightweight iOS app for browsing and playing videos from the video-server API.

## Features

- Native SwiftUI interface for iOS 15+ (iPhone & iPad)
- Server URL configuration with persistence
- Directory browsing with thumbnail previews
- Native video player with standard iOS controls
- Automatic server health checking
- Pull-to-refresh support
- HTTP range request support for video streaming

## Prerequisites

- macOS with Xcode 13.0 or later
- iOS 15.0+ device or simulator
- Running instance of video-server (default: http://127.0.0.1:3000)

## Setup Instructions

The Xcode project is already created with all source files in place.

### 1. Open the Project

```bash
open VideoClient/VideoClient.xcodeproj
```

Or double-click `VideoClient.xcodeproj` in Finder.

### 2. Clean Up (if needed)

Delete any auto-generated files that may conflict:
- If you see `ContentView.swift` in the Project Navigator, right-click > Delete > **Move to Trash**

### 3. Verify Settings

1. Select the project in Project Navigator (top item)
2. Select the **VideoClient** target
3. Go to **General** tab:
   - Verify **Minimum Deployments** is set to **iOS 15.0**
   - Ensure both **iPhone** and **iPad** are checked under Supported Destinations

### 4. Build and Run

1. Select a simulator or connected iOS device from the scheme selector (top bar)
2. Click the **Run** button (▶️) or press `Cmd+R`
3. The app will build and launch

**Note:** All source files are in `VideoClient/VideoClient/` - this is your working directory. Edit files directly in Xcode.

## Usage

### First Launch

1. The app will display a server setup screen
2. Enter your video-server URL:
   - **For iOS Simulator**: Use your Mac's IP address (e.g., `http://10.20.1.13:3000`)
     - Find your IP: System Settings > Network > Wi-Fi/Ethernet > Details
   - **For Physical Device**: Use your Mac's IP address on the same network
   - **Note**: `localhost` and `127.0.0.1` don't work reliably for video streaming in the simulator
3. Tap **Connect** to validate the server
4. On successful connection, you'll navigate to the directory browser

### Browsing Videos

- **Directories** appear first with a blue folder icon
- **Videos** appear below with thumbnails (or a film icon if thumbnails aren't available)
- Tap a directory to navigate into it
- Tap a video to play it in the native video player
- Use the back button to return to parent directories
- Pull down to refresh the current directory

### Playing Videos

- Videos open in a full-screen native player
- Standard iOS controls for play/pause, seeking, volume
- Tap the **X** button in the top-left to dismiss

### Server Issues

- If the server becomes unreachable, a red warning icon appears in the navigation bar
- Tap the warning icon to reconfigure the server URL
- The app automatically checks server health on launch

## Project Structure

```
VideoClient/
├── VideoClient/
│   ├── VideoClientApp.swift          # App entry point
│   ├── Models/
│   │   ├── BrowseResponse.swift      # API response models
│   │   ├── VideoItem.swift           # Video metadata
│   │   └── DirectoryItem.swift       # Directory metadata
│   ├── Services/
│   │   ├── APIService.swift          # Network layer
│   │   └── ServerURLManager.swift    # URL persistence
│   ├── Views/
│   │   ├── ServerSetupView.swift     # Server configuration
│   │   ├── DirectoryBrowserView.swift # Directory listing
│   │   └── VideoPlayerView.swift     # Video playback
│   ├── ViewModels/
│   │   └── DirectoryViewModel.swift  # Business logic
│   └── Info.plist                    # App configuration
└── README.md
```

## API Endpoints Used

- `GET /api/health` - Server health check
- `GET /api/browse` - Browse root directory
- `GET /api/browse/{path}` - Browse subdirectory
- `GET /api/video/{path}` - Stream video file
- `GET /api/thumbnail/{path}` - Get video thumbnail

## Troubleshooting

### Build Errors

- **Missing files**: Ensure all Swift files are added to the Xcode project target
- **Module not found**: Clean build folder (`Cmd+Shift+K`) and rebuild
- **Code signing**: For device deployment, configure your Apple Developer Team in project settings

### Runtime Issues

- **Cannot connect to server**: Verify video-server is running at the configured URL
- **Videos won't play**: Check that the video-server has proper file access permissions
- **Thumbnails not loading**: Thumbnails are generated on-demand; first load may be slow
- **HTTP not allowed**: Verify Info.plist includes `NSAppTransportSecurity` configuration

### Simulator vs Device

- **Localhost URLs**: On a physical device, `127.0.0.1` won't work - use your Mac's IP address
  - Find your Mac's IP: System Settings > Network > Wi-Fi/Ethernet > Details
  - Use format: `http://192.168.x.x:3000`
  - Ensure Mac and iOS device are on the same network

## Testing Checklist

- [ ] First launch shows server setup screen
- [ ] Can connect to video-server successfully
- [ ] Directories appear with folder icons
- [ ] Videos appear with thumbnails
- [ ] Can navigate into subdirectories
- [ ] Back button returns to parent directory
- [ ] Videos play in full-screen player
- [ ] Can seek/pause/play videos
- [ ] Pull-to-refresh works
- [ ] Server URL persists across app restarts
- [ ] App works on both iPhone and iPad
- [ ] Hidden files (starting with `.`) are not shown

## Development

Built with:
- SwiftUI (iOS 15+)
- AVKit for video playback
- URLSession for networking
- UserDefaults for persistence

Native iOS patterns:
- NavigationView/NavigationStack for navigation
- AsyncImage for thumbnail loading
- ObservableObject for state management
- async/await for asynchronous operations

## License

MIT
