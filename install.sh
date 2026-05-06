#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  Aurora Music Widget v4 — Installer
#  Linux · FreeBSD · macOS · (Windows: use install.ps1)
#  Distros: Debian/Ubuntu · Fedora/RHEL · Arch · openSUSE · Gentoo
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
G='\033[1;32m';Y='\033[1;33m';R='\033[0;31m';B='\033[1;34m';C='\033[0;36m';N='\033[0m'
inf(){ echo -e "${G}[aurora]${N} $*"; }
wrn(){ echo -e "${Y}[aurora]${N} $*"; }
err(){ echo -e "${R}[aurora]${N} $*"; exit 1; }
stp(){ echo -e "\n${B}━━━ $* ${N}"; }
ok() { echo -e "    ${G}✓${N} $*"; }

INSTALL_DIR="${HOME}/.local/share/aurora-widget"
BIN_DIR="${HOME}/.local/bin"
DESK="${HOME}/.local/share/applications"
AUTO="${HOME}/.config/autostart"
USE_VENV=0

echo -e "\n${C}  ╔═════════════════════════════════════════╗"
echo    "  ║     🎵  Aurora Music Widget v4           ║"
echo    "  ║  Resizable · Glowing · Cross-platform    ║"
echo -e "  ╚═════════════════════════════════════════╝${N}\n"

# ── Detect OS ──────────────────────────────────────────────────
PLAT="$(uname -s)"
stp "Detecting platform: ${PLAT}"

# ── Detect Linux distro ────────────────────────────────────────
DISTRO_ID="unknown"; DISTRO_LIKE=""
[ -f /etc/os-release ] && { . /etc/os-release; DISTRO_ID="${ID:-unknown}"; DISTRO_LIKE="${ID_LIKE:-}"; }
is_like(){ [[ "$DISTRO_ID" == "$1" || "$DISTRO_LIKE" == *"$1"* ]]; }

# ── Install system packages ────────────────────────────────────
stp "Installing system packages"
case "$PLAT" in
  Linux)
    if   is_like "debian" || [ -f /etc/debian_version ]; then
      sudo apt-get update -qq
      sudo apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv python3-dbus \
        libdbus-1-dev libxcb-cursor0 libxcb-xinerama0 2>/dev/null || true
      ok "apt"
    elif is_like "fedora" || is_like "rhel" || is_like "centos"; then
      sudo dnf install -y python3 python3-pip python3-dbus \
        dbus-devel xcb-util-cursor qt6-qtbase 2>/dev/null || true
      ok "dnf"
    elif is_like "arch"; then
      sudo pacman -Sy --noconfirm python python-pip python-dbus \
        python-pyqt6 xcb-util-cursor 2>/dev/null || true
      ok "pacman"
    elif is_like "suse" || is_like "opensuse"; then
      sudo zypper --non-interactive install python3 python3-pip \
        python3-dbus-python dbus-1-devel python3-PyQt6 2>/dev/null || true
      ok "zypper"
    elif [ -f /etc/gentoo-release ]; then
      wrn "Gentoo: run 'emerge dev-python/dbus-python dev-python/PyQt6 dev-python/pillow' if needed"
    else
      wrn "Unknown Linux — skipping system packages"
    fi
    ;;
  Darwin)
    if command -v brew &>/dev/null; then
      brew install python3 2>/dev/null || true
      ok "homebrew python3"
    else
      wrn "Homebrew not found. Install from https://brew.sh then rerun."
    fi
    ;;
  FreeBSD)
    sudo pkg install -y python3 py39-pip py39-dbus-python 2>/dev/null || \
    sudo pkg install -y python311 py311-pip py311-dbus-python 2>/dev/null || true
    ok "pkg"
    ;;
  *) wrn "Unknown OS: ${PLAT}" ;;
esac

# ── Python packages ────────────────────────────────────────────
stp "Installing Python packages"
PKGS="PyQt6 Pillow colorthief"
[ "$PLAT" = "Darwin" ] && PKGS="$PKGS pyobjc-framework-Cocoa pyobjc-framework-ScriptingBridge"

if   pip3 install $PKGS --user --quiet 2>/dev/null; then
  ok "pip --user"
elif pip3 install $PKGS --user --break-system-packages --quiet 2>/dev/null; then
  ok "pip --break-system-packages"
elif python3 -c "from PyQt6.QtWidgets import QApplication" 2>/dev/null; then
  ok "PyQt6 already available"
  pip3 install Pillow colorthief --user --quiet 2>/dev/null || true
else
  python3 -m venv "${INSTALL_DIR}/venv"
  "${INSTALL_DIR}/venv/bin/pip" install $PKGS --quiet
  USE_VENV=1; ok "venv"
fi

# ── Copy files ─────────────────────────────────────────────────
stp "Installing files"
mkdir -p "${INSTALL_DIR}" "${BIN_DIR}" "${DESK}"
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in musicwidget.py update.sh; do
  [ -f "${SDIR}/${f}" ] && cp "${SDIR}/${f}" "${INSTALL_DIR}/${f}" && ok "Copied ${f}"
done
chmod +x "${INSTALL_DIR}/update.sh" 2>/dev/null || true

# ── Launchers ──────────────────────────────────────────────────
stp "Creating launchers"
PBIN="python3"; [ "$USE_VENV" = "1" ] && PBIN="${INSTALL_DIR}/venv/bin/python3"
cat > "${BIN_DIR}/aurora-widget" <<LAUNCHER
#!/usr/bin/env bash
exec ${PBIN} "${INSTALL_DIR}/musicwidget.py" "\$@"
LAUNCHER
cat > "${BIN_DIR}/aurora-update" <<UPDATER
#!/usr/bin/env bash
exec bash "${INSTALL_DIR}/update.sh" "\$@"
UPDATER
chmod +x "${BIN_DIR}/aurora-widget" "${BIN_DIR}/aurora-update"
ok "aurora-widget  aurora-update"

# ── Desktop entry (Linux only) ─────────────────────────────────
if [ "$PLAT" = "Linux" ]; then
  cat > "${DESK}/aurora-widget.desktop" <<DESKTOP
[Desktop Entry]
Name=Aurora Music Widget
Comment=Resizable floating MPRIS music widget
Exec=${BIN_DIR}/aurora-widget
Icon=multimedia-player
Type=Application
Categories=AudioVideo;Audio;Utility;
Keywords=music;mpris;spotify;vlc;widget;
StartupNotify=false
DESKTOP
  ok "Desktop entry"
  read -r -p "$(echo -e "${Y}[aurora]${N} Autostart on login? [y/N] ")" yn || yn="n"
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    mkdir -p "${AUTO}"; cp "${DESK}/aurora-widget.desktop" "${AUTO}/"
    ok "Autostart enabled"
  fi
fi

# ── macOS: launchd plist ───────────────────────────────────────
if [ "$PLAT" = "Darwin" ]; then
  PLIST="${HOME}/Library/LaunchAgents/com.aurora-widget.plist"
  read -r -p "$(echo -e "${Y}[aurora]${N} Launch on login (launchd)? [y/N] ")" yn || yn="n"
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.aurora-widget</string>
  <key>ProgramArguments</key><array>
    <string>${BIN_DIR}/aurora-widget</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
</dict></plist>
PLIST
    launchctl load "$PLIST" 2>/dev/null || true
    ok "launchd plist installed"
  fi
fi

# ── Verify ─────────────────────────────────────────────────────
stp "Verifying"
python3 -c "from PyQt6.QtWidgets import QApplication" 2>/dev/null && ok "PyQt6" || wrn "PyQt6 missing"
python3 -c "import dbus" 2>/dev/null && ok "dbus-python" || wrn "dbus-python missing (Linux/BSD only)"
python3 -c "from colorthief import ColorThief" 2>/dev/null && ok "colorthief" || wrn "colorthief missing"

echo ""
echo -e "${G}  ✓  Done! Run: aurora-widget${N}"
echo    "  Right-click → Settings  |  Drag edges/corners to resize"
echo    "  Space=Play/Pause  ←/→=Prev/Next  Esc=Quit"
