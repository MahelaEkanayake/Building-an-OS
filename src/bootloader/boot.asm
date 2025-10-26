org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 header
;
jmp short start
nop

bdb_oem:                        db 'MSWIN4.1'        ; 8 bytes
bdb_bytes_per_sector:           dw 512               ; bytes per sector
bdb_sectors_per_cluster:        db 1                 ; sectors per cluster
bdb_reserved_sectors:           dw 1                 ; reserved sectors
bdb_fat_count:                  db 2                 ; number of FATs
bdb_dir_entries_count:          dw 0E0h              ; max root dir entries
bdb_total_sectors:              dw 2880              ; total sectors
bdb_media_descriptor_type:      db 0F0h              ; media descriptor
bdb_sectors_per_fat:            dw 9                 ; sectors per FAT
bdb_sectors_per_track:          dw 18                ; sectors per track
bdb_heads:                       dw 2                 ; number of heads
bdb_hidden_sectors:             dd 0                 ; hidden sectors
bdb_large_sector_count:         dd 0                 ; large sector count

; extended boot record
ebr_drive_number:               db 0                 ; 0x00 floppy, 0x80 hard disk
ebr_reserved:                   db 0                 ; reserved
ebr_signature:                  db 29h               ; extended boot signature
ebr_volume_id:                  db 12h, 34h, 56h, 78h   ; volume ID
ebr_volume_label:               db 'MY OS      '           ; volume label (11 bytes)
ebr_system_id:                  db 'FAT12  '        ; file system type (7 bytes)

; 
; Bootloader code starts here
;

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

    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], 

    mov ax, 1          ; LBA=1, second sector from disk
    mov cl, 1          ; 1 sector to read
    mov bx, 0x7E00     ; data should be after the bootloader
    call disk_read

    ; print message
    mov si, msg_hello
    call puts

    cli                 ; disable interrupts, this way CPU can't get out of "halt" state
    hlt

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h            ; wait for key press
    jmp 0FFFFH:0000h   ; jump to begginning of the BIOS, should reboot

.halt:
    cli                 ; disable interrupts, this way CPU can't get out of "halt" state
    hlt

;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   * ax - LBA Address
; Returns:
;   * cx - Cylinder and Sector (bits 15-6: Cylinder, bits 5-0: Sector)
;   * dx - Head
;

lba_to_chs:
    
    push ax
    push dx

    xor dx, dx                          ; clear dx (head)
    div word [bdb_sectors_per_track]    ; ax = LBA / Sectors per Track, 
                                        ; dx = LBA % Sectors per Track
    
    inc dx                              ; dx = (LBA % Sectors per Track) + 1 (Sector number starts from 1
    mov cx, dx                          ; cx = sector 

    xor dx, dx                          ; clear dx (head)
    div word [bdb_heads]                ; ax = (LBA / Sectors per Track) / Heads = Cylinder
                                        ; dx = (LBA / Sectors per Track) % Heads = Head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6                          
    or cl, ah                           ; put upper 2 bits of cylinder into CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret

;
; Reads sectors from a disk
; Parameters:
;   * ax - LBA address
;   * cl - number of sectors to read (up to 128)
;   * dl - drive number
;   * es:bx - memory address where to store read data
;

disk_read:

    push ax                  ; temporarily save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                 ; temporarily save CL (number of sectors to read)
    call lba_to_chs         ; convert LBA to CHS
    pop ax                  ; AL = number of sectors to read

    mov ah, 02h             
    mov di, 3               ; retry count

.retry:
    pusha                   ; save all registers. The BIOS call may modify them
    stc                     ; set carry flag, some BIOSes don't set it
    int 13h                 ; carry flag cleared = success
    jnc .done               ; jump if no carry (success)

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa

    pop di                 ; restore registers we modified
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;
; Resets disk controller
; Parameters:
;   * dl - drive number
;

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_hello:          db 'Hello World!', ENDL, 0
msg_read_failed:    db 'Disk Read Failed!', ENDL, 0

times 510-($-$$) db 0
dw 0xAA55