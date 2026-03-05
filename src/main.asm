section .data
    cells        times 1024 db 0   ; Array of 1024 unsigned 8-bit integers
    fileContents times 1024 db 0   ; Buffer to store the raw instructions from the file
    file_path    dd 0              ; Pointer to the command line argument string
    path_len     dd 0              ; Length of the file path string
    file_desc    dd 0              ; File descriptor returned by the system
    file_size    dd 0              ; Total bytes read from the file
    cellPointer  dd 0              ; Index (0-1023) pointing to the current active cell
    
    ; Variables for display_cells
    space        db ' '            ; Space character for formatting
    newline      db 10             ; Newline character for formatting
    temp_buf     times 4 db 0      ; Temporary buffer for number-to-string conversion

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
    mov esi, 0          ; Instruction pointer

process_loop:
    cmp esi, [file_size]
    je finish_processing

    mov al, [fileContents + esi]
    
    ; Logic for instruction parsing
    cmp al, '+'
    je increment_cell
    cmp al, '-'
    je decrement_cell
    cmp al, '>'
    je increment_pointer
    cmp al, '<'
    je decrement_pointer
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
    cmp eax, 1024       ; Check if we went past the last index (1023)
    jne .save           ; If not 1024, it's fine
    xor eax, eax        ; If 1024, wrap back to 0
.save:
    mov [cellPointer], eax
    jmp next_char

decrement_pointer:
    mov eax, [cellPointer]
    dec eax
    cmp eax, -1         ; Check if we went below the first index (0)
    jne .save           ; If not -1, it's fine
    mov eax, 1023       ; If -1, wrap to 1023
.save:
    mov [cellPointer], eax
    jmp next_char

next_char:
    inc esi
    jmp process_loop

finish_processing:
    call display_cells  ; Display the state of the first 10 cells

exit_program:
    mov eax, 1          
    mov ebx, 0
    int 0x80

error_exit:
    mov eax, 1
    mov ebx, 1
    int 0x80

; --- Function: display_cells ---
; Iterates through the first 10 entries of 'cells' and prints them to stdout
display_cells:
    mov ecx, 0          ; Loop counter (0 to 9)
display_loop:
    push ecx            
    movzx eax, byte [cells + ecx]
    mov edi, temp_buf + 3 
    mov byte [edi], 0     
    mov ebx, 10           
.convert:
    dec edi
    xor edx, edx
    div ebx               
    add dl, '0'           
    mov [edi], dl
    test eax, eax
    jnz .convert
    mov edx, temp_buf + 3
    sub edx, edi          
    mov eax, 4            
    mov ebx, 1            
    mov ecx, edi          
    int 0x80
    mov eax, 4
    mov ebx, 1
    mov ecx, space
    mov edx, 1
    int 0x80
    pop ecx               
    inc ecx
    cmp ecx, 10
    jl display_loop
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 0x80
    ret
