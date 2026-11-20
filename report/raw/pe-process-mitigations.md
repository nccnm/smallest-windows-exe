# PE - Policies at process creation

| Exe | Request | DEP / ASLR / CFG flags and result |
|---|---|---|
| s2_x64_268_soh0.exe | default | error:87 0x00000000 0x00000000 exit:0x0000002A |
| s2_x64_268_soh0.exe | dep | error:87 0x00000000 0x00000000 exit:0x0000002A |
| s2_x64_268_soh0.exe | aslr | error:87 0x00000002 0x00000000 exit:0x0000002A |
| s2_x64_268_soh0.exe | aslr-req | error:87 0x0000000A 0x00000000 exit:0x0000002A |
| s2_x64_268_soh0.exe | cfg | error:87 0x00000000 0x00000001 exit:0x0000002A |
| s2_x64_268_soh0.exe | cfg-strict | create-error:1657 |
| msvc_nocrt_plain.exe | default | error:87 0x00000005 0x00000000 exit:0x00000000 |
| msvc_nocrt_plain.exe | dep | error:87 0x00000005 0x00000000 exit:0x00000000 |
| msvc_nocrt_plain.exe | aslr | error:87 0x00000007 0x00000000 exit:0x00000000 |
| msvc_nocrt_plain.exe | aslr-req | error:87 0x0000000F 0x00000000 exit:0x00000000 |
| msvc_nocrt_plain.exe | cfg | error:87 0x00000005 0x00000001 exit:0x00000000 |
| msvc_nocrt_plain.exe | cfg-strict | create-error:1657 |
| msvc_nocrt_tuned.exe | default | error:87 0x00000000 0x00000000 exit:0x00000000 |
| msvc_nocrt_tuned.exe | dep | error:87 0x00000000 0x00000000 exit:0x00000000 |
| msvc_nocrt_tuned.exe | aslr | error:87 0x00000002 0x00000000 exit:0x00000000 |
| msvc_nocrt_tuned.exe | aslr-req | create-error:623 |
| msvc_nocrt_tuned.exe | cfg | error:87 0x00000000 0x00000001 exit:0x00000000 |
| msvc_nocrt_tuned.exe | cfg-strict | create-error:1657 |
| pulsar-mini-standard.exe | default | error:87 0x00000005 0x00000000 alive:1500ms |
| pulsar-mini-standard.exe | dep | error:87 0x00000005 0x00000000 alive:1500ms |
| pulsar-mini-standard.exe | aslr | error:87 0x00000007 0x00000000 alive:1500ms |
| pulsar-mini-standard.exe | aslr-req | error:87 0x0000000F 0x00000000 alive:1500ms |
| pulsar-mini-standard.exe | cfg | error:87 0x00000005 0x00000001 alive:1500ms |
| pulsar-mini-standard.exe | cfg-strict | create-error:1657 |
| pulsar-mini.exe | default | error:87 0x00000000 0x00000000 alive:1500ms |
| pulsar-mini.exe | dep | error:87 0x00000000 0x00000000 alive:1500ms |
| pulsar-mini.exe | aslr | error:87 0x00000002 0x00000000 alive:1500ms |
| pulsar-mini.exe | aslr-req | create-error:623 |
| pulsar-mini.exe | cfg | error:87 0x00000000 0x00000001 alive:1500ms |
| pulsar-mini.exe | cfg-strict | create-error:1657 |
| unpacked.exe | default | error:87 0x00000001 0x00000000 alive:1500ms |
| unpacked.exe | dep | error:87 0x00000001 0x00000000 alive:1500ms |
| unpacked.exe | aslr | error:87 0x00000003 0x00000000 alive:1500ms |
| unpacked.exe | aslr-req | error:87 0x0000000B 0x00000000 alive:1500ms |
| unpacked.exe | cfg | error:87 0x00000001 0x00000001 alive:1500ms |
| unpacked.exe | cfg-strict | create-error:1657 |
| guard-positive.exe | default | error:87 0x00000005 0x00000001 exit:0x00000000 |
| guard-positive.exe | cfg | error:87 0x00000005 0x00000001 exit:0x00000000 |
| guard-positive.exe | cfg-strict | error:87 0x00000005 0x00000005 exit:0x00000000 |

- Each child is created suspended, the three policies are read, then it is resumed. Resident samples are limited to 1,500 ms. The flags are attached to each child with PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY.
- Code 1657 reports missing Control Flow Guard. The guard-positive control build has /guard:cf and a 9-entry Guard CF table according to dumpbin.
- The GetProcessMitigationPolicy API returns 87 in the DEP field for the whole matrix, so this field does not measure the DEP state. The dep request rows only show the start/run behaviour under that process creation request.
- Load address relocation was not verified in the 1,500 ms runs. The ASLR flag confirms the policy at process level.

## DEP - x86 reads its own policy

| Exe | Request at creation | Result |
|---|---|---|
| dep-self-nx.exe | default | error:87 0x00000001 0x00000000 exit:0x00000110 |
| dep-self-nx.exe | dep | error:87 0x00000001 0x00000000 exit:0x00000113 |
| dep-self-no-nx.exe | default | error:87 0x00000001 0x00000000 exit:0x00000110 |
| dep-self-no-nx.exe | dep | error:87 0x00000001 0x00000000 exit:0x00000113 |

Two WoW64 fixtures call GetProcessDEPPolicy on their own process. Exit 0x110 encodes flags 0 and permanent 1. Exit 0x113 encodes flags 3 and permanent 1, showing that DEP is on and ATL thunk emulation is off when requested at child creation. The 87 in the table is still the error of the read from the launcher. [GetProcessDEPPolicy](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getprocessdeppolicy).
