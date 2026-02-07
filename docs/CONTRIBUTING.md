# Contributing

Thank you for your interest in improving Ubuntu Touch on the Lenovo Tab M8 HD!

## How to Contribute

### Reporting Issues
- Open a [GitHub Issue](https://github.com/thephfox/ubuntu-touch-lenovo-tab-m8/issues)
- Include your device model (TB-8505F, TB-8505X, etc.)
- Include kernel version (`uname -a`)
- Include relevant logs (`journalctl -b`, `dmesg`)

### Submitting Fixes
1. Fork this repository
2. Create a feature branch (`git checkout -b fix/audio-crackling`)
3. Test your changes on a real device
4. Submit a Pull Request with a clear description

### Areas Where Help is Needed

#### High Priority
- **Missing/blank characters** — Font rendering issue with Ubuntu variable font in QML/Lomiri
- **Camera quality** — ISP parameter tuning for the rear camera
- **Tap to wake** — FT8201 touch controller gesture wake handler

#### Medium Priority
- **Kernel recompilation** — Enable KSM, ZSWAP, FBCON, BBR (see `kernel/defconfig_changes.md`)
- **Waydroid improvements** — Better memory management for Android container on 2GB RAM
- **Battery optimization** — Power management tuning for longer battery life

#### Low Priority
- **OTA updates** — Setting up system-image server for over-the-air updates
- **TB-8505X support** — Cellular model with telephony support

## Development Setup

### Prerequisites
- Lenovo Tab M8 HD with unlocked bootloader
- Ubuntu Touch installed ([original port](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8))
- ADB access (platform-tools v29.0.5 recommended)
- Python 3.x for patch scripts

### Testing Changes
```bash
# Push and test a script
adb push scripts/your_script.sh /tmp/
adb shell "echo PASSWORD | sudo -S sh /tmp/your_script.sh"

# Check logs
adb shell "journalctl -b --no-pager | tail -50"

# Verify system state
adb push scripts/verify.sh /tmp/
adb shell "echo PASSWORD | sudo -S sh /tmp/verify.sh"
```

## Code Style
- Shell scripts: POSIX sh compatible (no bashisms)
- Python: Python 3.x, no external dependencies where possible
- Systemd units: well-commented with install instructions in header
- All files must include a header comment explaining purpose and usage

## License
All contributions must be compatible with GPL-2.0.
