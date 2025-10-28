# VoiceInk Build Scripts

## Quick Start

To build and install VoiceInk on a new Mac:

```bash
cd /path/to/VoiceInk
./scripts/run.sh
```

That's it! The script will automatically:
1. ✅ Check for Xcode and command line tools
2. ✅ Clone whisper.cpp if needed
3. ✅ Install cmake via Homebrew if needed
4. ✅ Build whisper.cpp XCFramework (5-10 minutes, only on first run)
5. ✅ Build VoiceInk in Release configuration
6. ✅ Install to `/Applications/VoiceInk.app`
7. ✅ Replace existing installation if present
8. ✅ Launch the app

## Prerequisites

- **macOS 14.0 or later**
- **Xcode** (latest version recommended)
  - Install from Mac App Store
  - Run `xcode-select --install` for command line tools
- **Homebrew** (optional, but recommended for automatic cmake installation)
  - Install from https://brew.sh
  - Or install cmake manually

## What the Script Does

### First-Time Setup (Automatic)

1. **whisper.cpp dependency**
   - Checks if `../whisper.cpp/build-apple/whisper.xcframework` exists
   - If not found:
     - Clones whisper.cpp repository
     - Installs cmake (via Homebrew if available)
     - Builds the XCFramework (takes 5-10 minutes)
   - This only happens once!

2. **VoiceInk build**
   - Cleans previous build artifacts
   - Builds in Release configuration with ad-hoc signing
   - Creates app bundle at `build/Build/Products/Release/VoiceInk.app`

3. **Installation**
   - Quits any running VoiceInk instance
   - Removes existing installation from `/Applications`
   - Copies new build to `/Applications/VoiceInk.app`
   - Sets correct permissions
   - Launches the app

### Subsequent Runs

After the first successful run:
- ✅ whisper.cpp is already built (skipped)
- ✅ Only VoiceInk needs to be rebuilt
- ✅ Build time: ~2-3 minutes
- ✅ Automatic installation and launch

## Permissions

Since the app is built without code signing (for development), macOS will require you to grant permissions on first launch:

```bash
# After first build, reset permissions (required once per build):
killall VoiceInk
tccutil reset Accessibility com.prakashjoshipax.VoiceInk
tccutil reset ScreenCapture com.prakashjoshipax.VoiceInk
tccutil reset Microphone com.prakashjoshipax.VoiceInk
open /Applications/VoiceInk.app
```

Or grant them manually in:
- System Settings → Privacy & Security → Accessibility
- System Settings → Privacy & Security → Screen Recording
- System Settings → Privacy & Security → Microphone

## Troubleshooting

### Build Fails

1. **Clean everything and retry:**
   ```bash
   cd /path/to/VoiceInk
   rm -rf build
   cd ../whisper.cpp
   rm -rf build-*
   cd ../VoiceInk
   ./scripts/run.sh
   ```

2. **Check Xcode:**
   - Make sure Xcode is installed and up to date
   - Run: `xcode-select --install`
   - Accept Xcode license: `sudo xcodebuild -license accept`

3. **Check cmake:**
   - Run: `brew install cmake` (if you have Homebrew)
   - Or download from: https://cmake.org/download/

### App Won't Launch

1. **Check permissions** (see Permissions section above)
2. **Check macOS Gatekeeper:**
   ```bash
   xattr -cr /Applications/VoiceInk.app
   ```

### whisper.cpp Build Issues

If whisper.cpp fails to build:
```bash
cd /path/to/whisper.cpp
# Check for build issues
./build-xcframework.sh
```

## Directory Structure

```
yaananth/
├── VoiceInk/              # Main project
│   ├── VoiceInk/          # Source code
│   ├── scripts/
│   │   ├── run.sh         # This script
│   │   └── README.md      # This file
│   └── build/             # Build output (auto-created)
└── whisper.cpp/           # Dependency (auto-cloned)
    └── build-apple/
        └── whisper.xcframework  # Built framework
```

## Development Workflow

1. **Make changes** to VoiceInk source code
2. **Rebuild and install:**
   ```bash
   ./scripts/run.sh
   ```
3. **Test** the changes
4. **Repeat!**

The script handles everything automatically, including:
- Quitting the running app
- Replacing the installation
- Relaunching with your changes

## For Production

For production builds with proper code signing:
1. Get an Apple Developer account
2. Update the build script to use your signing identity
3. Or build through Xcode with proper provisioning profiles

## Notes

- Build time (first run): ~10-15 minutes (whisper.cpp + VoiceInk)
- Build time (subsequent): ~2-3 minutes (VoiceInk only)
- Disk space required: ~500MB for build artifacts
- The app is built without code signing for ease of development
- Each build is treated as a "new" app by macOS security
