---
name: phonectl
description: Control the Android phone from the proot container with the `phonectl` CLI — root shell, UI automation (JSON hierarchy, selector taps, unicode text), screenshots/recording, apps, system settings, notifications/camera/SMS/location via Termux:API.
version: 3.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [android, phone, ui-automation, root, screenshot, termux, termux-api, adbkeyboard]
---

# Phone Control (Android)

`phonectl` runs in the proot container. Root comes from the termux-root-su proxy
(KernelSU module, abstract socket, uid auth); device APIs come from Termux:API;
unicode text uses ADBKeyboard.

Start with `phonectl selftest` — it checks root, getprop, UI dump, screenshot and
Termux:API in one shot.

## Common calls

```bash
phonectl root id                     # uid=0 context=u:r:ksu:s0
phonectl sysinfo
phonectl ui json                     # [{index,text,desc,id,cls,bounds,center,clickable,...}]
phonectl ui tap "登录"               # text/desc/id substring -> tap first hit
phonectl ui tap 37                   # node index from ui json
phonectl ui tap-text "设置"
phonectl ui tap-id com.example:id/btn
phonectl ui longpress "消息"
phonectl ui swipe-node "列表" up 600
phonectl ui set-text "搜索" "周报"   # focus + clear + type (unicode-safe)
phonectl ui wait "结果" 20
phonectl ui scroll-to "设置" 6
phonectl ui focus                    # current focused window
phonectl screenshot                  # /root/shots/... ready for vision
phonectl record 10                   # screenrecord (screen on + unlocked)
phonectl notify "Hermes" "完成"
phonectl toast "hello" ; phonectl vibrate 300 ; phonectl tts "播报内容"
phonectl camera 0 /sdcard/DCIM/agent.jpg
phonectl sms list ; phonectl sms send 10086 "查询余额"
phonectl location -p gps              # extra args are forwarded to termux-location
phonectl sensor list | accelerometer
phonectl torch on|off
phonectl termux <client> [args...]   # any termux-api client
```

Input primitives: `tap`, `doubletap`, `swipe`, `drag`, `longpress`, `scroll`,
`text [--clear]`, `key`, `keycombo`, `screen on|off|unlock|lock`.

Apps/files: `app list|start|stop|info|install|uninstall|current`, `pull`,
`push`, `intent`.

System: `battery`, `wifi status|on|off|scan`, `brightness`, `volume`,
`media`, `rotation`, `airplane`, `ime adb|system|status`.

`PHONECTL_DRY=1 phonectl ...` prints the underlying commands instead of executing.

## Recommended loops

**Selector loop (preferred)**
1. `phonectl ui json`
2. pick a node by text/desc/id (index, center, clickable)
3. `phonectl ui tap <index|text>` / `phonectl ui set-text ...`
4. `phonectl ui wait <expected>` to confirm.

**Vision loop (games/secure surfaces)**
`phonectl screenshot` → `vision_analyze /root/shots/...` → `phonectl tap X Y` →
screenshot again.

## Limitations

- Locked device cannot be unlocked programmatically; keyguard UI is visible but
  typing requires an unlocked, focused field.
- `phonectl text` unicode switches the IME for ~1.5s and restores it.
- `screenrecord` fails with `INVALID_LAYER_STACK` when the screen is off/locked.
- Clipboard read may be empty unless Termux:API is foreground.
- uiautomator misses games/secure windows; use screenshots + vision.
- Camera/SMS/call/location may need runtime permissions for Termux:API.

## Safety

- Screenshots/UI dumps can contain secrets — keep them local.
- Confirm destructive actions with the user: uninstall/disable apps, SMS,
  calls, permission changes, security settings.

## Recovery

`phonectl selftest` fails at root → from Termux:
`su -c 'sh /data/adb/modules/termux-root-su/service.sh'`.
