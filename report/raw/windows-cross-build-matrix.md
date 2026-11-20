# Windows loader matrix in virtual machines

QEMU, UEFI and TPM 2.0, Windows Evaluation installed on a virtual disk. The version is read from the guest itself. The test creates the process in four modes, reads DEP, ASLR and CFG, then lets it run. Resident samples only check the loader's response through a 1,500 ms alive mark.

- 24H2 reports `BUILD 26100.1742 24H2 EnterpriseSEval` and all 24 results before `COMPAT-DONE`.
- 25H2 reports `BUILD 26200.6584 25H2 EnterpriseEval` and all 24 results before `COMPAT-DONE`.

| Fixture | SHA-256 |
|---|---|
| hello-plain.exe | `8D963D73EA01B974D8E6264B9B1E92CEBE48B5CCD85EEBB507AA34228560E824` |
| hello-tuned.exe | `72A810721586DB84AB4A8FD656BB40752477D7C3945A1A3BCFDD7DA2E273AA05` |
| guard-positive.exe | `4DF4D8FEA95A14104CAD15D0953D64BBC603DDA4A5E549BEEF8FB39509B3304B` |
| tiny268.exe | `D31701B65392ECC34D3A871BE30215C7A3A343218E4596EB79584E2D88A19BFD` |
| pulsar-mini.exe | `44D6196D8BCB6D94D180F6265B6DC36D21CD5B7CA977F9A4B6BDD541AF557876` |
| pulsar-standard.exe | `92FED0C5BA1ACBB7BFB93609FD99D295F7E2B478CCEC409EBEC618B9621C6236` |

| Fixture | Request | 24H2 | 25H2 |
| --- | --- | --- | --- |
| hello-plain.exe | default | `error:87 0x00000005 0x00000000 exit:0x00000000` | `error:87 0x00000005 0x00000000 exit:0x00000000` |
| hello-plain.exe | aslr-req | `error:87 0x0000000F 0x00000000 exit:0x00000000` | `error:87 0x0000000F 0x00000000 exit:0x00000000` |
| hello-plain.exe | cfg | `error:87 0x00000005 0x00000001 exit:0x00000000` | `error:87 0x00000005 0x00000001 exit:0x00000000` |
| hello-plain.exe | cfg-strict | `create-error:1657` | `create-error:1657` |
| hello-tuned.exe | default | `error:87 0x00000000 0x00000000 exit:0x00000000` | `error:87 0x00000000 0x00000000 exit:0x00000000` |
| hello-tuned.exe | aslr-req | `create-error:623` | `create-error:623` |
| hello-tuned.exe | cfg | `error:87 0x00000000 0x00000001 exit:0x00000000` | `error:87 0x00000000 0x00000001 exit:0x00000000` |
| hello-tuned.exe | cfg-strict | `create-error:1657` | `create-error:1657` |
| guard-positive.exe | default | `error:87 0x00000005 0x00000001 exit:0xC0000135` | `error:87 0x00000005 0x00000001 exit:0xC0000135` |
| guard-positive.exe | aslr-req | `error:87 0x0000000F 0x00000001 exit:0xC0000135` | `error:87 0x0000000F 0x00000001 exit:0xC0000135` |
| guard-positive.exe | cfg | `error:87 0x00000005 0x00000001 exit:0xC0000135` | `error:87 0x00000005 0x00000001 exit:0xC0000135` |
| guard-positive.exe | cfg-strict | `error:87 0x00000005 0x00000005 exit:0xC0000135` | `error:87 0x00000005 0x00000005 exit:0xC0000135` |
| tiny268.exe | default | `error:87 0x00000000 0x00000000 exit:0x0000002A` | `error:87 0x00000000 0x00000000 exit:0x0000002A` |
| tiny268.exe | aslr-req | `error:87 0x0000000A 0x00000000 exit:0x0000002A` | `error:87 0x0000000A 0x00000000 exit:0x0000002A` |
| tiny268.exe | cfg | `error:87 0x00000000 0x00000001 exit:0x0000002A` | `error:87 0x00000000 0x00000001 exit:0x0000002A` |
| tiny268.exe | cfg-strict | `create-error:1657` | `create-error:1657` |
| pulsar-mini.exe | default | `error:87 0x00000000 0x00000000 alive:1500ms` | `error:87 0x00000000 0x00000000 alive:1500ms` |
| pulsar-mini.exe | aslr-req | `create-error:623` | `create-error:623` |
| pulsar-mini.exe | cfg | `error:87 0x00000000 0x00000001 alive:1500ms` | `error:87 0x00000000 0x00000001 alive:1500ms` |
| pulsar-mini.exe | cfg-strict | `create-error:1657` | `create-error:1657` |
| pulsar-standard.exe | default | `error:87 0x00000005 0x00000000 alive:1500ms` | `error:87 0x00000005 0x00000000 alive:1500ms` |
| pulsar-standard.exe | aslr-req | `error:87 0x0000000F 0x00000000 alive:1500ms` | `error:87 0x0000000F 0x00000000 alive:1500ms` |
| pulsar-standard.exe | cfg | `error:87 0x00000005 0x00000001 alive:1500ms` | `error:87 0x00000005 0x00000001 alive:1500ms` |
| pulsar-standard.exe | cfg-strict | `create-error:1657` | `create-error:1657` |

## Reading the results

Each cell is the line printed by `measure.exe`: last error code, DEP/ASLR flags, CFG flags and outcome. The 25H2 guest runs through `guest-audit.exe`, so its serial log has an extra `rc=0` from the measuring program at the start of each line.

- 48/48 cells are identical between 24H2 build 26100.1742 and 25H2 build 26200.6584, and match the cells of the same sample and mode on build 26300 in the [host matrix](pe-process-mitigations.md). The only exception is `guard-positive.exe`, which exits with code 0 on the host because the host already has the dynamic CRT.
- The 268 B PE and the two Pulsar builds run in normal mode on both Windows versions.
- Mandatory ASLR requires relocations and rejects `hello-tuned.exe` and `pulsar-mini.exe` with code 623. The standard Pulsar build still survives 1,500 ms in that configuration.
- The five samples without CFG are rejected at process creation under Strict CFG with code 1657.
- `guard-positive.exe` uses the dynamic CRT and imports `VCRUNTIME140.dll`. The clean guest does not have this DLL, so the process is created under Strict CFG and then exits with `0xC0000135`.

## Control: statically linked CFG build on 25H2

`guard-static.exe` is built from the same source with `/MT /guard:cf`, 111,616 B, importing only KERNEL32.dll. This sample only ran on the 25H2 guest because it was built after the 24H2 guest had been shut down.

| Request | 25H2 |
|---|---|
| default | `error:87 0x00000005 0x00000001 exit:0x00000000` |
| aslr-req | `error:87 0x0000000F 0x00000001 exit:0x00000000` |
| cfg | `error:87 0x00000005 0x00000001 exit:0x00000000` |
| cfg-strict | `error:87 0x00000005 0x00000005 exit:0x00000000` |

The CFG sample runs through its entry point and exits with code 0 in all four modes, including Strict CFG. The `0xC0000135` error of the dynamically linked sample comes from the missing DLL, not from the CFG policy.
