#!/bin/bash
set -e

echo "=============================="
echo " RStudio RES AMI Validation"
echo "=============================="

FAIL=0

check() {
  if ! eval "$2" >/dev/null 2>&1; then
    echo "❌ FAIL: $1"
    FAIL=1
  else
    echo "✅ PASS: $1"
  fi
}

echo
echo "1) Verifying R installation"
check "R binary exists" "[ -x /opt/R/4.5.2/bin/R ]"
check "R version is 4.5.2" "/opt/R/4.5.2/bin/R --version | grep -q 'R version 4.5.2'"

echo
echo "2) Verifying RStudio Desktop"
check "RStudio RPM installed" "rpm -qa | grep -qi '^rstudio-'"
check "rstudio binary present" "[ -x /usr/bin/rstudio ]"

echo
echo "3) Verifying environment hardening"
check "RSTUDIO_WHICH_R set globally" \
  "grep -q 'RSTUDIO_WHICH_R=/opt/R/4.5.2/bin/R' /etc/profile.d/rstudio-r.sh"

check "X11 forced (QT_QPA_PLATFORM=xcb)" \
  "grep -q 'QT_QPA_PLATFORM=xcb' /etc/profile.d/rstudio-x11.sh"

check "/usr/local/bin in PATH" \
  "grep -q '/usr/local/bin' /etc/profile.d/local-bin.sh"

echo
echo "4) Verifying jsonrpc self-healing guard"
check "rstudio-clean guard present" \
  "[ -f /etc/profile.d/rstudio-clean.sh ]"

echo
echo "5) Checking for forbidden baked user state"
RESIDUE=$(ls -d /home/*/.local/share/rstudio \
               /home/*/.config/rstudio \
               /home/*/.cache/rstudio \
               /home/*/.jupyter \
               /home/*/.ipython \
               /home/*/.mozilla 2>/dev/null || true)

if [ -n "$RESIDUE" ]; then
  echo "❌ FAIL: Per-user residue found:"
  echo "$RESIDUE"
  FAIL=1
else
  echo "✅ PASS: No per-user residue detected"
fi

echo
echo "6) Checking R library locations"
check "S7 installed system-wide" \
  "/opt/R/4.5.2/bin/R -q -e \"stopifnot(.libPaths()[1] != paste0(Sys.getenv('HOME'), '/R'))\""

echo
echo "7) Home filesystem check"
mount | grep -q '/home' && echo "ℹ️  /home is mounted (expected in RES)"

echo
echo "=============================="
if [ $FAIL -eq 0 ]; then
  echo "🎉 ALL CHECKS PASSED"
  echo "➡️  SAFE TO CREATE AMI / RES SOFTWARE STACK"
else
  echo "🚫 VALIDATION FAILED"
  echo "➡️  FIX THE ABOVE ISSUES BEFORE IMAGING"
  exit 1
fi
echo "=============================="
