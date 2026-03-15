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
AUTO_YES=true
WITH_MCP=false
SCRIPT_DIR=""  # resolved below after dependency checks

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
command -v git >/dev/null 2>&1 || error "git is required but not installed."

# ── Resolve repo (clone/update if run via pipe, use local if run from clone) ──
REPO_URL="https://github.com/alessandro9110/agent-skills.git"
INSTALL_DIR="$HOME/.agent-skills"

_src_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd || true)"
if [[ -f "${BASH_SOURCE[0]:-}" ]] && [[ -d "$_src_dir/skills" ]]; then
  # Running from a local file with a skills/ directory alongside it
  SCRIPT_DIR="$_src_dir"
else
  # Running via pipe (bash <(curl ...)) — clone or update repo
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Updating agent-skills repo..."
    git -C "$INSTALL_DIR" pull -q
  else
    info "Cloning agent-skills repo to $INSTALL_DIR..."
    git clone -q "$REPO_URL" "$INSTALL_DIR"
  fi
  SCRIPT_DIR="$INSTALL_DIR"
fi

# ── Skill dirs — parallel arrays (bash 3.2 compatible) ───────────────────────
SKILL_DIR_TOOLS=()
SKILL_DIR_PATHS=()

set_skill_dir() {
  local tool="$1" path="$2" i
  for i in "${!SKILL_DIR_TOOLS[@]}"; do
    [[ "${SKILL_DIR_TOOLS[$i]}" == "$tool" ]] && { SKILL_DIR_PATHS[$i]="$path"; return; }
  done
  SKILL_DIR_TOOLS+=("$tool")
  SKILL_DIR_PATHS+=("$path")
}

# ── Resolve target directories ───────────────────────────────────────────────
IFS=',' read -ra TOOL_LIST <<< "$TOOLS"
for tool in "${TOOL_LIST[@]}"; do
  tool=$(echo "$tool" | tr -d ' ')
  if $GLOBAL; then
    case $tool in
      claude)  set_skill_dir "claude"  "$HOME/.claude/skills" ;;
      cursor)  set_skill_dir "cursor"  "$HOME/.cursor/rules" ;;
      copilot) set_skill_dir "copilot" "$HOME/.github/skills" ;;
      *) warn "Unknown tool: $tool (supported: claude, cursor, copilot)" ;;
    esac
  else
    case $tool in
      claude)  set_skill_dir "claude"  "$(pwd)/.claude/skills" ;;
      cursor)  set_skill_dir "cursor"  "$(pwd)/.cursor/rules" ;;
      copilot) set_skill_dir "copilot" "$(pwd)/.github/skills" ;;
      *) warn "Unknown tool: $tool (supported: claude, cursor, copilot)" ;;
    esac
  fi
done

[ ${#SKILL_DIR_TOOLS[@]} -eq 0 ] && error "No valid tools specified."

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
# Output: "name|type|url|command|args|path_var|path_hint|auto_clone|auto_clone_dir|setup_cmds|env_vars"
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
                current['path_hint'] = stripped.split('path_hint:')[1].strip().strip('"')
            elif 'auto_clone:' in stripped:
                current['auto_clone'] = stripped.split('auto_clone:')[1].strip()
            elif 'auto_clone_dir:' in stripped:
                current['auto_clone_dir'] = stripped.split('auto_clone_dir:')[1].strip()
            elif 'setup_cmds:' in stripped:
                current['setup_cmds'] = stripped.split('setup_cmds:')[1].strip().strip('"')
            elif 'env_vars:' in stripped:
                current['env_vars'] = stripped.split('env_vars:')[1].strip().strip('"')
        elif stripped and not stripped.startswith('#') and not re.match(r'^    ', line):
            in_mcp = False

if current:
    servers.append(current)

for s in servers:
    name           = s.get('name', '')
    typ            = s.get('type', 'http')
    url            = s.get('url', '')
    command        = s.get('command', '')
    args           = s.get('args', '')
    path_var       = s.get('path_var', '')
    path_hint      = s.get('path_hint', '')
    auto_clone     = s.get('auto_clone', '')
    auto_clone_dir = s.get('auto_clone_dir', '')
    setup_cmds     = s.get('setup_cmds', '')
    env_vars       = s.get('env_vars', '')
    if name:
        print(f"{name}|{typ}|{url}|{command}|{args}|{path_var}|{path_hint}|{auto_clone}|{auto_clone_dir}|{setup_cmds}|{env_vars}")
EOF
}

# ── Deps and MCPs — parallel arrays (bash 3.2 compatible) ────────────────────
DEP_NAMES=()
DEP_VALUES=()

set_dep() {
  local name="$1" value="$2" i
  for i in "${!DEP_NAMES[@]}"; do
    [[ "${DEP_NAMES[$i]}" == "$name" ]] && { DEP_VALUES[$i]="$value"; return; }
  done
  DEP_NAMES+=("$name")
  DEP_VALUES+=("$value")
}

MCP_NAMES=()
MCP_VALUES=()

set_mcp() {
  local name="$1" value="$2" i
  for i in "${!MCP_NAMES[@]}"; do
    [[ "${MCP_NAMES[$i]}" == "$name" ]] && { MCP_VALUES[$i]="$value"; return; }
  done
  MCP_NAMES+=("$name")
  MCP_VALUES+=("$value")
}

# ── Collect all skills, dependencies, and MCP servers ────────────────────────
info "Scanning skills for dependencies and MCP servers..."

for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || continue

  while IFS='|' read -r dep_name raw_base files; do
    [ -z "$dep_name" ] && continue
    set_dep "$dep_name" "$raw_base|$files"
    info "  Found dependency: $dep_name (from $skill_name)"
  done < <(parse_dependencies "$skill_md")

  while IFS='|' read -r mcp_name mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint mcp_auto_clone mcp_auto_clone_dir mcp_setup_cmds mcp_env_vars; do
    [ -z "$mcp_name" ] && continue
    set_mcp "$mcp_name" "$mcp_type|$mcp_url|$mcp_command|$mcp_args|$mcp_path_var|$mcp_path_hint|$mcp_auto_clone|$mcp_auto_clone_dir|$mcp_setup_cmds|$mcp_env_vars"
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

if [ ${#DEP_NAMES[@]} -gt 0 ]; then
  echo ""
  echo "External dependencies (${#DEP_NAMES[@]}):"
  for dep in "${DEP_NAMES[@]}"; do echo "  • $dep"; done
fi

if [ ${#MCP_NAMES[@]} -gt 0 ]; then
  echo ""
  echo "MCP servers available (${#MCP_NAMES[@]}):"
  for i in "${!MCP_NAMES[@]}"; do
    mcp="${MCP_NAMES[$i]}"
    IFS='|' read -r mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint mcp_auto_clone mcp_auto_clone_dir mcp_setup_cmds mcp_env_vars <<< "${MCP_VALUES[$i]}"
    if [[ "$mcp_type" == "http" ]]; then
      echo "  • $mcp  (http → $mcp_url)"
    else
      echo "  • $mcp  (stdio: $mcp_command)"
      [ -n "$mcp_auto_clone" ] && echo "    auto-clone: $mcp_auto_clone → ${mcp_auto_clone_dir/#\~/$HOME}"
      [ -z "$mcp_auto_clone" ] && [ -n "$mcp_path_hint" ] && echo "    requires: $mcp_path_hint"
      [ -n "$mcp_env_vars" ] && echo "    env: $(echo "$mcp_env_vars" | tr ',' '\n' | sed 's/:.*$//' | paste -sd ',' -)"
    fi
  done
fi

echo ""
echo "Install locations:"
for i in "${!SKILL_DIR_TOOLS[@]}"; do
  echo "  • ${SKILL_DIR_TOOLS[$i]} → ${SKILL_DIR_PATHS[$i]}"
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
  for i in "${!SKILL_DIR_TOOLS[@]}"; do
    local tool="${SKILL_DIR_TOOLS[$i]}"
    local dest="${SKILL_DIR_PATHS[$i]}/$skill_name"
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
  for i in "${!SKILL_DIR_TOOLS[@]}"; do
    local tool="${SKILL_DIR_TOOLS[$i]}"
    local dest="${SKILL_DIR_PATHS[$i]}/$skill_name"
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
configure_mcp_server() {
  local mcp_name="$1"
  local mcp_type="$2"
  local mcp_url="$3"
  local mcp_command="$4"
  local mcp_args="$5"
  local config_file="$6"
  local config_key="$7"
  local mcp_env_json="${8:-}"   # optional JSON object string, e.g. '{"KEY":"val"}'

  python3 - "$config_file" "$config_key" "$mcp_name" "$mcp_type" "$mcp_url" "$mcp_command" "$mcp_args" "$mcp_env_json" <<'EOF'
import sys, json, os, shlex

config_file, config_key, mcp_name, mcp_type, mcp_url, mcp_command, mcp_args, mcp_env_json = sys.argv[1:]

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
    entry = {
        "command": mcp_command,
        "args": args_list,
        "defer_loading": True
    }
    if mcp_env_json:
        try:
            env_dict = json.loads(mcp_env_json)
            if env_dict:
                entry["env"] = env_dict
        except:
            pass
    config[config_key][mcp_name] = entry

os.makedirs(os.path.dirname(os.path.abspath(config_file)), exist_ok=True)
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
EOF
}

install_mcps() {
  echo ""
  info "Configuring MCP servers..."

  # Check if uv is needed and available
  local needs_uv=false
  for i in "${!MCP_NAMES[@]}"; do
    local _type _url _cmd _args _pvar _phint
    IFS='|' read -r _type _url _cmd _args _pvar _phint <<< "${MCP_VALUES[$i]}"
    [[ "$_type" == "stdio" && "$_cmd" == "uv" ]] && needs_uv=true && break
  done
  if $needs_uv && ! command -v uv >/dev/null 2>&1; then
    warn "uv is required for one or more MCP servers but is not installed."
    warn "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    warn "Skipping MCP configuration."
    return
  fi

  for i in "${!MCP_NAMES[@]}"; do
    local mcp_name="${MCP_NAMES[$i]}"
    IFS='|' read -r mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint mcp_auto_clone mcp_auto_clone_dir mcp_setup_cmds mcp_env_vars <<< "${MCP_VALUES[$i]}"

    # For stdio MCPs with a required path: resolve it (auto-clone or prompt)
    if [[ "$mcp_type" == "stdio" ]] && [[ -n "$mcp_path_var" ]]; then
      local actual_path=""

      if [[ -n "$mcp_auto_clone" ]]; then
        local default_dir="${mcp_auto_clone_dir/#\~/$HOME}"

        echo ""
        echo "  MCP '$mcp_name' requires the repository: $mcp_auto_clone"
        read -rp "  $mcp_path_hint [$default_dir]: " actual_path
        [[ -z "$actual_path" ]] && actual_path="$default_dir"

        # Clone if not already present
        if [[ ! -d "$actual_path/.git" ]]; then
          info "  Cloning $mcp_auto_clone → $actual_path ..."
          git clone -q "$mcp_auto_clone" "$actual_path" || { warn "  Clone failed — skipping $mcp_name"; continue; }
          success "  Cloned to $actual_path"
        else
          info "  Using existing clone at $actual_path"
        fi

        # Run setup commands (install packages)
        if [[ -n "$mcp_setup_cmds" ]]; then
          info "  Running setup: $mcp_setup_cmds"
          (cd "$actual_path" && eval "$mcp_setup_cmds") || warn "  Setup commands failed — MCP may not work correctly"
        fi

      else
        # No auto-clone: prompt for path manually
        echo ""
        echo "  MCP '$mcp_name' requires a local path."
        read -rp "  $mcp_path_hint: " actual_path
        if [[ -z "$actual_path" ]]; then
          warn "  No path provided — skipping $mcp_name"
          continue
        fi
      fi

      mcp_args="${mcp_args//$mcp_path_var/$actual_path}"
    fi

    # Collect environment variables (prompt for each KEY:hint pair)
    local env_json="{}"
    if [[ -n "$mcp_env_vars" ]]; then
      echo ""
      echo "  MCP '$mcp_name' requires Databricks credentials."
      echo "  (Leave blank to rely on ~/.databrickscfg or existing env vars)"
      local env_pairs=()
      IFS=',' read -ra env_items <<< "$mcp_env_vars"
      for env_item in "${env_items[@]}"; do
        local env_key="${env_item%%:*}"
        local env_hint="${env_item#*:}"
        local env_val=""
        read -rp "  $env_key ($env_hint): " env_val
        [[ -n "$env_val" ]] && env_pairs+=("\"$env_key\":\"$env_val\"")
      done
      if [[ ${#env_pairs[@]} -gt 0 ]]; then
        env_json="{$(IFS=','; echo "${env_pairs[*]}")}"
      fi
    fi

    for j in "${!SKILL_DIR_TOOLS[@]}"; do
      local tool="${SKILL_DIR_TOOLS[$j]}"
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
      configure_mcp_server "$mcp_name" "$mcp_type" "$mcp_url" "$mcp_command" "$mcp_args" "$config_file" "$config_key" "$env_json"
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
if [ ${#DEP_NAMES[@]} -gt 0 ]; then
  echo ""
  info "Installing external dependencies..."
  for i in "${!DEP_NAMES[@]}"; do
    dep_name="${DEP_NAMES[$i]}"
    IFS='|' read -r raw_base files <<< "${DEP_VALUES[$i]}"
    install_remote_skill "$dep_name" "$raw_base" "$files"
  done
fi

# ── Configure MCP servers (optional) ─────────────────────────────────────────
if [ ${#MCP_NAMES[@]} -gt 0 ]; then
  if $WITH_MCP; then
    install_mcps
  elif ! $AUTO_YES; then
    echo ""
    echo "MCP servers found (${#MCP_NAMES[@]}):"
    for i in "${!MCP_NAMES[@]}"; do
      mcp="${MCP_NAMES[$i]}"
      IFS='|' read -r mcp_type mcp_url mcp_command mcp_args mcp_path_var mcp_path_hint mcp_auto_clone mcp_auto_clone_dir mcp_setup_cmds mcp_env_vars <<< "${MCP_VALUES[$i]}"
      if [[ "$mcp_type" == "http" ]]; then
        echo "  • $mcp  (http → $mcp_url)"
      else
        echo "  • $mcp  (stdio: $mcp_command)"
        [ -n "$mcp_auto_clone" ] && echo "    auto-clone: $mcp_auto_clone → ${mcp_auto_clone_dir/#\~/$HOME}"
        [ -z "$mcp_auto_clone" ] && [ -n "$mcp_path_hint" ] && echo "    requires: $mcp_path_hint"
        [ -n "$mcp_env_vars" ] && echo "    env: $(echo "$mcp_env_vars" | tr ',' '\n' | sed 's/:.*$//' | paste -sd ',' -)"
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
      echo "To configure manually, re-run: bash install.sh --with-mcp"
    fi
  else
    # AUTO_YES=true, WITH_MCP=false: show notice so user knows MCPs were skipped
    echo ""
    warn "MCP servers declared but not configured (${#MCP_NAMES[@]} found)."
    warn "Re-run with --with-mcp to install and configure them:"
    warn "  bash install.sh --with-mcp"
  fi
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation complete!             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed skills:"
for i in "${!SKILL_DIR_TOOLS[@]}"; do
  tool="${SKILL_DIR_TOOLS[$i]}"
  path="${SKILL_DIR_PATHS[$i]}"
  echo ""
  echo "  $tool → $path"
  ls "$path" 2>/dev/null | sed 's/^/    • /' || true
done
echo ""
echo "Next steps:"
for i in "${!SKILL_DIR_TOOLS[@]}"; do
  case "${SKILL_DIR_TOOLS[$i]}" in
    claude)  echo "  • Claude Code: start a new session — skills load automatically" ;;
    cursor)  echo "  • Cursor: restart Cursor and check Settings > Rules" ;;
    copilot) echo "  • GitHub Copilot: skills available in Copilot Chat" ;;
  esac
done
echo ""
