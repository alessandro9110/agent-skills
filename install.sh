#!/usr/bin/env bash
# Agent Skills Installer
# Installs skills + all required dependencies (databricks ai-dev-kit, langchain-skills)
# Usage: bash install.sh [--global] [--tools claude,cursor,copilot] [--yes]

set -e

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Defaults ─────────────────────────────────────────────────────────────────
GLOBAL=false
TOOLS="claude"        # comma-separated: claude,cursor,copilot
AUTO_YES=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --global|-g)   GLOBAL=true; shift ;;
    --tools|-t)    TOOLS="$2"; shift 2 ;;
    --yes|-y)      AUTO_YES=true; shift ;;
    --help|-h)
      echo "Usage: bash install.sh [--global] [--tools claude,cursor,copilot] [--yes]"
      echo ""
      echo "Options:"
      echo "  --global, -g         Install globally (~/.claude/skills, ~/.cursor/rules, etc.)"
      echo "  --tools, -t TOOLS    Comma-separated list of tools: claude,cursor,copilot (default: claude)"
      echo "  --yes, -y            Skip confirmation prompts"
      exit 0 ;;
    *) warn "Unknown option: $1"; shift ;;
  esac
done

# ── Resolve target directories ───────────────────────────────────────────────
declare -A SKILL_DIRS

IFS=',' read -ra TOOL_LIST <<< "$TOOLS"
for tool in "${TOOL_LIST[@]}"; do
  tool=$(echo "$tool" | tr -d ' ')
  if $GLOBAL; then
    case $tool in
      claude)  SKILL_DIRS["claude"]="$HOME/.claude/skills" ;;
      cursor)  SKILL_DIRS["cursor"]="$HOME/.cursor/rules" ;;
      copilot) SKILL_DIRS["copilot"]="$HOME/.github/skills" ;;
      *) warn "Unknown tool: $tool (supported: claude, cursor, copilot)" ;;
    esac
  else
    case $tool in
      claude)  SKILL_DIRS["claude"]="$(pwd)/.claude/skills" ;;
      cursor)  SKILL_DIRS["cursor"]="$(pwd)/.cursor/rules" ;;
      copilot) SKILL_DIRS["copilot"]="$(pwd)/.github/skills" ;;
      *) warn "Unknown tool: $tool (supported: claude, cursor, copilot)" ;;
    esac
  fi
done

if [ ${#SKILL_DIRS[@]} -eq 0 ]; then
  error "No valid tools specified."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Agent Skills Installer             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Skills to install:"
echo "  • Our skills:             azure-ai-foundry-agents, databricks-mosaic-ai-agents"
echo "  • From databricks/ai-dev-kit: databricks-asset-bundles, databricks-model-serving"
echo "    + databricks-vector-search, databricks-mlflow-evaluation"
echo "  • From langchain-ai/langchain-skills: langgraph-fundamentals, langgraph-persistence,"
echo "    langchain-fundamentals, framework-selection"
echo ""
echo "Install locations:"
for tool in "${!SKILL_DIRS[@]}"; do
  echo "  • $tool → ${SKILL_DIRS[$tool]}"
done
echo ""

if ! $AUTO_YES; then
  read -rp "Continue? [Y/n] " confirm
  [[ "$confirm" =~ ^[Nn]$ ]] && { info "Aborted."; exit 0; }
fi

# ── Helpers ──────────────────────────────────────────────────────────────────
install_local_skill() {
  local skill_name="$1"
  local skill_src="$SCRIPT_DIR/skills/$skill_name"

  if [ ! -d "$skill_src" ]; then
    warn "Local skill not found: $skill_name — skipping"
    return
  fi

  for tool in "${!SKILL_DIRS[@]}"; do
    local dest="${SKILL_DIRS[$tool]}/$skill_name"
    mkdir -p "$dest"
    cp -r "$skill_src/." "$dest/"
    success "[$tool] Installed: $skill_name"
  done
}

install_remote_skill() {
  local skill_name="$1"
  local raw_base_url="$2"    # raw.githubusercontent.com base URL for skill folder
  local files=("${@:3}")     # list of files to download (relative to skill folder)

  for tool in "${!SKILL_DIRS[@]}"; do
    local dest="${SKILL_DIRS[$tool]}/$skill_name"
    mkdir -p "$dest"

    for file in "${files[@]}"; do
      local dir
      dir="$(dirname "$file")"
      [ "$dir" != "." ] && mkdir -p "$dest/$dir"

      local url="$raw_base_url/$file"
      if curl -fsSL "$url" -o "$dest/$file" 2>/dev/null; then
        :
      else
        warn "  Could not download: $url"
      fi
    done
    success "[$tool] Installed: $skill_name"
  done
}

# ── Install our skills ───────────────────────────────────────────────────────
echo ""
info "Installing our skills..."
install_local_skill "azure-ai-foundry-agents"
install_local_skill "databricks-mosaic-ai-agents"

# ── Install from databricks-solutions/ai-dev-kit ─────────────────────────────
echo ""
info "Installing dependencies from databricks-solutions/ai-dev-kit..."

DBRX_RAW="https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/databricks-skills"

install_remote_skill "databricks-asset-bundles" \
  "$DBRX_RAW/databricks-asset-bundles" \
  "SKILL.md"

install_remote_skill "databricks-model-serving" \
  "$DBRX_RAW/databricks-model-serving" \
  "SKILL.md"

install_remote_skill "databricks-vector-search" \
  "$DBRX_RAW/databricks-vector-search" \
  "SKILL.md"

install_remote_skill "databricks-mlflow-evaluation" \
  "$DBRX_RAW/databricks-mlflow-evaluation" \
  "SKILL.md"

# ── Install from langchain-ai/langchain-skills ───────────────────────────────
echo ""
info "Installing dependencies from langchain-ai/langchain-skills..."

LC_RAW="https://raw.githubusercontent.com/langchain-ai/langchain-skills/main/config/skills"

install_remote_skill "langgraph-fundamentals" \
  "$LC_RAW/langgraph-fundamentals" \
  "SKILL.md"

install_remote_skill "langgraph-persistence" \
  "$LC_RAW/langgraph-persistence" \
  "SKILL.md"

install_remote_skill "langchain-fundamentals" \
  "$LC_RAW/langchain-fundamentals" \
  "SKILL.md"

install_remote_skill "framework-selection" \
  "$LC_RAW/framework-selection" \
  "SKILL.md"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation complete!             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed skills:"
for tool in "${!SKILL_DIRS[@]}"; do
  echo ""
  echo "  $tool → ${SKILL_DIRS[$tool]}"
  ls "${SKILL_DIRS[$tool]}" 2>/dev/null | sed 's/^/    • /'
done
echo ""
echo "Next steps:"
if [[ "${SKILL_DIRS[*]}" == *".claude"* ]]; then
  echo "  • Claude Code: skills are ready — start a new session in your project"
fi
if [[ "${SKILL_DIRS[*]}" == *".cursor"* ]]; then
  echo "  • Cursor: restart Cursor and check Settings > Rules"
fi
if [[ "${SKILL_DIRS[*]}" == *".github"* ]]; then
  echo "  • GitHub Copilot: skills available in Copilot Chat via @workspace"
fi
echo ""
