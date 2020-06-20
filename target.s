
;;structs sizes:
scheduler_size equ 12
printer_size equ 12
target_size equ 20
drone_size equ 36
;;stackCo offsets
cor_CODEP equ 0
cor_SPP equ 4
cor_ST_START equ 8
;;additional offsets
cor_x_loc equ 12
cor_y_loc equ 16
drone_speed equ 20
drone_headings equ 24
drone_score equ 28
drone_id            equ 32
;;additional values
MAX_INT             equ 2147483647
MAX_WORD            equ 65535
STK_SIZE            equ 16*1024





; 1st - 6th: argument to print, 7thd: format
%macro push_float_printing 1
    mov edi, dword[%1]
    mov     dword[float_tmp], edi
    fld     dword[float_tmp]        
    fstp    qword[float_printer_arg]       
    push    dword[float_printer_arg +  4]
    push    dword[float_printer_arg]
%endmacro

; 1st = argument to print, 2nd = format
%macro drones_printf 2
    pushad
    push    %1                         ; push string agrument on stack
    push    %2                         ; format_string
    call    printf                     ; printf(%2, %1)
    add      esp ,8                    ; remove fun arguments of stack
    popad
%endmacro

%macro startFunc 0
    push ebp
    mov ebp, esp 
%endmacro

%macro endFunc 0
    mov esp, ebp	
	pop ebp
	ret
%endmacro




section .bss
    
section .data
    x_var:                      dd 0.0
    y_var:                      dd 0.0
    float_tmp:                  dd 0.0                                      ; will hold tmp float for printing
    lfsr_curr                   dd  0                                               ; inital current for lfsr
    
section	.rodata    
    msg_target:                 db "-> target()", 0
    debug_msg_create_target:    db "       -> create target()",10, 0  
    format_string:              db "%s", 10, 0	                                    ; format string_string              
    format_float:               db "%.2f", 10, 0	                                    ; format string_string              
    debug_format_x_y:           db "DEBUG -> target x: %.2f, y: %.2f",10, 10, 0 
    
section .text
    global createTarget
    global target_exec
    align 16
    extern stdout
    extern stdin
    extern stderr
    extern printf
    extern fprintf
    extern sscanf  
    extern fflush
    extern malloc 
    extern calloc 
    extern free
    extern generate_new_target
    extern CURR
    extern get_random_scaled_num
    extern scaled_result
    extern target
    extern resume
    extern scale_low
    extern scale_high
    extern float_printer_arg
    extern curr_killer


target_exec:
    call createTarget
    
    mov ebx,dword[curr_killer]                      ; ebx hold's pointer to drone that destroyed the target
    call resume                                     ; resume control to the destroying drone
    jmp target_exec

createTarget:   
    startFunc                                           ;push board size as arg for scaled num func
    
    set_x_target:
        mov     esi, dword[target]                      ; esi = target adress
        mov     dword[scale_high],100                   ; set range
        mov     dword[scale_low],0                      ; set range
        call    get_random_scaled_num                   ; call get random
        mov     edx,dword[scaled_result]                ; edx = result
        mov dword[esi + cor_x_loc],edx                  ; set new x coordinate

    set_y_target:
        
        mov     dword[scale_high],100                   ; set range
        mov     dword[scale_low],0                      ; set range
        call    get_random_scaled_num                   ; callget random
        mov     edx,dword[scaled_result]                ; edx = result
        mov     dword[esi + cor_y_loc],edx              ; set new y coordinate

    endFunc                                             ; return to target_exec




