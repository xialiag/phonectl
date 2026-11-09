# phonectl

Android control toolkit for the [Hermes Agent](https://github.com/NousResearch/hermes-agent)
running inside a Termux **proot** container.

It gives the agent real Android root plus a compact CLI for UI automation,
screenshots, app/system control, and Termux:API features — so an LLM agent can
actually operate the phone instead of only chatting.

```
phonectl root id                  # uid=0(root) context=u:r:ksu:s0
phonectl ui json                  # structured hierarchy the model can parse
phonectl ui tap-text "微信"       # tap by text/desc/id
phonectl ui set-text "搜索" "周报"  # focus + clear + unicode-safe typing
phonectl screenshot               # PNG also copied to /root/shots for vision
phonectl notify "Hermes" "完成"
```

## Why

Hermes runs in a Linux container; Android is outside it. Two problems:

1. **No root inside proot.** Magisk's `su` checks the client's exe and proot
   hijacks unix socket paths, so a container-side `su` cannot reach magiskd.
2. **No Android binaries/PATH.** Termux binaries are bionic and the Termux:API
   service expects the Termux uid.

This project solves both:

- **termux-root-su proxy** (KernelSU/Magisk module, patched here for KernelSU):
  a root daemon listens on the abstract socket `@termux-root-su`, authenticates
  callers by uid (`SO_PEERCRED`), and forks Android root shells. Abstract
  sockets are not path-translated by proot, so the container client connects.
- **Termux:API bridge**: the app is installed and the `termux-api` clients are
  placed in `$PREFIX`; `phonectl` runs them through `run-as com.termux` so they
  reach the API service with the right uid.
- **ADBKeyboard** provides unicode text injection (`phonectl text "中文"` switches
  the IME temporarily and restores the previous one).

## Requirements

- Android device with **KernelSU** (tested 3.3.1) or Magisk (module is
  Magisk-format; the patched script also runs under KernelSU).
- Termux + `proot-distro` Ubuntu (or any glibc container with bash/python3).
- Termux:API app (the installer downloads the GitHub release).
- ADBKeyboard app (the installer downloads it).
- A GitHub token is **not** needed at runtime.

## Install

### 1. Device side (root, from adb or Termux)

```bash
adb push setup-device.sh /data/local/tmp/
adb shell su -c 'sh /data/local/tmp/setup-device.sh'
```

The script:

1. downloads the `termux-root-su` release zip;
2. patches `service.sh` for KernelSU (no Magisk tmpfs) and repacks it;
3. installs it with `ksud module install` (falls back to Magisk's
   `magisk --install-module`);
4. starts the proxy now (`service.sh`);
5. downloads and installs **Termux:API** and **ADBKeyboard** APKs via `pm`;
6. downloads the `termux-api` client `.deb` and installs its files into
   `$PREFIX` as the Termux uid (pkg mirrors are often unreachable).

### 2. Container side

Put this repository somewhere the container can read (e.g. `/sdcard/phonectl`
or copy it into the container), then:

```bash
proot-distro login ubuntu -- bash /sdcard/phonectl/install-container.sh
```

Copies `phonectl` to `/usr/local/bin/phonectl` (plus a `phone` symlink for
convenience) and the skill to `~/.hermes/skills/phonectl/SKILL.md`.

### 3. Verify

```bash
phonectl selftest      # root, getprop, UI dump, screenshot, Termux:API battery
```

## Command surface

| Area | Commands |
|---|---|
| root | `root`, `sh`, `sysinfo`, `selftest` |
| UI | `ui dump/json/find/tap/tap-text/tap-id/longpress/swipe-node/set-text/wait/scroll-to/focus` |
| input | `tap`, `doubletap`, `swipe`, `drag`, `longpress`, `scroll`, `text [--clear]`, `key`, `keycombo` |
| screen | `screenshot`, `record`, `screen on/off/unlock/lock` |
| apps | `app list/start/stop/info/install/uninstall/current` |
| files | `pull`, `push`, `intent` |
| system | `battery`, `wifi status/on/off/scan`, `brightness`, `volume`, `media`, `rotation`, `airplane`, `ime` |
| Termux:API | `notify`, `toast`, `vibrate`, `tts`, `clipboard`, `camera`, `sms`, `call`, `location`, `sensor`, `torch`, `share`, `download`, `termux <client>` |

`PHONECTL_DRY=1 phonectl ...` prints the underlying commands instead of executing.

## Hermes integration

The skill teaches the agent when and how to use the CLI; the agent calls it
through its `terminal` tool. Recommended loop: `phonectl ui json` → selector-based
action → `phonectl screenshot` + vision when uiautomator cannot see the surface.

## Limitations

- Locked devices cannot be unlocked programmatically (by design).
- `phonectl text` unicode path switches IME for ~1.5s; a focused field is required.
- Clipboard **read** may be empty unless Termux:API is foreground (Android 10+).
- `screenrecord` requires the screen on and unlocked.
- `uiautomator dump` misses games/secure surfaces — use screenshots + vision.
- Termux:API features (camera/SMS/call/location) may ask for runtime
  permissions on first use.

## Security

- The root proxy accepts **any process running as the Termux uid**; that is the
  point of the module, but it means every Termux script can become root.
- Screenshots and UI dumps can contain secrets; keep them local.
- Confirm destructive actions (uninstall, SMS, calls, permission changes) with
  the device owner.

## Tested on

vivo X80 (PD2183), Android 15, KernelSU 3.3.1, Termux proot Ubuntu 26.04.

## License

MIT
