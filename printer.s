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

; 1st = argument to print, 2nd = format
%macro drones_printf 2
    pushad
    push    %1                         ; push string agrument on stack
    push    %2                         ; format_string
    call    printf                     ; printf(%2, %1)
    add      esp ,8                    ; remove fun arguments of stack
    popad
%endmacro


; update drone_index
%macro update_drone_index 0
        pushad
        inc dword[drone_index]                          ; index ++
        mov ebx,dword[drone_num]
        cmp dword[drone_index], ebx                     ; if index is valid
        jne %%skip                                      ; continue
        mov dword[drone_index], 0                       ; set index =0
        %%skip:
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


; 1st - 6th: argument to print, 7thd: format
%macro push_float_printing 1
    mov edi, dword[%1]
    mov     dword[float_tmp], edi
    fld     dword[float_tmp]        
    fstp    qword[float_printer_arg]       
    push    dword[float_printer_arg +  4]
    push    dword[float_printer_arg]
%endmacro


section .bss
        
section .data
        float_tmp:                  dd 0.0      ; will hold tmp float for printing
        

section	.rodata
        format_target:              db "%.2f,%.2f", 10, 10,0                                        ; "x,y"
        format_msg:                 db "%d, %.2f, %.2f, %.2f, %.2f, %d", 10, 0                      ; string for end of game
        msg_printer:                db "x     y", 0 
        msg_out_printer:            db " ",10, 0 
        format_string:              db "%s", 10, 0	                                                ; format string_string               
        msg_start_print:            db "                   PRINT", 0 
        format_score_decimal:       db "drone score: %d", 10, 0                                     ; format string_int
        debug_format_print_loop:    db "index, x, y,    alpha, speed, numOfDestroyedTargets", 0

section .text
    global printer_exec
    align 16
    global printer_function
    global prepare_print_loop
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
    extern cycles_num
    extern print_k
    extern drone_num
    extern printer
    extern drone_arr
    extern active_drones_num
    extern float_printer_arg
    extern target
    extern resume
    extern scheduler
    
   
printer_exec:
        drones_printf msg_start_print, format_string        ; welcome message
        drones_printf msg_printer, format_string            ; "x, y"
        
        print_target:
            mov esi, dword[target]
            push_float_printing (esi + cor_y_loc)           ; push target_x on stack
            push_float_printing (esi + cor_x_loc)           ; push target_y on stack
            push format_target 
            call printf                                     ; printf(...)
            add esp, 20                                     ; clean stack
        

        prepare_print_loop:
            mov edx, dword[drone_arr]                       ; edx = drone_arr[0]
            xor ecx, ecx                                    ; i=0   
        drones_printf debug_format_print_loop , format_string ;table headers print     
        
        check_if_active:
            mov eax, dword[edx + 4*ecx]                     ; eax = drone (i+1)th adress
            cmp eax, 0                                      ; is drone diactivated
            je prepare_next_drone_print

        print_drone_loop:
            pushad
            push                dword[eax + drone_score]    ; push drone_score            
            push_float_printing (eax + drone_speed)         ; push drone_speed
            push_float_printing (eax + drone_headings)      ; push drone_headings
            push_float_printing (eax + cor_y_loc)           ; push cor_y_loc
            push_float_printing (eax + cor_x_loc)           ; push cor_x_loc
            push                dword[eax+ drone_id]        ; push drone_id
            push                format_msg                  ; push format
            call                printf                      ; printf(...)
            add                 esp,  44                    ; clean stack
            popad
            
        prepare_next_drone_print:
            inc ecx                                         ; i++
            cmp ecx, dword[drone_num]                       ; check if more drones need to be printed
            jne check_if_active                             ; repeat process 
        
        finish_co_routine_run: 
            drones_printf msg_out_printer, format_string    ; finish printer printing 
            mov ebx,dword[scheduler]                        ; prepare for calling scheduler co-routine
            call resume                                     ; resume to scheduler
        jmp printer_exec                                    ; repeat process            
