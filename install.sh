#!/bin/bash
# System Design Skills — Interactive Installer
set -e

# When piped via `curl | bash`, stdin is the pipe — redirect input from terminal
exec < /dev/tty

REPO="https://github.com/truongnat/system-design-skills.git"
RAW_BASE="https://raw.githubusercontent.com/truongnat/system-design-skills/main"
SKILL="system-design-overview"
SKILL_DIR="$HOME/.system-design-skills"   # single source of truth for all agents

# ── helpers ────────────────────────────────────────────────────────────────────
GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; RESET="\033[0m"
ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
info() { echo -e "${CYAN}   $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }

need_git()  { command -v git  &>/dev/null || { warn "git not found. Please install git first.";  exit 1; }; }
need_curl() { command -v curl &>/dev/null || { warn "curl not found. Please install curl first."; exit 1; }; }

# ── step 1: always clone/update the full repo ──────────────────────────────────
sync_repo() {
  need_git
  if [ -d "$SKILL_DIR/.git" ]; then
    info "Updating existing skill repo…"
    git -C "$SKILL_DIR" pull --depth 1 -q
  else
    info "Cloning full skill repo to $SKILL_DIR …"
    git clone --depth 1 -q "$REPO" "$SKILL_DIR"
  fi
  ok "Skill files ready at $SKILL_DIR"
}

# ── step 2: link/configure per agent ──────────────────────────────────────────

link_claude_code() {  # $1 = target skills dir
  mkdir -p "$1"
  # Symlink so updates to $SKILL_DIR are instant
  if [ -L "$1/$SKILL" ]; then
    info "Symlink already exists, skipping."
  else
    ln -s "$SKILL_DIR" "$1/$SKILL"
    info "Symlinked → $1/$SKILL"
  fi
}

write_agents_md() {   # $1 = file path
  need_curl
  mkdir -p "$(dirname "$1")"
  # Prepend a reference block pointing to the local skill dir
  REF_BLOCK="## System Design Skills\n\nLocal skill dir: \`$SKILL_DIR\`\n\nWhen answering architecture, scaling, DB, caching, queues, AI engineering, compliance, or cost questions:\n1. Read \`$SKILL_DIR/SKILL.md\` for the routing table\n2. Load the referenced domain file from \`$SKILL_DIR/references/\`\n\n"
  if grep -q "System Design Skills" "$1" 2>/dev/null; then
    info "Already present in $1, skipping."
  else
    { printf '%b' "$REF_BLOCK"; cat "$1" 2>/dev/null || true; } > "$1.tmp" && mv "$1.tmp" "$1"
    info "Updated → $1"
  fi
}

write_cursor_mdc() {
  mkdir -p ".cursor/rules"
  DEST=".cursor/rules/system-design.mdc"

  echo; info "Choose load mode for Cursor:"
  echo "  1) alwaysApply: true   — load vào mọi chat (recommended)"
  echo "  2) globs: **/*         — load khi có file nào đang mở"
  echo "  3) description only    — AI tự quyết (không đảm bảo)"
  read -rp "  → " cm
  case $cm in
    2) FRONTMATTER="---\ndescription: System design reference. Apply for architecture, scaling, DB, caching, AI engineering, compliance questions.\nglobs: \"**/*\"\nalwaysApply: false\n---" ;;
    3) FRONTMATTER="---\ndescription: System design reference. Apply for architecture, scaling, DB, caching, AI engineering, compliance questions.\nalwaysApply: false\n---" ;;
    *) FRONTMATTER="---\ndescription: System design reference. Apply for architecture, scaling, DB, caching, AI engineering, compliance questions.\nalwaysApply: true\n---" ;;
  esac

  printf "%b\n\n## System Design Skills\n\nLocal skill dir: \`%s\`\n\nWhen answering architecture or design questions:\n1. Read \`%s/SKILL.md\` for the routing table\n2. Load the relevant file from \`%s/references/\`\n" \
    "$FRONTMATTER" "$SKILL_DIR" "$SKILL_DIR" "$SKILL_DIR" > "$DEST"
  info "Written → $DEST"
}

# ── installers ─────────────────────────────────────────────────────────────────
install_claude_code() {
  echo; info "Choose scope:"
  echo "  1) Global  (~/.claude/skills/)"
  echo "  2) Project (.claude/skills/)"
  read -rp "  → " s
  case $s in
    1) link_claude_code "$HOME/.claude/skills" ;;
    2) link_claude_code ".claude/skills" ;;
    *) warn "Invalid choice"; return ;;
  esac
  ok "Claude Code installed."
}

install_cursor() {
  echo; info "Choose method:"
  echo "  1) .cursor/rules/system-design.mdc  (native — recommended)"
  echo "  2) AGENTS.md                        (cross-tool standard)"
  echo "  3) Both"
  read -rp "  → " s
  [[ $s == 1 || $s == 3 ]] && write_cursor_mdc
  [[ $s == 2 || $s == 3 ]] && write_agents_md "AGENTS.md"
  ok "Cursor installed."
}

install_windsurf() {
  echo; info "Choose method:"
  echo "  1) .windsurfrules  (native)"
  echo "  2) AGENTS.md       (cross-tool standard)"
  echo "  3) Both"
  read -rp "  → " s
  [[ $s == 1 || $s == 3 ]] && write_agents_md ".windsurfrules"
  [[ $s == 2 || $s == 3 ]] && write_agents_md "AGENTS.md"
  ok "Windsurf installed."
}

install_copilot() {
  echo; info "Choose method:"
  echo "  1) .github/copilot-instructions.md  (GitHub Copilot native)"
  echo "  2) AGENTS.md                        (cross-tool standard)"
  echo "  3) Both"
  read -rp "  → " s
  [[ $s == 1 || $s == 3 ]] && write_agents_md ".github/copilot-instructions.md"
  [[ $s == 2 || $s == 3 ]] && write_agents_md "AGENTS.md"
  ok "GitHub Copilot / VS Code installed."
}

install_gemini() {
  echo; info "Choose method:"
  echo "  1) Global  (~/.gemini/skills/)"
  echo "  2) GEMINI.md  (project-level)"
  echo "  3) Both"
  read -rp "  → " s
  if [[ $s == 1 || $s == 3 ]]; then
    mkdir -p "$HOME/.gemini/skills"
    if [ -L "$HOME/.gemini/skills/$SKILL" ]; then
      info "Symlink already exists, skipping."
    else
      ln -s "$SKILL_DIR" "$HOME/.gemini/skills/$SKILL"
      info "Symlinked → ~/.gemini/skills/$SKILL"
    fi
  fi
  [[ $s == 2 || $s == 3 ]] && write_agents_md "GEMINI.md"
  ok "Gemini CLI installed."
}

install_agents_md() {
  write_agents_md "AGENTS.md"
  ok "AGENTS.md updated (Codex CLI, Devin, Amp, and any AGENTS.md-compatible agent)."
}

install_all() {
  info "Installing for all agents…"
  link_claude_code "$HOME/.claude/skills"
  write_cursor_mdc
  write_agents_md ".windsurfrules"
  write_agents_md ".github/copilot-instructions.md"
  write_agents_md "AGENTS.md"
  write_agents_md "GEMINI.md"
  mkdir -p "$HOME/.gemini/skills"
  [ -L "$HOME/.gemini/skills/$SKILL" ] || ln -s "$SKILL_DIR" "$HOME/.gemini/skills/$SKILL"
  # CLAUDE.md → reference AGENTS.md
  grep -q "@AGENTS.md" CLAUDE.md 2>/dev/null || echo -e "\n@AGENTS.md" >> CLAUDE.md
  ok "All agents configured."
}

# ── main ───────────────────────────────────────────────────────────────────────
echo
echo -e "${CYAN}╔══════════════════════════════════════════╗"
echo    "║   System Design Skills — Installer       ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo

# Always sync the full repo first
sync_repo
echo

echo "  Which agent(s) do you want to configure?"
echo
echo "  1) Claude Code"
echo "  2) Cursor"
echo "  3) Windsurf"
echo "  4) GitHub Copilot / VS Code"
echo "  5) Gemini CLI"
echo "  6) AGENTS.md (Codex CLI / Devin / Amp / universal)"
echo "  7) All of the above"
echo "  0) Cancel"
echo
read -rp "  → " choice

case $choice in
  1) install_claude_code ;;
  2) install_cursor ;;
  3) install_windsurf ;;
  4) install_copilot ;;
  5) install_gemini ;;
  6) install_agents_md ;;
  7) install_all ;;
  0) echo "Cancelled."; exit 0 ;;
  *) warn "Invalid choice."; exit 1 ;;
esac

echo
echo -e "${GREEN}✨ Done!${RESET}"
info "Skill files: $SKILL_DIR"
info "Run again anytime to update or add more agents."
echo
