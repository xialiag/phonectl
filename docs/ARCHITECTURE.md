# Architecture

```
┌────────────────────────────── Android ──────────────────────────────┐
│  termux-root-su module (KernelSU/Magisk)                            │
│  ┌────────────────────┐   abstract unix socket @termux-root-su      │
│  │ magisk-proxy (uid0)│◀───────────────┐  SO_PEERCRED: uid 0/10009   │
│  │ forks Android sh   │                │                            │
│  └────────▲───────────┘                │                            │
│           │ fork                       │                            │
│  ┌────────┴───────────┐     ┌──────────┴─────────┐                  │
│  │ root shell (ksu)   │     │ su client (musl)   │                  │
│  └────────────────────┘     └──────────▲─────────┘                  │
│                                        │ exec                       │
│  ┌─────────────────────────────────────┴────────────────────────┐  │
│  │ proot Ubuntu container                                        │  │
│  │  /usr/local/bin/phonectl  ──► su -c ... (root); /system/bin/sh   │  │
│  │  run-as com.termux ──► termux-api clients (Termux uid)        │  │
│  │  am broadcast ──► ADBKeyboard (unicode text)                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Root path

1. `service.sh` (run by KernelSU/Magisk at boot, or manually) starts
   `magisk-proxy` as uid 0. It listens on the **abstract** unix socket
   `@termux-root-su`; proot does not path-translate abstract sockets.
2. The proxy accepts a connection only when `SO_PEERCRED` reports uid 0 or the
   Termux uid (`10009` on this device), then forks an Android shell.
3. The musl-static `su` client is deployed to Termux `$PREFIX/bin/su` and every
   proot rootfs `/usr/local/bin/su`. Inside the container it connects to the
   proxy and bridges stdio/exit codes.
4. Why not plain Magisk su: Magisk checks the client's executable inode
   (`/proc/pid/exe` is the proot loader) and proot hijacks filesystem unix
   sockets; both make the normal path impossible.

## KernelSU patch

Upstream v3.10 is a Magisk module; `service.sh` aborts when no `MAGISKTMP`
exists. The patch (see `patches/`) falls back to `/data/adb/ksu` and skips the
magiskd socket wait — the proxy never uses magiskd. Install with
`ksud module install`; KernelSU stages it in `modules_update` until reboot.

## Termux:API path

The API app (`com.termux.api`) is installed as a normal APK. Client scripts
(`termux-notification`, `termux-battery-status`, ...) are extracted from the
official `.deb` into `$PREFIX` (Termux pkg mirrors are often unreachable).
`phonectl` runs them via `run-as com.termux env PREFIX=... PATH=...`, so the
client has the Termux uid and can reach the API service through
`termux-am` / broadcast. Root would be rejected by the app.

## Unicode input

Android's `input text` is ASCII-only. `phonectl text` detects non-ASCII, saves the
current IME, switches to `com.android.adbkeyboard/.AdbIME`, sends
`am broadcast -a ADB_INPUT_B64 --es msg <base64>`, waits for the commit, and
restores the previous IME. The field must be focused; the device must be
unlocked.

## Boundary and failure modes

- Locked device: UI dump/screenshot/tap work on the keyguard but cannot bypass
  it; unicode typing is unavailable.
- `screenrecord` needs screen-on + unlocked (Android returns
  `INVALID_LAYER_STACK` otherwise).
- Clipboard reads may be empty unless Termux:API is in the foreground
  (Android 10+).
- If the proxy dies, its watchdog restarts it; manual recovery:
  `su -c 'sh /data/adb/modules/termux-root-su/service.sh'`.
