# Tests in a Windows 25H2 guest

The guest reports `BUILD 26200.6584 25H2 EnterpriseEval`. QEMU 10.2.1 with KVM nested in WSL2, UEFI, TPM 2.0, 4 virtual CPUs, 6,144 MB RAM, `-vga std` display card, no network, one screen. Every line below comes from the serial log of the install run at 20:52 on 2026-11-18 (the guest's serial.log, not included). The loader matrix of the same run is in the [virtual machine matrix](windows-cross-build-matrix.md).

Virtual machine note: `-cpu host` under KVM stayed at the firmware logo for 9 minutes and did not write to the virtual disk. The CPU model `Skylake-Client-v4,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_time` finished installing and wrote `COMPAT-DONE` after about 25 minutes.

## Protection state of the guest

`Get-MpComputerStatus` returns AMRunningMode Normal, RealTimeProtectionEnabled true, SmartAppControlState **Eval**, antivirus signature 1.403.7.0.

## Auto-hide taskbar

The `guest-taskbar.exe` test turns on the auto-hide flag through `SHAppBarMessage`, measures the height of the part of the taskbar on the main screen, then restores the original flag.

| Widget | Auto-hide on | Taskbar px: before / hidden / after moving the mouse | Widget px: hidden / after | Widget answers WM_NULL | Flag restored |
|---|---|---|---|---|---|
| pulsar-mini.exe | True | 48 / 2 / 2 | 2 / 2 | True | True |
| battery-mini.exe | True | 48 / 2 / 2 | 2 / 2 | True | True |

- The taskbar shrinks from 48 px to 2 px, the widget's child window shrinks with it and still answers.
- Putting the pointer at the bottom edge with `SetCursorPos` did not bring the taskbar back within 10 seconds. The show-again step is not confirmed.

## Widget menu and exclusive full screen: no valid result yet

- Menu: both widgets log `no child hit-test point`. No point inside the widget frame returns the child window itself through `WindowFromPoint`.
- Exclusive: `exclusive.exe` exits with code 1. The two widgets have frames 0,752,235,800 and 0,752,220,800, `is_visible=1`. Before, during and after the test, the test point inside the widget frame always lands on a window of class `Internet Explorer_Server`, pixel 0x00000000. `set_fullscreen=0x00000000`, `present=0x00000000`, `fullscreen_reported=0`, `foreground=0`.
- The test command runs in FirstLogonCommands. A window of class `Internet Explorer_Server` covers the taskbar area at that moment. The agent's inference: this is the first sign-in welcome screen; it was not captured to confirm.
- The Direct3D program does not report entering full screen on the `-vga std` card. This guest cannot demonstrate exclusive mode.

## Crinkler in the guest

Crinkler 3.0b links `resident.obj` inside the guest. The standard build is 435 B, the TINYHEADER build 378 B.

| File | Seconds | Working Set KiB | Private KiB |
|---|---:|---:|---:|
| unpacked.exe | 1.010 | 5,136 | 668 |
| unpacked.exe | 5.006 | 5,136 | 668 |
| unpacked.exe | 35.001 | 5,136 | 668 |
| unpacked.exe | 60.001 | 5,136 | 668 |
| crinkler-standard.exe | 1.003 | 518,232 | 578,600 |
| crinkler-standard.exe | 5.012 | 518,232 | 578,600 |
| crinkler-standard.exe | 35.043 | 518,232 | 578,600 |
| crinkler-standard.exe | 633.104 | 518,184 | 553,956 |

- The last sample of the standard build was taken at 633 seconds instead of 60 seconds. The measuring program was delayed in the guest, cause unknown.
- `crinkler-tinyheader.exe` could not start: Win32Exception "Operation did not complete successfully because the file contains a virus or potentially unwanted software".
- Defender Operational ID 1116 records Trojan:Win32/Crysant.RPS!MTB, source Real-Time Protection, for the exact path of the TINYHEADER file in the guest. Same label as on the build 26300 host, see the [host measurements](crinkler-resident.md).
- The RAM of TINYHEADER could not be measured on either the host or the clean guest.

## Smart App Control signature audit: no result yet

| Step | Log line |
|---|---|
| List policies before | `SAC before timeout` |
| Mount the EFI partition | `SAC mount rc=0` |
| Refresh policies | `SAC refresh timeout` |
| List policies after | `SAC after timeout` |
| Test conclusion | `SAC NoISG audit policy not listed` |
| Unmount the EFI partition | `SAC unmount rc=0` |

`CiTool.exe -lp` and `CiTool.exe -r` both timed out after 90 seconds, so the NoISG audit policy is not confirmed as loaded and the three samples were not tested under the policy. The agent's hypothesis: CiTool waits for a key press without `-json`. Not verified.

## SHA-256 of the samples on the test disk

| File | SHA-256 |
|---|---|
| guest-audit.exe | `9AAB607533D8EB76263D2040354A34AC2BB712FA85AD5ECE56F682261887FD88` |
| guest-taskbar.exe | `1144903535E9091E4BF1B959B8394C57E615E91134D74B01CD695A4C11578666` |
| exclusive.exe | `330C9D2362B83965A35E77F5A777E1D04AA885F64C4C77938FEC196F265D6EB8` |
| pulsar-mini.exe | `44D6196D8BCB6D94D180F6265B6DC36D21CD5B7CA977F9A4B6BDD541AF557876` |
| battery-mini.exe | `0E86AFE42E5A26389A18B172E2D7C117954A4BFC16ABCC754A6B9AA92131F6F3` |
| resident.obj | `54BAA74F2C6DD7E65EF7E7E1CD00C09073119ADD38A4FC3ECCF8283C2C58A82A` |
| unpacked.exe | `C8473EAEC74A4943CE4E25C82127325D6BDC683878D510B4627033EFBA2140E0` |
| Crinkler.exe | `86E4D861105DE24A9F599A5E7319E45D052C0DC2413BBE7A08FBD71AB5FB49D8` |
