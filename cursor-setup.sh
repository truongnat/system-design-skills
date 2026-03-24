#!/bin/bash
# Cursor Professional Setup (Rule & Skill Separation)
# Inspired by GSD-style modularity.

REPO_RAW_URL="https://raw.githubusercontent.com/truongnat/system-design-skills/main"
RULES_DIR=".cursor/rules"
SKILLS_DIR=".cursor/skills/system-design"

echo "🚀 Installing System Design Ecosystem..."

# 1. Create directory structure
mkdir -p "$RULES_DIR"
mkdir -p "$SKILLS_DIR"

# 2. Download the Knowledge Base (Skills)
FILES=(
  "SKILL.md"
  "references/ai-engineering.md"
  "references/adr-guide.md"
  "references/anti-patterns.md"
  "references/auth-multi-tenancy.md"
  "references/backend-hld.md"
  "references/compliance.md"
  "references/cross-cutting.md"
  "references/data-pipelines.md"
  "references/decision-trees.md"
  "references/deprecated.md"
  "references/deployment-release.md"
  "references/documentation-diagrams.md"
  "references/edge-case-analysis.md"
  "references/edge-wasm.md"
  "references/finops.md"
  "references/frontend.md"
  "references/lld.md"
  "references/migration-strategy.md"
  "references/mobile.md"
  "references/platform-engineering.md"
  "references/sizing-guide.md"
  "references/sre-incident-response.md"
  "references/tech-selection-strategy.md"
  "references/testing-automation.md"
  "references/testing-fundamentals.md"
  "references/ui-design-system.md"
)

echo "📡 Fetching Skills (Knowledge Base)..."
for file in "${FILES[@]}"; do
  filename=$(basename "$file")
  curl -sSL "$REPO_RAW_URL/$file" -o "$SKILLS_DIR/$filename"
done

# 3. Create the Master Rule (Instructions)
echo "🧠 Creating the Master Rule (.mdc)..."
cat <<EOF > "$RULES_DIR/system-design.mdc"
---
description: Senior System Architect Rule. Triggers on architecture, design, scaling, and system-level questions. Use /design command.
globs: "**/*"
alwaysApply: true
---

# 🏗️ System Design Architect Rule

You are a Senior System Architect. You MUST follow this rule to integrate your local skills.

## 📂 Skill Integration (Local-First)
Your specialized knowledge is located in: \`.cursor/skills/system-design/\`.
- **Primary Map:** Read \`.cursor/skills/system-design/SKILL.md\` first for routing.
- **Decision Engine:** Consult \`.cursor/skills/system-design/decision-trees.md\` for quick paths.
- **Domain Knowledge:** Read the relevant file in the same directory based on the user's query.

## 🚦 Execution Protocol
1.  **Identify Intent:** If the user asks about architecture, database selection, or scaling.
2.  **Check 3 Questions:** ALWAYS ask about (Scale, Team, Constraints) if not provided.
3.  **Read Skill:** Use the \`read_file\` tool to fetch the relevant skill from \`.cursor/skills/system-design/\`.
4.  **Synthesize:** Provide the answer using the standards (Severity Tiers, Anti-patterns) found in the skills.

## ⌨️ Trigger Commands
- /design: Full system design process.
- /arch: Code/Folder architecture review.

---
*Rule & Skill separated for context efficiency.*
EOF

echo ""
echo "✅ SUCCESS!"
echo "📍 Rules: $RULES_DIR/system-design.mdc"
echo "📂 Skills: $SKILLS_DIR/ (15+ reference files)"
echo "💡 You now have a clean separation of 'How to think' (Rules) and 'What to know' (Skills)."
