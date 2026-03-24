#!/bin/bash
# System Design Skills — Interactive Installer
set -e

# When piped via `curl | bash`, stdin is the pipe — redirect input from terminal
exec < /dev/tty

REPO="https://github.com/truongnat/system-design-skills.git"
RAW="https://raw.githubusercontent.com/truongnat/system-design-skills/main/SKILL.md"
SKILL="system-design-overview"

# ── helpers ────────────────────────────────────────────────────────────────────
GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; RESET="\033[0m"
ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
info() { echo -e "${CYAN}   $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }

need_git()  { command -v git  &>/dev/null || { warn "git not found. Please install git first.";  exit 1; }; }
need_curl() { command -v curl &>/dev/null || { warn "curl not found. Please install curl first."; exit 1; }; }

clone_or_pull() {   # $1 = destination
  need_git
  if [ -d "$1/.git" ]; then
    info "Updating existing install…"; git -C "$1" pull --depth 1 -q
  else
    git clone --depth 1 -q "$REPO" "$1"
  fi
}

append_skill() {    # $1 = file path
  need_curl
  mkdir -p "$(dirname "$1")"
  curl -sSL "$RAW" >> "$1"
  info "Appended → $1"
}

write_skill() {     # $1 = file path, $2 = optional prepend text
  need_curl
  mkdir -p "$(dirname "$1")"
  if [ -n "$2" ]; then
    { printf '%b' "$2"; curl -sSL "$RAW"; } > "$1"
  else
    curl -sSL "$RAW" -o "$1"
  fi
  info "Written → $1"
}

# ── installers ─────────────────────────────────────────────────────────────────
install_claude_code() {
  echo; info "Choose scope:"
  echo "  1) Global  (~/.claude/skills/)"
  echo "  2) Project (.claude/skills/)"
  read -rp "  → " s
  case $s in
    1) clone_or_pull "$HOME/.claude/skills/$SKILL" ;;
    2) clone_or_pull ".claude/skills/$SKILL" ;;
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
  MDC_FRONT="---\ndescription: System design reference. Apply for architecture, scaling, DB, caching, AI engineering questions.\nalwaysApply: false\n---\n\n"
  [[ $s == 1 || $s == 3 ]] && write_skill ".cursor/rules/system-design.mdc" "$MDC_FRONT"
  [[ $s == 2 || $s == 3 ]] && append_skill "AGENTS.md"
  ok "Cursor installed."
}

install_windsurf() {
  echo; info "Choose method:"
  echo "  1) .windsurfrules  (native)"
  echo "  2) AGENTS.md       (cross-tool standard)"
  echo "  3) Both"
  read -rp "  → " s
  [[ $s == 1 || $s == 3 ]] && append_skill ".windsurfrules"
  [[ $s == 2 || $s == 3 ]] && append_skill "AGENTS.md"
  ok "Windsurf installed."
}

install_copilot() {
  echo; info "Choose method:"
  echo "  1) .github/copilot-instructions.md  (GitHub Copilot native)"
  echo "  2) AGENTS.md                        (cross-tool standard)"
  echo "  3) Both"
  read -rp "  → " s
  [[ $s == 1 || $s == 3 ]] && append_skill ".github/copilot-instructions.md"
  [[ $s == 2 || $s == 3 ]] && append_skill "AGENTS.md"
  ok "GitHub Copilot / VS Code installed."
}

install_gemini() {
  echo; info "Choose method:"
  echo "  1) Global  (~/.gemini/skills/)"
  echo "  2) GEMINI.md  (project-level)"
  echo "  3) Both"
  read -rp "  → " s
  [[ $s == 1 || $s == 3 ]] && clone_or_pull "$HOME/.gemini/skills/$SKILL"
  [[ $s == 2 || $s == 3 ]] && append_skill "GEMINI.md"
  ok "Gemini CLI installed."
}

install_agents_md() {
  append_skill "AGENTS.md"
  ok "AGENTS.md updated (Codex CLI, Devin, Amp, and any AGENTS.md-compatible agent)."
}

install_all() {
  info "Installing for all agents…"
  clone_or_pull "$HOME/.claude/skills/$SKILL"
  MDC_FRONT="---\ndescription: System design reference. Apply for architecture, scaling, DB, caching, AI engineering questions.\nalwaysApply: false\n---\n\n"
  write_skill ".cursor/rules/system-design.mdc" "$MDC_FRONT"
  append_skill ".windsurfrules"
  append_skill ".github/copilot-instructions.md"
  append_skill "AGENTS.md"
  append_skill "GEMINI.md"
  echo -e "\n@AGENTS.md" >> CLAUDE.md
  ok "All agents configured."
}

# ── main menu ──────────────────────────────────────────────────────────────────
echo
echo -e "${CYAN}╔══════════════════════════════════════════╗"
echo    "║   System Design Skills — Installer       ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo
echo "  Which agent(s) do you want to install for?"
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
echo -e "${GREEN}✨ Done! Ask your agent about system architecture to activate the skill.${RESET}"
echo
