#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  Aurora Music Widget v4 — Update Script
#  Linux · macOS · FreeBSD
#  For Windows: use update.ps1
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
G='\033[1;32m';Y='\033[1;33m';R='\033[0;31m';B='\033[1;34m';N='\033[0m'
inf(){ echo -e "${G}[aurora]${N} $*"; }
wrn(){ echo -e "${Y}[aurora]${N} $*"; }
stp(){ echo -e "\n${B}━━━ $* ${N}"; }
ok() { echo -e "    ${G}✓${N} $*"; }

INSTALL_DIR="${HOME}/.local/share/aurora-widget"
BIN="${HOME}/.local/bin/aurora-widget"
PLAT="$(uname -s)"

echo -e "\n${B}Aurora Music Widget v4 — Updater${N}\n"

# ── 1. System packages ─────────────────────────────────────────
stp "Updating system packages"
case "$PLAT" in
  Linux)
    DISTRO_ID="unknown"; DISTRO_LIKE=""
    [ -f /etc/os-release ] && { . /etc/os-release; DISTRO_ID="${ID:-unknown}"; DISTRO_LIKE="${ID_LIKE:-}"; }
    is_like(){ [[ "$DISTRO_ID" == "$1" || "$DISTRO_LIKE" == *"$1"* ]]; }
    if   is_like "debian" || [ -f /etc/debian_version ]; then
      sudo apt-get install -y --no-install-recommends python3-dbus libdbus-1-dev 2>/dev/null || true
    elif is_like "fedora" || is_like "rhel"; then
      sudo dnf install -y python3-dbus dbus-devel 2>/dev/null || true
    elif is_like "arch"; then
      sudo pacman -Sy --noconfirm python-dbus 2>/dev/null || true
    elif is_like "suse" || is_like "opensuse"; then
      sudo zypper --non-interactive install python3-dbus-python 2>/dev/null || true
    fi; ok "Linux system packages"
    ;;
  Darwin)
    command -v brew &>/dev/null && brew upgrade python3 2>/dev/null || true; ok "macOS";;
  FreeBSD)
    sudo pkg upgrade -y 2>/dev/null || true; ok "FreeBSD";;
  *) wrn "Unknown OS: ${PLAT}";;
esac

# ── 2. Python packages ─────────────────────────────────────────
stp "Updating Python packages"
PKGS="PyQt6 Pillow colorthief"
[ "$PLAT" = "Darwin" ] && PKGS="$PKGS pyobjc-framework-Cocoa pyobjc-framework-ScriptingBridge"

if   pip3 install --upgrade $PKGS --user --quiet 2>/dev/null; then
  ok "pip --user upgrade"
elif pip3 install --upgrade $PKGS --user --break-system-packages --quiet 2>/dev/null; then
  ok "pip --break-system-packages upgrade"
elif [ -x "${INSTALL_DIR}/venv/bin/pip" ]; then
  "${INSTALL_DIR}/venv/bin/pip" install --upgrade $PKGS --quiet; ok "venv upgrade"
else
  wrn "Could not upgrade pip packages — try manually: pip3 install --upgrade $PKGS --user"
fi

# ── 3. Update widget script from source ────────────────────────
stp "Updating widget script"
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_SRC="${SDIR}/musicwidget.py"
WIDGET_DST="${INSTALL_DIR}/musicwidget.py"

if [ -f "$WIDGET_SRC" ] && [ "$WIDGET_SRC" != "$WIDGET_DST" ]; then
  if python3 -c "import ast; ast.parse(open('${WIDGET_SRC}').read())" 2>/dev/null; then
    cp "$WIDGET_SRC" "$WIDGET_DST"; ok "Widget updated from source"
  else
    wrn "Source widget failed syntax check — keeping installed version"
  fi
elif [ ! -f "$WIDGET_DST" ]; then
  wrn "Widget not installed. Run install.sh first."
else
  ok "Widget script up-to-date"
fi

# ── 4. Rebuild launcher ────────────────────────────────────────
stp "Rebuilding launcher"
PBIN="python3"
[ -x "${INSTALL_DIR}/venv/bin/python3" ] && PBIN="${INSTALL_DIR}/venv/bin/python3"
mkdir -p "${HOME}/.local/bin"
cat > "$BIN" <<LAUNCHER
#!/usr/bin/env bash
exec ${PBIN} "${INSTALL_DIR}/musicwidget.py" "\$@"
LAUNCHER
chmod +x "$BIN"; ok "Launcher rebuilt: $BIN"

# ── 5. Verify ─────────────────────────────────────────────────
stp "Verifying"
python3 -c "from PyQt6.QtWidgets import QApplication" 2>/dev/null && ok "PyQt6" || wrn "PyQt6 missing"
python3 -c "import ast; ast.parse(open('${INSTALL_DIR}/musicwidget.py').read())" 2>/dev/null && ok "Syntax OK" || wrn "Syntax check failed"

echo -e "\n${G}  ✓  Update complete! Run: aurora-widget${N}\n"
