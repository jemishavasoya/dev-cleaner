#!/usr/bin/env bash

echo "🔍 Checking System Data Storage..."
echo ""

echo "📱 iOS Backups:"
du -sh ~/Library/Application\ Support/MobileSync/Backup 2>/dev/null || echo "None found"
echo ""

echo "🐳 Docker Storage:"
docker system df 2>/dev/null || echo "Docker not installed"
echo ""

echo "⏰ Time Machine Local Snapshots:"
tmutil listlocalsnapshots / 2>/dev/null | wc -l | xargs echo "Snapshots count:"
echo ""

echo "📧 Mail Data:"
du -sh ~/Library/Mail 2>/dev/null || echo "None found"
du -sh ~/Library/Mail\ Downloads 2>/dev/null || echo "None found"
echo ""

echo "💿 macOS Installers:"
du -sh /Applications/Install\ macOS*.app 2>/dev/null || echo "None found"
du -sh ~/Library/Updates 2>/dev/null || echo "None found"
echo ""

echo "🎵 Spotify Cache:"
du -sh ~/Library/Caches/com.spotify.client 2>/dev/null || echo "None found"
echo ""

echo "🤖 Claude Code versions:"
du -sh ~/.local/share/claude/versions 2>/dev/null || echo "None found"
echo ""

echo "📦 Largest directories in ~/Library:"
du -sh ~/Library/* 2>/dev/null | sort -hr | head -10
