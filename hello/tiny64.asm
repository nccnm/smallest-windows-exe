; tiny64.asm - hand-built PE32+ (x64) with NASM, no linker.
; "Clean" tiny PE: standard headers, one RWX section, real import table, nothing overlapped.
; Low-alignment mode: SectionAlignment == FileAlignment == 4, so file offset == RVA.
; Build: nasm -f bin -o tiny64_cli.exe tiny64.asm            (console hello)
;        nasm -f bin -DGUI -o tiny64_gui.exe tiny64.asm      (MessageBox hello)
BITS 64
DEFAULT REL
IMAGEBASE equ 0x400000

mz:     dw 'MZ'
        times 0x3C-($-mz) db 0
        dd pe                       ; e_lfanew

pe:     dd 0x00004550               ; 'PE\0\0'
        dw 0x8664                   ; Machine = AMD64
        dw 1                        ; NumberOfSections
        dd 0, 0, 0                  ; TimeDateStamp, PointerToSymbolTable, NumberOfSymbols
        dw opt_end - opt            ; SizeOfOptionalHeader
        dw 0x0023                   ; RELOCS_STRIPPED | EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE
opt:    dw 0x020B                   ; PE32+
        db 0, 0                     ; linker version
        dd image_end - sect         ; SizeOfCode
        dd 0, 0                     ; SizeOfInitializedData, SizeOfUninitializedData
        dd start                    ; AddressOfEntryPoint
        dd sect                     ; BaseOfCode
        dq IMAGEBASE                ; ImageBase
        dd 4                        ; SectionAlignment
        dd 4                        ; FileAlignment
        dw 6, 0                     ; OS version
        dw 0, 0                     ; image version
        dw 6, 0                     ; subsystem version
        dd 0                        ; Win32VersionValue
        dd image_end                ; SizeOfImage
        dd hdr_end                  ; SizeOfHeaders
        dd 0                        ; CheckSum
%ifdef GUI
        dw 2                        ; Subsystem = WINDOWS_GUI
%else
        dw 3                        ; Subsystem = WINDOWS_CUI
%endif
        dw 0                        ; DllCharacteristics
        dq 0x100000, 0x1000         ; stack reserve, commit
        dq 0x100000, 0x1000         ; heap reserve, commit
        dd 0                        ; LoaderFlags
        dd 16                       ; NumberOfRvaAndSizes
        dd 0, 0                     ; export
        dd idata, idata_end - idata ; import
        times 14 dd 0, 0
opt_end:
        db '.text', 0, 0, 0
        dd image_end - sect         ; VirtualSize
        dd sect                     ; VirtualAddress
        dd image_end - sect         ; SizeOfRawData
        dd sect                     ; PointerToRawData
        dd 0, 0
        dw 0, 0
        dd 0xE0000060               ; code | initialized data | execute | read | write
hdr_end:

sect:
start:
        sub rsp, 40                 ; 32 shadow + 8 for 5th arg, keeps 16-byte alignment
%ifdef GUI
        xor ecx, ecx                ; hWnd
        lea rdx, [msg]
        lea r8, [cap]
        xor r9d, r9d                ; MB_OK
        call [iat1]                 ; MessageBoxA
%else
        mov ecx, -11                ; STD_OUTPUT_HANDLE
        call [iat1]                 ; GetStdHandle
        mov rcx, rax
        lea rdx, [msg]
        mov r8d, msg_len
        lea r9, [written]
        mov qword [rsp+32], 0
        call [iat2]                 ; WriteFile
%endif
        xor ecx, ecx
        call [iat_exit]             ; ExitProcess

%ifdef GUI
msg:    db 'Hello, World!', 0
cap:    db 'Hello', 0
%else
msg:    db 'Hello, World!', 13, 10
msg_len equ $ - msg
%endif
        align 8
written: dq 0

idata:
%ifdef GUI
        dd 0, 0, 0, dll_user, iat_user
%endif
        dd 0, 0, 0, dll_k32, iat_k32
        dd 0, 0, 0, 0, 0
idata_end:

        align 8
%ifdef GUI
iat_user:
iat1:   dq hn_mb
        dq 0
iat_k32:
iat_exit: dq hn_exit
        dq 0
%else
iat_k32:
iat1:   dq hn_gsh
iat2:   dq hn_wf
iat_exit: dq hn_exit
        dq 0
%endif

        align 2
%ifdef GUI
hn_mb:  dw 0
        db 'MessageBoxA', 0
        align 2
%else
hn_gsh: dw 0
        db 'GetStdHandle', 0
        align 2
hn_wf:  dw 0
        db 'WriteFile', 0
        align 2
%endif
hn_exit: dw 0
        db 'ExitProcess', 0
dll_k32: db 'KERNEL32.dll', 0
%ifdef GUI
dll_user: db 'USER32.dll', 0
%endif
        align 4
image_end:
