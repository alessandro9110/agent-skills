#!/usr/bin/env bash
# Agent Skills Installer
# Installs our skills + all external dependencies declared in each SKILL.md frontmatter.
# Optionally configures MCP servers (http and stdio) declared in each SKILL.md.
# Usage: bash install.sh [--global] [--tools claude,cursor,copilot] [--yes] [--with-mcp]

set -e

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Defaults ─────────────────────────────────────────────────────────────────
GLOBAL=false
TOOLS="claude"
AUTO_YES=false
WITH_MCP=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --global|-g)   GLOBAL=true; shift ;;
    --tools|-t)    TOOLS="$2"; shift 2 ;;
    --yes|-y)      AUTO_YES=true; shift ;;
    --with-mcp)    WITH_MCP=true; shift ;;
    --help|-h)
      echo "Usage: bash install.sh [--global] [--tools claude,cursor,copilot] [--yes] [--with-mcp]"
      echo ""
      echo "Options:"
      echo "  --global, -g         Install globally (~/.claude/skills, ~/.cursor/rules, etc.)"
      echo "  --tools, -t TOOLS    Comma-separated: claude,cursor,copilot (default: claude)"
      echo "  --yes, -y            Skip confirmation prompts"
      echo "  --with-mcp           Configure MCP servers without prompting"
      exit 0 ;;
    *) warn "Unknown option: $1"; shift ;;
  esac
done

# ── Check dependencies ───────────────────────────────────────────────────────
command -v curl >/dev/null 2>&1 || error "curl is required but not installed."
command -v python3 >/dev/null 2>&1 || error "python3 is required but not installed."

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

[ ${#SKILL_DIRS[@]} -eq 0 ] && error "No valid tools specified."

# ── Parse dependencies from SKILL.md frontmatter ─────────────────────────────
# Output: "name|raw_base|files"
parse_dependencies() {
  local skill_md="$1"
  python3 - "$skill_md" <<'EOF'
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not match:
    sys.exit(0)

yaml_block = match.group(1)

in_deps = False
deps = []
current = {}

for line in yaml_block.split('\n'):
    stripped = line.strip()

    if stripped == 'dependencies:':
        in_deps = True
        continue

    if in_deps:
        if re.match(r'^    - name:', line):
            if current:
                deps.append(current)
            current = {}
            current['name'] = stripped.split('name:')[1].strip()
        elif re.match(r'^      name:', line):
            current['name'] = stripped.split('name:')[1].strip()
        elif 'raw_base:' in line:
            current['raw_base'] = stripped.split('raw_base:')[1].strip()
        elif 'files:' in line:
            files_str = stripped.split('files:')[1].strip().strip('[]')
            current['files'] = [f.strip() for f in files_str.split(',')]
        elif stripped and not stripped.startswith('#') and ':' in stripped:
            key = stripped.split(':')[0].strip()
            if key not in ('name', 'repo', 'raw_base', 'files'):
                in_deps = False

if current:
    deps.append(current)

for dep in deps:
    name = dep.get('name', '')
    raw_base = dep.get('raw_base', '')
    files = ','.join(dep.get('files', ['SKILL.md']))
    if name and raw_base:
        print(f"{name}|{raw_base}|{files}")
EOF
}

# ── Parse MCP servers from SKILL.md frontmatter ──────────────────────────────
# Output: "name|type|url|command|args|path_var|path_hint"
#   http  → name|http|url|||
#   stdio → name|stdio||command|args|PATH_VAR|hint text
parse_mcp_servers() {
  local skill_md="$1"
  python3 - "$skill_md" <<'EOF'
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not match:
    sys.exit(0)

yaml_block = match.group(1)

in_mcp = False
servers = []
current = {}

for line in yaml_block.split('\n'):
    stripped = line.strip()

    if stripped == 'mcp_servers:':
        in_mcp = True
        continue

    if in_mcp:
        if re.match(r'^    - name:', line):
            if current:
                servers.append(current)
            current = {}
            current['name'] = stripped.split('name:')[1].strip()
        elif re.match(r'^      ', line) and stripped:
            if 'type:' in stripped:
                current['type'] = stripped.split('type:')[1].strip()
            elif 'url:' in stripped:
                current['url'] = stripped.split('url:')[1].strip()
            elif 'command:' in stripped:
                current['command'] = stripped.split('command:')[1].strip()
            elif 'args:' in stripped:
                current['args'] = stripped.split('args:')[1].strip()
            elif 'path_var:' in stripped:
                current['path_var'] = stripped.split('path_var:')[1].strip()
            elif 'path_hint:' in stripped:
                current['path_hint'] = stripped.split('path_hint:')[1].strip()
        elif stripped and not stripped.startswith('#') and not re.match(r'^    ', line):
            in_mcp = False

if current:
    servers.append(current)

for s in servers:
    name     = s.get('name', '')
    typ      = s.get('type', 'http')
    url      = s.get('url', '')
    command  = s.get('command', '')
    args     = s.get('args', '')
    path_var = s.get('path_var', '')
    path_hint = s.get('path_hint', '')
    if name:
        print(f"{name}|{typ}|{url}|{command}|{args}|{path_var}|{path_hint}")
EOF
}

# ── Collect all skills, dependencies, and MCP servers ────────────────────────
declare -A ALL_DEPS   # dep_name  -> "raw_base|files"
declare -A ALL_MCPS   # mcp_name  -> "type|url|command|args|path_var|path_hint"

info "Scanning skills for dependencies and MCP servers..."

for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || continue

  while IFS='|' read -r dep_name raw_base files; do
    [ -z "$dep_name" ] && continue
    ALL_DEPS["$dep_name"]="$raw_base|$files"
    info "  Found dependency: $dep_name (from $skill_name)"
  done < <(parse_dependencies "$skill_md")

  while IFS='|' read -r mcp_name mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint; do
    [ -z "$mcp_name" ] && continue
    ALL_MCPS["$mcp_name"]="$mcp_type|$mcp_url|$mcp_command|$mcp_args|$mcp_path_var|$mcp_path_hint"
    info "  Found MCP server: $mcp_name [$mcp_type] (from $skill_name)"
  done < <(parse_mcp_servers "$skill_md")
done

# ── Summary ──────────────────────────────────────────────────────────────────
OUR_SKILLS=()
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  OUR_SKILLS+=("$(basename "$skill_dir")")
done

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Agent Skills Installer             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Our skills (${#OUR_SKILLS[@]}):"
for s in "${OUR_SKILLS[@]}"; do echo "  • $s"; done

if [ ${#ALL_DEPS[@]} -gt 0 ]; then
  echo ""
  echo "External dependencies (${#ALL_DEPS[@]}):"
  for dep in "${!ALL_DEPS[@]}"; do echo "  • $dep"; done
fi

if [ ${#ALL_MCPS[@]} -gt 0 ]; then
  echo ""
  echo "MCP servers available (${#ALL_MCPS[@]}):"
  for mcp in "${!ALL_MCPS[@]}"; do
    IFS='|' read -r mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint <<< "${ALL_MCPS[$mcp]}"
    if [[ "$mcp_type" == "http" ]]; then
      echo "  • $mcp  (http → $mcp_url)"
    else
      echo "  • $mcp  (stdio: $mcp_command $mcp_args)"
      [ -n "$mcp_path_hint" ] && echo "    requires: $mcp_path_hint"
    fi
  done
fi

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
  [ -d "$skill_src" ] || { warn "Local skill not found: $skill_name — skipping"; return; }
  for tool in "${!SKILL_DIRS[@]}"; do
    local dest="${SKILL_DIRS[$tool]}/$skill_name"
    mkdir -p "$dest"
    cp -r "$skill_src/." "$dest/"
    success "[$tool] Installed: $skill_name"
  done
}

install_remote_skill() {
  local skill_name="$1"
  local raw_base="$2"
  local files_csv="$3"
  IFS=',' read -ra files <<< "$files_csv"
  for tool in "${!SKILL_DIRS[@]}"; do
    local dest="${SKILL_DIRS[$tool]}/$skill_name"
    mkdir -p "$dest"
    for file in "${files[@]}"; do
      file=$(echo "$file" | tr -d ' ')
      local dir; dir="$(dirname "$file")"
      [ "$dir" != "." ] && mkdir -p "$dest/$dir"
      local url="$raw_base/$file"
      if curl -fsSL "$url" -o "$dest/$file" 2>/dev/null; then :
      else warn "  Could not download: $url"; fi
    done
    success "[$tool] Installed: $skill_name"
  done
}

# Writes one MCP server entry into a JSON config file (merges, never overwrites).
# Usage: configure_mcp_server <name> <type> <url> <command> <args> <config_file> <config_key>
configure_mcp_server() {
  local mcp_name="$1"
  local mcp_type="$2"
  local mcp_url="$3"
  local mcp_command="$4"
  local mcp_args="$5"
  local config_file="$6"
  local config_key="$7"

  python3 - "$config_file" "$config_key" "$mcp_name" "$mcp_type" "$mcp_url" "$mcp_command" "$mcp_args" <<'EOF'
import sys, json, os, shlex

config_file, config_key, mcp_name, mcp_type, mcp_url, mcp_command, mcp_args = sys.argv[1:]

if os.path.exists(config_file):
    with open(config_file) as f:
        try:    config = json.load(f)
        except: config = {}
else:
    config = {}

if config_key not in config:
    config[config_key] = {}

if mcp_type == 'http':
    config[config_key][mcp_name] = {"type": "http", "url": mcp_url}
else:  # stdio
    args_list = shlex.split(mcp_args) if mcp_args else []
    config[config_key][mcp_name] = {
        "command": mcp_command,
        "args": args_list,
        "defer_loading": True
    }

os.makedirs(os.path.dirname(os.path.abspath(config_file)), exist_ok=True)
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
EOF
}

install_mcps() {
  echo ""
  info "Configuring MCP servers..."
  for mcp_name in "${!ALL_MCPS[@]}"; do
    IFS='|' read -r mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint <<< "${ALL_MCPS[$mcp_name]}"

    # For stdio MCPs with a required path: ask user once, substitute in args
    if [[ "$mcp_type" == "stdio" ]] && [[ -n "$mcp_path_var" ]]; then
      echo ""
      echo "  MCP '$mcp_name' requires a local path."
      read -rp "  $mcp_path_hint: " actual_path
      if [[ -z "$actual_path" ]]; then
        warn "  No path provided — skipping $mcp_name"
        continue
      fi
      mcp_args="${mcp_args//$mcp_path_var/$actual_path}"
    fi

    for tool in "${!SKILL_DIRS[@]}"; do
      local config_file config_key
      if $GLOBAL; then
        case $tool in
          claude)  config_file="$HOME/.claude/settings.json";  config_key="mcpServers" ;;
          cursor)  config_file="$HOME/.cursor/mcp.json";        config_key="mcpServers" ;;
          copilot) config_file="$HOME/.vscode/mcp.json";        config_key="servers" ;;
        esac
      else
        case $tool in
          claude)  config_file="$(pwd)/.claude/settings.json";  config_key="mcpServers" ;;
          cursor)  config_file="$(pwd)/.cursor/mcp.json";        config_key="mcpServers" ;;
          copilot) config_file="$(pwd)/.vscode/mcp.json";        config_key="servers" ;;
        esac
      fi
      configure_mcp_server "$mcp_name" "$mcp_type" "$mcp_url" "$mcp_command" "$mcp_args" "$config_file" "$config_key"
      success "[$tool] MCP configured: $mcp_name → $config_file"
    done
  done
}

# ── Install our skills ───────────────────────────────────────────────────────
echo ""
info "Installing our skills..."
for skill_name in "${OUR_SKILLS[@]}"; do
  install_local_skill "$skill_name"
done

# ── Install external dependencies ────────────────────────────────────────────
if [ ${#ALL_DEPS[@]} -gt 0 ]; then
  echo ""
  info "Installing external dependencies..."
  for dep_name in "${!ALL_DEPS[@]}"; do
    IFS='|' read -r raw_base files <<< "${ALL_DEPS[$dep_name]}"
    install_remote_skill "$dep_name" "$raw_base" "$files"
  done
fi

# ── Configure MCP servers (optional) ─────────────────────────────────────────
if [ ${#ALL_MCPS[@]} -gt 0 ]; then
  if $WITH_MCP; then
    install_mcps
  elif ! $AUTO_YES; then
    echo ""
    echo "MCP servers found (${#ALL_MCPS[@]}):"
    for mcp in "${!ALL_MCPS[@]}"; do
      IFS='|' read -r mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint <<< "${ALL_MCPS[$mcp]}"
      if [[ "$mcp_type" == "http" ]]; then
        echo "  • $mcp  (http → $mcp_url)"
      else
        echo "  • $mcp  (stdio: $mcp_command)"
        [ -n "$mcp_path_hint" ] && echo "    requires: $mcp_path_hint"
      fi
    done
    echo ""
    echo "Configuring MCP servers lets skills call live APIs and tools"
    echo "when running in VS Code, Cursor, or Claude Code with MCP enabled."
    echo ""
    read -rp "Configure MCP servers? [y/N] " mcp_confirm
    if [[ "$mcp_confirm" =~ ^[Yy]$ ]]; then
      install_mcps
    else
      info "Skipping MCP configuration."
      echo ""
      echo "To configure manually:"
      for mcp in "${!ALL_MCPS[@]}"; do
        IFS='|' read -r mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint <<< "${ALL_MCPS[$mcp]}"
        if [[ "$mcp_type" == "http" ]]; then
          echo "  $mcp: { \"type\": \"http\", \"url\": \"$mcp_url\" }"
        else
          echo "  $mcp: { \"command\": \"$mcp_command\", \"args\": [\"$(echo "$mcp_args" | sed 's/ /", "/g')\"] }"
          [ -n "$mcp_path_hint" ] && echo "    ($mcp_path_hint)"
        fi
      done
    fi
  fi
fi

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
  ls "${SKILL_DIRS[$tool]}" 2>/dev/null | sed 's/^/    • /' || true
done
echo ""
echo "Next steps:"
if [[ "${!SKILL_DIRS[*]}" == *"claude"* ]]; then
  echo "  • Claude Code: start a new session — skills load automatically"
fi
if [[ "${!SKILL_DIRS[*]}" == *"cursor"* ]]; then
  echo "  • Cursor: restart Cursor and check Settings > Rules"
fi
if [[ "${!SKILL_DIRS[*]}" == *"copilot"* ]]; then
  echo "  • GitHub Copilot: skills available in Copilot Chat"
fi
echo ""
