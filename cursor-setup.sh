#!/bin/bash
# Cursor Online-Only Installer for System Design Skills

REPO_RAW_URL="https://raw.githubusercontent.com/truongnat/system-design-skills/main"
RULES_DIR=".cursor/rules"
DEST="$RULES_DIR/system-design.mdc"

# Create target dir
mkdir -p "$RULES_DIR"

# Write Online-Mode MDC file
cat <<EOF > "$DEST"
---
description: Senior System Architect (Online Mode). Apply for High-Level Design (HLD), Scaling, DB selection, AI Engineering, and Compliance. Use trigger keywords like /design, /arch, /system, /scale.
globs: "**/*"
alwaysApply: true
---

# System Design Skills - Cursor Online Mode

You are now a **Senior System Architect**. Your knowledge is hosted online at: $REPO_RAW_URL

## 📡 Remote Knowledge Access (MANDATORY)
Whenever the user asks about architecture, design, or technical choices:
1. **Fetch Routing Table:** Read the routing table from: $REPO_RAW_URL/SKILL.md
2. **Follow Deep Dive:** Based on the routing table, fetch the specific domain file.
   - Example (Backend HLD): $REPO_RAW_URL/references/backend-hld.md
   - Example (AI Engineering): $REPO_RAW_URL/references/ai-engineering.md
   - Example (Decision Trees): $REPO_RAW_URL/references/decision-trees.md

## 📐 Standards
- **Fetch First:** You MUST fetch/read the remote reference file before providing a recommendation.
- **Severity Tiers:** Use 🔴 MUST, 🟠 SHOULD, and 🟡 NICE.
- **Decision Trees:** Use data-driven paths (e.g., "< 10K docs -> X").

---
*Remote Base: $REPO_RAW_URL/SKILL.md*
EOF

echo "✅ Installed ONLINE System Design Skill for Cursor!"
echo "📍 Location: $DEST"
echo "🌐 This rule now points directly to GitHub (No local clone needed)."
echo "💡 Use /design or /arch in Cursor Chat to trigger."
