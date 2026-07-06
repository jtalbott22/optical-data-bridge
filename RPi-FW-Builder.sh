#!/usr/bin/env bash
###############################################################################
# build-kiosk-image.sh
#
# Builds a custom Raspberry Pi OS image that boots straight into Chromium
# (kiosk mode) displaying a single local HTML file, with KMS display drivers
# and the libcamera/V4L2 camera stack baked in.
#
# Targets: Raspberry Pi 3 / 4 / 5 / Zero 2 W (arm64)
# Build host: Debian/Ubuntu x86_64 or a Raspberry Pi (needs ~15GB free disk)
#
# Usage:
#   ./build-kiosk-image.sh /path/to/your/app.html
#
# Output:
#   ./pi-gen/deploy/*.img.xz  -> flash with Raspberry Pi Imager or dd
###############################################################################
set -euo pipefail

APP_FILE="${1:?Usage: $0 /path/to/app.html}"
IMG_NAME="kiosk-pi"
HOSTNAME="kioskpi"
KIOSK_USER="kiosk"
KIOSK_PASS="kiosk"          # change me
WORKDIR="$(pwd)/pi-gen"

[[ -f "$APP_FILE" ]] || { echo "App file not found: $APP_FILE"; exit 1; }

# --- Build host dependencies -------------------------------------------------
sudo apt-get update
sudo apt-get install -y coreutils quilt parted qemu-user-static debootstrap \
  zerofree zip dosfstools libarchive-tools libcap2-bin grep rsync xz-utils \
  file git curl bc gpg pigz arch-test

# --- Fetch pi-gen (official Raspberry Pi OS image builder) -------------------
if [[ ! -d "$WORKDIR" ]]; then
  git clone --depth 1 --branch arm64 https://github.com/RPi-Distro/pi-gen.git "$WORKDIR"
fi
cd "$WORKDIR"

# --- Top-level pi-gen config -------------------------------------------------
cat > config <<EOF
IMG_NAME="${IMG_NAME}"
RELEASE=bookworm
ARMHF_ARCH=arm64
TARGET_HOSTNAME=${HOSTNAME}
FIRST_USER_NAME=${KIOSK_USER}
FIRST_USER_PASS=${KIOSK_PASS}
DISABLE_FIRST_BOOT_USER_RENAME=1
ENABLE_SSH=1
LOCALE_DEFAULT=en_US.UTF-8
KEYBOARD_KEYMAP=us
KEYBOARD_LAYOUT="English (US)"
TIMEZONE_DEFAULT=America/New_York
STAGE_LIST="stage0 stage1 stage2 stage-kiosk"
DEPLOY_COMPRESSION=xz
EOF

# --- Custom stage: stage-kiosk ------------------------------------------------
STAGE="stage-kiosk/00-kiosk"
mkdir -p "${STAGE}/files"

# Skip building lite/full images of intermediate stages
touch stage-kiosk/EXPORT_IMAGE
cp stage2/EXPORT_IMAGE stage-kiosk/EXPORT_IMAGE 2>/dev/null || true

# Packages: Chromium, cage (minimal Wayland kiosk compositor),
# camera stack (libcamera + v4l2), GPU/KMS userspace (Mesa)
cat > "${STAGE}/00-packages" <<'EOF'
chromium-browser
cage
seatd
libcamera-apps
libcamera0.3
v4l-utils
mesa-vulkan-drivers
libgl1-mesa-dri
fonts-dejavu
EOF

# Copy the app into the stage so it lands in the image
cp "$APP_FILE" "${STAGE}/files/app.html"

# In-chroot setup script
cat > "${STAGE}/01-run-chroot.sh" <<'CHROOT'
#!/bin/bash -e

# --- App payload ---
install -d -m 755 /opt/kiosk
install -m 644 /tmp/stage-files/app.html /opt/kiosk/app.html

# --- Firmware config: KMS display driver + camera autodetect ---
CONFIG=/boot/firmware/config.txt
grep -q "^dtoverlay=vc4-kms-v3d" $CONFIG || cat >> $CONFIG <<'EOT'

# --- Kiosk image additions ---
dtoverlay=vc4-kms-v3d
max_framebuffers=2
camera_auto_detect=1
display_auto_detect=1
disable_splash=1
EOT

# Quiet boot
sed -i 's/$/ quiet loglevel=3 logo.nologo vt.global_cursor_default=0/' /boot/firmware/cmdline.txt

# --- Permissions: camera + GPU + input ---
usermod -aG video,render,input kiosk
systemctl enable seatd

# --- Kiosk launch script ---
cat > /opt/kiosk/start-kiosk.sh <<'EOT'
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
exec cage -- chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --no-first-run \
  --ozone-platform=wayland \
  --enable-features=UseOzonePlatform \
  --allow-file-access-from-files \
  --use-fake-ui-for-media-stream \
  --autoplay-policy=no-user-gesture-required \
  --check-for-update-interval=31536000 \
  file:///opt/kiosk/app.html
EOT
chmod +x /opt/kiosk/start-kiosk.sh

# --- systemd service: launch on boot, restart on crash ---
cat > /etc/systemd/system/kiosk.service <<'EOT'
[Unit]
Description=Chromium Kiosk
After=systemd-user-sessions.service seatd.service
Wants=seatd.service

[Service]
User=kiosk
Group=kiosk
PAMName=login
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
ExecStart=/opt/kiosk/start-kiosk.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOT

systemctl enable kiosk.service
systemctl set-default multi-user.target
CHROOT
chmod +x "${STAGE}/01-run-chroot.sh"

# Hook to copy stage files into chroot /tmp before the chroot script runs
cat > "${STAGE}/01-run.sh" <<'EOF'
#!/bin/bash -e
install -d "${ROOTFS_DIR}/tmp/stage-files"
install -m 644 files/app.html "${ROOTFS_DIR}/tmp/stage-files/app.html"
EOF
chmod +x "${STAGE}/01-run.sh"

# Prereq marker so pi-gen runs the stage
touch stage-kiosk/prerun.sh
cat > stage-kiosk/prerun.sh <<'EOF'
#!/bin/bash -e
if [ ! -d "${ROOTFS_DIR}" ]; then
  copy_previous
fi
EOF
chmod +x stage-kiosk/prerun.sh

# --- Build --------------------------------------------------------------------
echo ">>> Starting image build (this takes 30-90 min)..."
sudo ./build.sh

echo ">>> Done. Flashable image is in: ${WORKDIR}/deploy/"
