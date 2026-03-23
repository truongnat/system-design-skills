#!/bin/bash

# System Design Skills - Installer
# Helps install or link this skill to your AI agents (Gemini CLI, Cursor, etc.)

set -e

REPO_URL="https://github.com/truongdq/system-design-skills.git"
RAW_URL="https://raw.githubusercontent.com/truongdq/system-design-skills/main"
SKILL_NAME="system-design-overview"
DEFAULT_INSTALL_DIR="$HOME/.gemini/skills/$SKILL_NAME"

echo "🚀 Starting System Design Skills installation..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Local Link Mode (if running inside the repo)
if [ -f "SKILL.md" ]; then
    echo "📍 Local directory detected. Linking skill..."
    if command_exists gemini; then
        gemini skills link .
        echo "✅ Skill linked successfully to Gemini CLI."
    else
        echo "⚠️  Gemini CLI not found. Manual link needed."
    fi

# 2. Remote Install Mode (via curl | bash or running from outside)
else
    echo "🌐 Remote installation mode..."
    
    if command_exists gemini; then
        echo "📦 Using Gemini CLI to install..."
        gemini skills install $REPO_URL
        echo "✅ Skill installed successfully via Gemini CLI."
    else
        echo "📂 Gemini CLI not found. Cloning to $DEFAULT_INSTALL_DIR..."
        mkdir -p "$HOME/.gemini/skills"
        
        if [ -d "$DEFAULT_INSTALL_DIR" ]; then
            echo "♻️  Updating existing installation..."
            cd "$DEFAULT_INSTALL_DIR" && git pull
        else
            git clone --depth 1 $REPO_URL "$DEFAULT_INSTALL_DIR"
        fi
        
        echo "✅ Files installed to $DEFAULT_INSTALL_DIR"
        echo "💡 Note: You can now point your AI Agent (Cursor/Claude) to this folder."
    fi
fi

echo "✨ Done! Use this skill by asking your agent about system architecture."
