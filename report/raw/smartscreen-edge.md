# SmartScreen - download test through Edge

Tested on 2026-11-18 with Microsoft Edge 157.0.4341.60 on Windows 11 build 26300. A new profile was used with the default protection settings. The Downloads page and the download history of that profile were read. Both URLs belong to Microsoft's public sample set. [Microsoft's SmartScreen test guide](https://learn.microsoft.com/en-us/defender-endpoint/defender-endpoint-demonstration-app-reputation).

| Microsoft sample | Observed in Edge | Target file | Download history |
|---|---|---|---|
| Known good | The Downloads page shows the file and the open-folder button | 34,304 B, Zone.Identifier with ZoneId 3 and a SmartScreen stream | state 1, danger_type 4, interrupt_reason 0, opened 0 |
| Unknown | The Downloads page says the file is not commonly downloaded and asks for confirmation before opening | Only a temporary download file while observing. The temporary file disappears after the session is closed | state 2, danger_type 5, interrupt_reason 41, opened 0 |

The SHA-256 of the Known good sample is 1C2C20790056345087838A32CBC39ECA0C14FFFA155C63758972DC254D62B614. The download step did not execute the file. Windows Smart App Control on the host reported Off when its state was queried.

## Control: opening the file through the Windows Shell

Microsoft's Known good sample is kept unchanged, with the same SHA-256 and ZoneId 3. It is opened with the Windows Shell `open` verb. The Shell created process PID 37252 after 160 ms. The process has a main window and exits with code 0 when the sample's own window is closed. The Unknown sample stops at the download warning in Edge. The Windows Shell warning for a sample without reputation, and Smart App Control in the On state, remain open questions. [ShellExecuteEx](https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shellexecuteexw).

## Opening the Unknown sample through the Windows Shell

Tested on 2026-11-18 on the build 26300 host, Smart App Control reported Off, Defender real-time protection on. Microsoft's Unknown sample was downloaded with curl because Edge does not save the complete file: 34,304 B, SHA-256 A8ACE233FD63B0D1D30BC55BE9D74357F5985099AE570EDF3AE78E0724ADD865, Authenticode NotSigned. The Zone.Identifier stream was written by hand with ZoneId 3 and the sample's HostUrl, so there is no SmartScreen stream created by Edge.

| Step | Observation |
|---|---|
| Windows Shell `open` verb | The call does not return, no freevideo.exe process |
| Window that appears | `Open File - Security Warning` dialog, class #32770, owned by the process that called the Shell |
| Dialog content | "The publisher could not be verified. Are you sure you want to run this software?", Publisher: Unknown Publisher, Run and Cancel buttons |
| Related process | smartscreen.exe PID 24852 started at 20:47:34, while the Shell call was running |
| Dialog closed with WM_CLOSE | The Shell returns "The operation was canceled by the user" after 221 seconds, the sample does not run |

The Windows Shell blocked with a warning before creating the process. The observed warning is the Attachment Manager dialog for an unsigned file, not SmartScreen's blue "Windows protected your PC" screen. The Run button does not accept simulated clicks through BM_CLICK and WM_COMMAND, so the next part was done by hand by the user.

### Run opened by hand in File Explorer

The user opened the same file from File Explorer and reported clicking "Run anyway". That button label belongs to the SmartScreen warning screen. The agent could not capture that screen itself, so the wording on the warning is as reported by the user.

| Observed after the user clicked | Value |
|---|---|
| freevideo.exe process | PID 84412, started 20:52:37, at the sample's path |
| Main window title | Demo App - An Unknown App |
| File streams after running | Only :$DATA 34,304 B left, Zone.Identifier removed |

The Windows Shell let the sample without reputation run after the user confirmed, and removed the Internet zone mark from the file. Smart App Control in the On state remains an open question.
