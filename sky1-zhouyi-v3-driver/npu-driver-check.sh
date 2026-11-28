#!/usr/bin/env bash
# npu-driver-check.sh — verify, without root, that the CIX NPU (Zhouyi V3) DKMS driver is healthy on the
# running kernel. Run after every kernel update (and reboot), or with --upstream to see whether the
# Reonarudo fork has moved past the commit this package pins.
#
#   npu-driver-check.sh            health check (exit 0 = healthy, 1 = something is wrong)
#   npu-driver-check.sh --upstream also compare the installed fork commit with the fork's HEAD (GitHub API)
set -u
PKG=sky1-zhouyi-v3-driver-dkms
KVER="$(uname -r)"
fork_of_installed() { pacman -Q "$PKG" 2>/dev/null | awk '{print $2}'; }
tree_commit() { ls -d /usr/src/zhouyi-aipu-* 2>/dev/null | sed -E 's/.*\.r([0-9a-f]+)$/\1/' | head -1; }
fail=0
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fail=1; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$*"; }

echo "npu-driver-check  kernel=$KVER  package=$PKG $(fork_of_installed)"
echo "- kernel headers:";    HV="$(pacman -Q linux-aarch64-headers 2>/dev/null | awk '{print $2}')"; [ -n "$HV" ] && [ -d "/usr/lib/modules/$KVER/build" ] && ok "linux-aarch64-headers $HV (build dir for $KVER present)" || bad "headers for $KVER missing: pacman -S linux-aarch64-headers"
echo "- dkms + hooks:";      pacman -Q dkms >/dev/null 2>&1 && [ -f /usr/share/libalpm/hooks/70-dkms-upgrade.hook ] && ok "dkms $(pacman -Q dkms | awk '{print $2}') + pacman hooks" || bad "dkms or its pacman hooks missing"
echo "- DKMS source tree:";  TREE="$(ls -d /usr/src/zhouyi-aipu-* 2>/dev/null | head -1)"; [ -n "$TREE" ] && [ -f "$TREE/Makefile" ] && [ -f "$TREE/dkms.conf" ] && ok "$TREE (fork $(tree_commit))" || bad "no /usr/src/zhouyi-aipu-* tree with Makefile+dkms.conf"
echo "- built module:";      KO="/lib/modules/$KVER/updates/dkms/aipu.ko"; if [ -f "$KO" ]; then ok "$KO ($(stat -c %y "$KO" | cut -d. -f1))"; else bad "not built for $KVER -> doas dkms install zhouyi-aipu/<ver> -k $KVER (see /var/lib/dkms/zhouyi-aipu/*/make.log)"; fi
echo "- vermagic:";          VM="$(modinfo -F vermagic aipu 2>/dev/null)"; [ "${VM%% *}" = "$KVER" ] && ok "matches running kernel" || bad "'$VM' != $KVER (stale module file)"
echo "- loaded:";            if lsmod | grep -q '^aipu'; then ok "aipu loaded, $(lsmod | awk '/^aipu/{print $2}') bytes"; else bad "aipu not loaded -> doas modprobe aipu (or reboot: /usr/lib/modules-load.d/aipu.conf)"; fi
echo "- device node:";       [ -c /dev/aipu ] && ok "/dev/aipu" || bad "/dev/aipu missing"
echo "- boot autoload:";     [ -f /usr/lib/modules-load.d/aipu.conf ] && ok "$(grep -vE '^\s*(#|$)' /usr/lib/modules-load.d/aipu.conf | tr '\n' ' ')" || warn "no modules-load.d/aipu.conf"
echo "- kernel log:";        if dmesg 2>/dev/null | grep -q 'AIPU KMD'; then ok "$(dmesg | grep -E 'AIPU KMD \(v|zhouyi-v3|devfreq unavailable' | tail -2 | sed -E 's/^\[[^]]*\] //' | tr '\n' '|')"; else warn "no 'AIPU KMD' line in dmesg (module loaded before this boot's log? or probe never ran)"; fi
echo "- power state:";       echo "        $(cat /sys/devices/platform/CIXH4000:00/power/runtime_status 2>/dev/null || echo n/a) (suspended = idle, fine)"

if [ "${1:-}" = "--upstream" ]; then
  echo "- upstream:"
  LOCAL="$(tree_commit)"; HEAD="$(curl -sfL --max-time 15 https://api.github.com/repos/Reonarudo/sky1-zhouyi-v3-driver/commits?per_page=1 | sed -nE 's/.*"sha": *"([0-9a-f]{7})[0-9a-f]*".*/\1/p' | head -1)"
  if [ -z "$HEAD" ]; then warn "GitHub API unreachable (rate limit / offline)"; else
    if [ "$LOCAL" = "$HEAD" ]; then ok "fork HEAD $HEAD == installed"; else warn "fork HEAD $HEAD is newer than installed $LOCAL -> update the PKGBUILD (_fork / commit=) and rebuild"; fi
  fi
  UP="$(curl -sfL --max-time 15 https://api.github.com/repos/cixtech/cix_opensource__npu_driver/tags?per_page=1 | sed -nE 's/.*"name": *"([^"]+)".*/\1/p' | head -1)"
  [ -n "$UP" ] && echo "        cixtech upstream latest tag: $UP (our base: p1_7.0_v6.2.0)"
fi
[ $fail -eq 0 ] && echo "RESULT: healthy" || echo "RESULT: needs attention (see FAIL lines)"
exit $fail
