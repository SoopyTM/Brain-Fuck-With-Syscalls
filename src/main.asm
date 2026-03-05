section .data
    my_array times 1024 db 0
    fileContents times 1024 db 0
    file_path dd 0
    path_len  dd 0
    file_desc dd 0

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
    mov ebx, [file_desc] ; file descriptor
    mov ecx, fileContents ; destination buffer
    mov edx, 1024       ; maximum bytes to read
    int 0x80

    ; Check if read failed
    cmp eax, 0
    jl error_exit
    
    ; Store actual number of bytes read (returned in EAX)
    ; We'll use this for the write call so we don't print 1024 bytes of junk
    mov edx, eax        

    ; --- Output file contents to terminal ---
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, fileContents
    ; edx already contains the number of bytes read from the previous step
    int 0x80

    ; --- Close the file ---
    mov eax, 6          ; sys_close
    mov ebx, [file_desc]
    int 0x80

exit_program:
    mov eax, 1          
    mov ebx, 0
    int 0x80

error_exit:
    mov eax, 1
    mov ebx, 1
    int 0x80
