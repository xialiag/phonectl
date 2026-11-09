# Bundled third-party files

- `termux-root-su-kernelsu.zip` — built from
  https://github.com/xialiag/termux-root-su v3.10 (MIT). `service.sh` is patched
  for KernelSU; see `../patches/termux-root-su-kernelsu.patch`.
- `ADBKeyboard.apk` — from https://github.com/senzhk/ADBKeyBoard
  (Apache License 2.0).
The Termux:API **application** APK and the `termux-api` client **.deb** are not
bundled; `setup-device.sh` downloads them from the official release / mirror at
install time (Termux:API is GPL-3.0).
