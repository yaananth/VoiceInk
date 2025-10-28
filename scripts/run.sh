#!/bin/bash

set -e

echo "🚀 VoiceInk Build and Install Script"
echo "====================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
PARENT_DIR="$( cd "$PROJECT_DIR/.." && pwd )"

# Configuration
PROJECT_NAME="VoiceInk"
SCHEME_NAME="VoiceInk"
CONFIGURATION="Release"
APP_NAME="VoiceInk.app"
WHISPER_DIR="$PARENT_DIR/whisper.cpp"
WHISPER_XCFRAMEWORK="$WHISPER_DIR/build-apple/whisper.xcframework"

echo "📁 Project directory: $PROJECT_DIR"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode command line tools not found"
    echo "   Please install Xcode and run: xcode-select --install"
    exit 1
fi

# Check for whisper.cpp XCFramework
echo "🔍 Checking for whisper.cpp XCFramework..."
if [ ! -d "$WHISPER_XCFRAMEWORK" ]; then
    echo "   ⚠️  whisper.cpp XCFramework not found"
    
    # Check if whisper.cpp repo exists
    if [ ! -d "$WHISPER_DIR" ]; then
        echo "   📥 Cloning whisper.cpp..."
        cd "$PARENT_DIR"
        git clone https://github.com/ggerganov/whisper.cpp.git
        
        if [ $? -ne 0 ]; then
            echo "❌ Failed to clone whisper.cpp"
            exit 1
        fi
    fi
    
    # Check for cmake
    if ! command -v cmake &> /dev/null; then
        echo "   📦 Installing cmake via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "❌ Error: Homebrew is required to install cmake"
            echo "   Install Homebrew from https://brew.sh"
            exit 1
        fi
        brew install cmake
    fi
    
    # Build whisper.cpp XCFramework
    echo "   🔨 Building whisper.cpp XCFramework (this may take 5-10 minutes)..."
    cd "$WHISPER_DIR"
    ./build-xcframework.sh
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to build whisper.cpp XCFramework"
        exit 1
    fi
    
    echo "   ✅ whisper.cpp XCFramework built successfully"
else
    echo "   ✅ whisper.cpp XCFramework found"
fi

# Navigate to project directory
cd "$PROJECT_DIR"

echo "🧹 Cleaning build artifacts..."
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" > /dev/null 2>&1 || true

echo "🔨 Building $PROJECT_NAME in $CONFIGURATION mode..."
echo "   This may take a few minutes..."
echo ""

# Build the project with ad-hoc signing
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$PROJECT_DIR/build" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "✅ Build completed successfully!"
echo ""

# Find the built app
BUILT_APP="$PROJECT_DIR/build/Build/Products/$CONFIGURATION/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Error: Built app not found at $BUILT_APP"
    exit 1
fi

echo "📦 Built app location: $BUILT_APP"
echo ""

# Install to /Applications
INSTALL_PATH="/Applications/$APP_NAME"

echo "📲 Installing to /Applications..."

# Check if app already exists
if [ -d "$INSTALL_PATH" ]; then
    echo "   ⚠️  Existing installation found, replacing..."
    
    # Check if app is running and quit it
    if pgrep -x "VoiceInk" > /dev/null; then
        echo "   🛑 Quitting running VoiceInk..."
        osascript -e 'quit app "VoiceInk"' 2>/dev/null || killall VoiceInk 2>/dev/null || true
        sleep 2
    fi
    
    # Remove old version
    rm -rf "$INSTALL_PATH"
fi

# Copy new version
cp -R "$BUILT_APP" "$INSTALL_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Installation failed!"
    exit 1
fi

echo "✅ Installation completed!"
echo ""

# Fix permissions
echo "🔐 Setting correct permissions..."
chmod -R 755 "$INSTALL_PATH"
xattr -cr "$INSTALL_PATH" 2>/dev/null || true

echo ""
echo "🔄 Resetting macOS permissions..."
echo "   (This ensures the new build gets fresh permissions)"

# Reset all permissions for the app
tccutil reset Accessibility com.prakashjoshipax.VoiceInk 2>/dev/null || true
tccutil reset ScreenCapture com.prakashjoshipax.VoiceInk 2>/dev/null || true
tccutil reset Microphone com.prakashjoshipax.VoiceInk 2>/dev/null || true
tccutil reset SystemPolicyAllFiles com.prakashjoshipax.VoiceInk 2>/dev/null || true

echo "   ✅ Permissions reset - you'll be prompted to grant them on launch"
echo ""
echo "🎉 Success! VoiceInk has been installed to /Applications"
echo ""
echo "🚀 Launching VoiceInk..."
echo "   ⚠️  Please grant Accessibility, Screen Recording, and Microphone permissions when prompted"
open -a "$INSTALL_PATH"

echo ""
echo "✨ All done! VoiceInk is now running."
echo "   Grant the permissions in the system prompts to use all features."
echo ""
