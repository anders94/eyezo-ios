# EyeZo

**A radically simple video server for your home network.**

## Philosophy

EyeZo was created out of frustration with existing home media servers like Plex and Jellyfin. While these solutions are feature-rich, they often feel like overkill for simple use cases. EyeZo takes a different approach:

### What We Believe

- **Your folders are already organized.** We don't try to guess, reorganize, or fetch metadata. Your file structure is respected exactly as you've arranged it.
- **Native is better.** We use standard OS components instead of reinventing the wheel. The system video player works great - why replace it?
- **Lightweight wins.** No heavy server processes, no complex configuration, no resource consumption. Just a simple API serving your videos.
- **Simple beats complex.** We'd rather do a few things well than everything poorly.

### What This Means

If you want automatic metadata fetching, poster art, actor information, recommendations, user management, transcoding, or dozens of other features - EyeZo is **not for you**. Use Plex or Jellyfin instead.

If you want to point an app at a folder of videos and just watch them - EyeZo might be exactly what you need.

## What EyeZo Does

### Server
- Serves videos from a directory on your machine
- Provides a simple REST API for browsing and streaming
- Tracks watch progress
- Generates thumbnails automatically
- Runs with minimal configuration and resources

### iOS/iPadOS App
- Browse your video folder structure
- Stream videos with native playback controls
- Download videos for offline viewing
- Automatic watch progress sync
- Background downloads
- Clean, native iOS interface

### visionOS App
- Spatial video viewing experience
- Same browsing and streaming capabilities as iOS
- Native visionOS interface

### tvOS App
- Browse and stream on Apple TV
- Native tvOS player with remote support
- Watch progress tracking

## What EyeZo Doesn't Do

- Metadata fetching or management
- Content reorganization
- Transcoding
- User management beyond basic access
- Recommendations or discovery features
- Subtitle management (uses whatever subtitles are already embedded)
- Multi-user libraries with permissions
- Content sharing outside your network
- Parental controls
- Collections or playlists (use folders)

## Technical Details

### Server Requirements
- Node.js runtime
- A folder with video files
- Network access

### Supported Platforms
- **Server**: macOS, Linux, Windows (Node.js)
- **Clients**: iOS 18+, iPadOS 18+, visionOS 2+, tvOS 18+
- **Planned**: Android, Web

### Open Source
All EyeZo projects are open source and free:
- Server: https://github.com/anders94/eyezo-server
- iOS: https://github.com/anders94/eyezo-ios
- visionOS: https://github.com/anders94/eyezo-visionos
- tvOS: https://github.com/anders94/eyezo-tvos

### Distribution
- **App Store**: Available for convenience (no app review delays or installation complexity)
- **Source**: Clone and compile yourself - you own the code
- **Contributions**: Pull requests welcome on all repositories

## Who Should Use EyeZo

### Great For
- People with already-organized video collections
- Home users who just want to watch their videos
- Privacy-focused users who want complete control
- Users frustrated with bloated media server solutions
- Developers who want simple, hackable media serving

### Not Great For
- Users who want automatic content organization
- People expecting a polished commercial product
- Users who need transcoding for device compatibility
- Anyone wanting a "complete" media center solution

## Philosophy on Features

We are **very opinionated** about keeping EyeZo simple. Feature requests will often be declined if they add complexity. We'd rather be excellent at one thing than mediocre at many things.

That said, we welcome:
- Bug fixes
- Performance improvements
- Platform ports (Android, web)
- UI/UX refinements that maintain simplicity
- Accessibility improvements

## Getting Started

### Server Setup
1. Install Node.js
2. Clone the server repository
3. Point it at your video folder
4. Run it

See the server repository for detailed instructions.

### Client Setup
1. Install the app (App Store or compile from source)
2. Enter your server URL
3. Start browsing

## Support

This is a free, open-source project maintained by volunteers. Support is community-driven through GitHub issues and discussions.

## License

MIT License - See individual repositories for details.

---

**EyeZo: Your videos. Your folders. Your server.**
