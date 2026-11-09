#!/usr/bin/env bash
# Safe smoke test (run inside the container, device may be locked).
set -u
fail=0
step() { echo "== $*"; }

step version;      phonectl --version || fail=1
step selftest;     phonectl selftest || fail=1
step dry tap;      PHONECTL_DRY=1 phonectlctl tap 10 20 || fail=1
step dry swipe;    PHONECTL_DRY=1 phonectlctl swipe 1 2 3 4 300 || fail=1
step dry drag;     PHONECTL_DRY=1 phonectlctl drag 1 2 3 4 500 || fail=1
step dry text;     PHONECTL_DRY=1 phonectlctl text "hello world" || fail=1
step dry unicode;  PHONECTL_DRY=1 phonectlctl text "中文测试" || fail=1
step ui json;      phonectl ui json | head -c 80; echo || fail=1
step battery;      phonectl battery | head -4 || fail=1
if [ "$fail" -eq 0 ]; then
    echo "SMOKE PASS"
else
    echo "SMOKE FAIL"
    exit 1
fi
