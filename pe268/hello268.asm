; Experiment B, step 3: Hello World inside the 268-byte file itself. Same header as tiny268.exe;
; the code lives in two holes the loader does not read:
;   0x0C-0x17  TimeDateStamp, PointerToSymbolTable, NumberOfSymbols (12 bytes)
;   0x8C-0x10B the 16 data directories, unused because NumberOfRvaAndSizes = 0 (128 bytes),
;              except the import RVA at 0x94-0x97: on the first run of a new file Windows reads it
;              anyway (a non-zero value crashes that run), so the 4 zero bytes of 'push 0' land there.
; also 0x1E-0x2B (linker version and the SizeOf* fields, 14 bytes).
; Build: nasm -f bin -o v3.exe v3.asm
BITS 64
DEFAULT REL
f:
        db 'MZ', 0, 0
        db 'PE', 0, 0
        dw 0x8664                       ; 0x08 Machine
        dw 0                            ; 0x0A NumberOfSections
start:                                  ; 0x0C
        push 0x60
        pop rsi
        gs lodsq                        ; rax = PEB
        mov rbx, [rax+0x20]             ; ProcessParameters
        jmp short part2
        times 0x18-($-f) db 0           ; (error here if the chunk is too long)
        dw 0xF0                         ; 0x18 SizeOfOptionalHeader
        dw 0x0022                       ; 0x1A Characteristics
        dw 0x020B                       ; 0x1C Magic PE32+
part2:                                  ; 0x1E linker version, SizeOfCode, SizeOf(Un)InitializedData
        mov rax, [rax+0x18]             ; Ldr
        mov rax, [rax+0x20]             ; the exe
        mov rax, [rax]                  ; ntdll
        jmp short part3
        times 0x2C-($-f) db 0           ; (error here if the chunk is too long)
        dd start                        ; 0x2C AddressOfEntryPoint
        times 0x34-($-f) db 0
        dq 0x140000000                  ; 0x34 ImageBase
        dd 4                            ; 0x3C SectionAlignment = e_lfanew
        dd 4                            ; 0x40 FileAlignment
        times 0x4C-($-f) db 0
        dw 6, 0                         ; 0x4C subsystem version
        times 0x54-($-f) db 0
        dd 0x200                        ; 0x54 SizeOfImage
        times 0x60-($-f) db 0
        dw 3                            ; 0x60 Subsystem: console
        times 0x64-($-f) db 0
        dq 0x100000, 0x1000, 0x100000, 0x1000
        dd 0                            ; 0x84 LoaderFlags
        dd 0                            ; 0x88 NumberOfRvaAndSizes = 0
part3:                                  ; 0x8C                                  ; 0x8C
        mov rax, [rax]                  ; kernel32
        mov rbp, [rax+0x20]             ; kernel32 base
        db 0x68, 0, 0, 0, 0             ; push 0 (imm32 form) 0x93: 68 00000000, the zeros are the import RVA; 5th argument lpOverlapped = NULL
        sub rsp, 0x20                   ; shadow space; rsp is 16-byte aligned now
        mov eax, [rbp+0x3C]
        mov edx, [rbp+rax+0x88]         ; export directory
        add rdx, rbp
        mov ecx, [rdx+0x18]             ; NumberOfNames
        mov r8d, [rdx+0x20]             ; AddressOfNames
        add r8, rbp
.find:  dec ecx
        mov esi, [r8+rcx*4]
        cmp dword [rbp+rsi+6], 0x00656C69   ; "ile\0" at name+6: only WriteFile
        jne .find
        mov esi, [rdx+0x24]             ; AddressOfNameOrdinals
        add rsi, rbp
        movzx ecx, word [rsi+rcx*2]
        mov esi, [rdx+0x1C]             ; AddressOfFunctions
        add rsi, rbp
        mov eax, [rsi+rcx*4]
        add rax, rbp
        mov rcx, [rbx+0x28]             ; StandardOutput
        lea rdx, [msg]
        push msg_len
        pop r8
        lea r9, [rsp+0x30]              ; lpNumberOfBytesWritten: our own home slot above the return address
        call rax
        xor eax, eax                    ; exit code 0
        add rsp, 0x28
        ret
msg:    db 'Hello, World!', 13, 10
msg_len equ $ - msg
        times 268-($-f) db 0            ; (error here if the code is too long)
