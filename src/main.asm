section .data
    cells        times 1024 db 0   ; Array of 1024 unsigned 8-bit integers
    fileContents times 1024 db 0   ; Buffer to store the raw instructions from the file
    file_path    dd 0              ; Pointer to the command line argument string
    path_len     dd 0              ; Length of the file path string
    file_desc    dd 0              ; File descriptor returned by the system
    file_size    dd 0              ; Total bytes read from the file
    cellPointer  dd 0              ; Index (0-1023) pointing to the current active cell

section .text
    global _start

_start:
    ; Check argc
    mov eax, [esp]
    cmp eax, 2
    jl error_exit

    ; Store pointer to argv[1]
    mov ebx, [esp + 8]
    mov [file_path], ebx

    ; --- Calculate string length ---
    mov edi, ebx
    mov ecx, 0
count_loop:
    cmp byte [edi], 0
    je count_done
    inc edi
    inc ecx
    jmp count_loop
count_done:
    mov [path_len], ecx

    ; --- Open the file ---
    mov eax, 5          ; sys_open
    mov ebx, [file_path]
    mov ecx, 0          ; O_RDONLY
    int 0x80

    cmp eax, 0
    jl error_exit
    mov [file_desc], eax

    ; --- Read from the file ---
    mov eax, 3          ; sys_read
    mov ebx, [file_desc]
    mov ecx, fileContents
    mov edx, 1024
    int 0x80

    ; Check for read error
    cmp eax, 0
    jl error_exit
    
    ; Store the number of bytes actually read
    mov [file_size], eax

    ; --- Close the file ---
    mov eax, 6          ; sys_close
    mov ebx, [file_desc]
    int 0x80

    ; --- Process fileContents ---
    mov esi, 0          ; Instruction pointer (ESI is our program counter)

process_loop:
    cmp esi, [file_size]
    je exit_program

    mov al, [fileContents + esi]
    
    cmp al, '+'
    je increment_cell
    cmp al, '-'
    je decrement_cell
    cmp al, '>'
    je increment_pointer
    cmp al, '<'
    je decrement_pointer
    cmp al, '['
    je loop_start
    cmp al, ']'
    je loop_end
    cmp al, '.'
    je trigger_syscall
    jmp next_char

increment_cell:
    mov ebx, [cellPointer]
    inc byte [cells + ebx]
    jmp next_char

decrement_cell:
    mov ebx, [cellPointer]
    dec byte [cells + ebx]
    jmp next_char

increment_pointer:
    mov eax, [cellPointer]
    inc eax
    cmp eax, 1024
    jne .save
    xor eax, eax
.save:
    mov [cellPointer], eax
    jmp next_char

decrement_pointer:
    mov eax, [cellPointer]
    dec eax
    cmp eax, -1
    jne .save
    mov eax, 1023
.save:
    mov [cellPointer], eax
    jmp next_char

loop_start:
    ; If current cell is zero, skip forward to matching ']'
    mov ebx, [cellPointer]
    cmp byte [cells + ebx], 0
    jne next_char

    mov edx, 1
.find_match_forward:
    inc esi
    cmp esi, [file_size]
    je error_exit

    mov al, [fileContents + esi]
    cmp al, '['
    je .inc_depth
    cmp al, ']'
    je .dec_depth
    jmp .find_match_forward

.inc_depth:
    inc edx
    jmp .find_match_forward

.dec_depth:
    dec edx
    cmp edx, 0
    jne .find_match_forward
    jmp next_char

loop_end:
    ; If current cell is non-zero, jump back to matching '['
    mov ebx, [cellPointer]
    cmp byte [cells + ebx], 0
    je next_char

    mov edx, 1
.find_match_backward:
    dec esi
    cmp esi, -1
    je error_exit

    mov al, [fileContents + esi]
    cmp al, ']'
    je .inc_depth
    cmp al, '['
    je .dec_depth
    jmp .find_match_backward

.inc_depth:
    inc edx
    jmp .find_match_backward

.dec_depth:
    dec edx
    cmp edx, 0
    jne .find_match_backward
    jmp next_char

trigger_syscall:
    ; We MUST save all registers that the interpreter uses
    ; ESI is our program counter. EBX is often used for indexing.
    push esi
    push ebx

    ; First 28 bytes are 7 little-endian 32-bit registers:
    ; EAX cells[0..3], EBX cells[4..7], ECX cells[8..11], EDX cells[12..15],
    ; ESI cells[16..19], EDI cells[20..23], EBP cells[24..27].
    ; Pointer convention (for args only): if bit 31 is set, treat the value
    ; as a tape index and convert it to an address: cells + (value & 1023).
    mov eax, [cells + 0]
    mov ebx, [cells + 4]
    mov ecx, [cells + 8]
    mov edx, [cells + 12]
    mov esi, [cells + 16]
    mov edi, [cells + 20]
    mov ebp, [cells + 24]

    test ebx, 0x80000000
    jz .ebx_ready
    and ebx, 1023
    add ebx, cells
.ebx_ready:
    test ecx, 0x80000000
    jz .ecx_ready
    and ecx, 1023
    add ecx, cells
.ecx_ready:
    test edx, 0x80000000
    jz .edx_ready
    and edx, 1023
    add edx, cells
.edx_ready:
    test esi, 0x80000000
    jz .esi_ready
    and esi, 1023
    add esi, cells
.esi_ready:
    test edi, 0x80000000
    jz .edi_ready
    and edi, 1023
    add edi, cells
.edi_ready:
    test ebp, 0x80000000
    jz .ebp_ready
    and ebp, 1023
    add ebp, cells
.ebp_ready:

    int 0x80                       ; Execute Syscall

    ; Restore our interpreter state
    pop ebx
    pop esi
    jmp next_char

next_char:
    inc esi
    jmp process_loop

exit_program:
    mov eax, 1          
    mov ebx, 0
    int 0x80

error_exit:
    mov eax, 1
    mov ebx, 1
    int 0x80
