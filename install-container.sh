#!/usr/bin/env bash
# Container-side install (run inside the proot distro).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
install -m 755 "$HERE/phonectl" /usr/local/bin/phonectl
ln -sf /usr/local/bin/phonectl /usr/local/bin/phone
SK="$HOME/.hermes/skills/phonectl/SKILL.md"
mkdir -p "$(dirname "$SK")"
install -m 644 "$HERE/skills/phonectl/SKILL.md" "$SK"
echo "installed /usr/local/bin/phonectl"
echo "installed $SK"
phonectl --version
