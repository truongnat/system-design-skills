#!/bin/bash
# Cursor Local-First Installer (GSD-style)
# This script installs the system design skills DIRECTLY into your project.

REPO_RAW_URL="https://raw.githubusercontent.com/truongnat/system-design-skills/main"
RULES_DIR=".cursor/rules"
SKILLS_LOCAL_DIR="$RULES_DIR/system-design"

echo "🚀 Installing System Design Skills LOCALLY into your project..."

# 1. Create directories
mkdir -p "$SKILLS_LOCAL_DIR"

# 2. List of files to download
FILES=(
  "SKILL.md"
  "references/ai-engineering.md"
  "references/anti-patterns.md"
  "references/backend-hld.md"
  "references/compliance.md"
  "references/cross-cutting.md"
  "references/data-pipelines.md"
  "references/decision-trees.md"
  "references/deprecated.md"
  "references/edge-wasm.md"
  "references/finops.md"
  "references/frontend.md"
  "references/lld.md"
  "references/mobile.md"
  "references/platform-engineering.md"
  "references/sizing-guide.md"
  "references/testing-automation.md"
  "references/testing-fundamentals.md"
  "references/ui-design-system.md"
)

# 3. Download each file
for file in "${FILES[@]}"; do
  filename=$(basename "$file")
  echo "📡 Downloading $filename..."
  curl -sSL "$REPO_RAW_URL/$file" -o "$SKILLS_LOCAL_DIR/$filename"
done

# 4. Create the Master Engine (.mdc)
echo "🧠 Creating the Architect Engine..."
cat <<EOF > "$RULES_DIR/system-design.mdc"
---
description: Senior System Architect. Use for HLD, LLD, Scaling, DB selection, AI, and Compliance.
globs: "**/*"
alwaysApply: true
---

# 🏗️ System Design Architect (Local-First)

You are a Senior System Architect. Your knowledge base is located locally in \`.cursor/rules/system-design/\`.

## 📋 PRE-FLIGHT CHECK
Before answering any architecture query, you MUST:
1. **Read \`.cursor/rules/system-design/SKILL.md\`** to understand the routing table.
2. **Consult \`.cursor/rules/system-design/decision-trees.md\`** for quick decision paths.

## 🔍 DEEP DIVE
Based on the routing, read the specific file in \`.cursor/rules/system-design/\`:
- For DB/Scaling: \`backend-hld.md\`
- For AI/RAG: \`ai-engineering.md\`
- For Security: \`cross-cutting.md\`
- For Code Patterns: \`lld.md\`

## 📜 MANDATES
- Ask the **3 First Questions** (Scale, Team, Constraints) before proposing solutions.
- Use **XML tags** (<thought>, <plan>) for complex reasoning.
- Reference the specific local file you used in your answer.

---
*Installed locally in .cursor/rules/system-design/*
EOF

echo ""
echo "✅ SUCCESS! System Design Skills are now installed in your project."
echo "📂 Check your sidebar: .cursor/rules/system-design/ is now populated."
echo "💡 You can now commit these files to your repository."
