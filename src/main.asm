section .data
    cells        times 1024 db 0   ; Array of 1024 unsigned 8-bit integers
    fileContents times 1024 db 0   ; Buffer to store the raw instructions from the file
    file_path    dd 0              ; Pointer to the command line argument string
    path_len     dd 0              ; Length of the file path string
    file_desc    dd 0              ; File descriptor returned by the system
    file_size    dd 0              ; Total bytes read from the file
    cellPointer  dd 0              ; Index (0-1023) pointing to the current active cell
    pointer_storage dd 0           ; Stores 32-bit address for ECX syscalls

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
    cmp al, '&'
    je set_ecx_pointer
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

set_ecx_pointer:
    ; Calculate actual memory address of the current cell
    mov ebx, cells
    add ebx, [cellPointer]
    mov [pointer_storage], ebx
    jmp next_char

trigger_syscall:
    ; We MUST save all registers that the interpreter uses
    ; ESI is our program counter. EBX is often used for indexing.
    push esi
    push ebx

    ; Map cells 0, 1, 3, 4, 5, 6 to registers
    ; We SKIP cell 2 because ECX is handled by the '&' pointer_storage
    movzx eax, byte [cells + 0]    ; syscall number (e.g., 4 for write)
    movzx ebx, byte [cells + 1]    ; arg 1 (e.g., 1 for stdout)
    movzx ecx, byte [cells + 2]     ; arg 2 (The pointer we saved with '&')
    movzx edx, byte [cells + 3]    ; arg 3 (e.g., length)
    movzx esi, byte [cells + 4]    ; arg 4
    movzx edi, byte [cells + 5]    ; arg 5
    movzx ebp, byte [cells + 6]    ; arg 6

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
