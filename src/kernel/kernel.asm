org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
    jmp main

;
; Prints a string to the screen,
; expects DS:SI to point to the string
;

puts: 
    ;save registers we will modify
    push si 
    push ax

.loop:
    lodsb              ; loads next character in al
    or al, al          ; check for null terminator
    jz .done           ; if null, we're done

    mov ah, 0x0E      ; BIOS teletype function
    mov bh, 0         ; page number
    int 0x10          ; call BIOS

    jmp .loop         ; repeat for next character

.done:
    pop ax
    pop si
    ret 

main: 

    ; setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00

    ; print message
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

msg_hello: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0
dw 0xAA55