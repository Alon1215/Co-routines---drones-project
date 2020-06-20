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

%macro push_float_printing 1
    fld  dword[%1]        
    sub esp,8
    fstp qword [esp]
%endmacro

%macro debug_print_location 0
        pushad
        push_float_printing (ebx + cor_y_loc)
        push_float_printing (ebx + cor_x_loc)
        push debug_format_loc
        call printf
        add esp, 20
        popad
%endmacro

;;1st= float adress , 2nd = format
%macro drones_float_print 2
    pushad
    fld  dword[%1]        
    sub esp,8
    fstp qword [esp]
    push %2
    call printf
    add esp, 12
    popad
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

    global curr_killer
    temp_val_1:                 resd 1   
    mayDestroy_result:          resd 1                                                     
    curr_killer:                resd 1                          ;pointer to the latest killer drone (for target cour)
    


section .data
        
        speed_change:           dd 0.0                                  ; hold random speed change
        heading_change:         dd 0.0                                  ; hold random heading change
        max_speed:              dd 100.0
        min_speed:              dd 0.0
        max_heading:            dd 360.0
        angle_180:              dd 180.0
        min_heading:            dd 0.0
        max_location:           dd 100.0
        min_location:           dd 0.0

section	.rodata
        msg_drone:              db "-> drone()", 0                
        msg_drone_loop:         db "-> drone_loop()", 0                
        debug_format_calc:      db "    -> calc_distance: %.2f", 10, 0
        format_string:          db "%s", 10, 0                
        format_float:           db "%.2f", 10, 0
        debug_format_speed:     db "    -> speed: %.2f", 10, 0 
        debug_format_loc:       db "    -> location: %.2f, %.2f", 10, 0
        debug_format_id:        db "    -> active drone: %d", 10, 0
        debug_print_result:     db "    -> mayDestroy result: %d", 10, 10, 0
        debug_format_distance:  db "    -> distance from target: %.2f", 10, 0 

section .text
    global drone_exec
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
    extern scale_high
    extern scale_low
    extern target
    extern resume
    extern scheduler
    extern destroy_distance

drone_exec:
    call compute_new_loc
    call compute_new_delta
    
    drone_loop:
        
        destroy_attemp:
            call mayDestroy
            cmp dword[mayDestroy_result],1              ; check if may destroy
            jne update_location_n_delta                  ; if not, skip next label
        
            .kill_and_update_target:
                mov ebx,dword[CURR]
                inc dword[ebx + drone_score]            ; if mayDestroy() == true then kill and add to score!
                mov dword[curr_killer],ebx              ; update current killer to point at this drone
                mov ebx,dword[target]
                call resume                             ; resume target co_routine after killing

        update_location_n_delta:
            call compute_new_loc
            call compute_new_delta
            mov     ebx,dword[scheduler]                
            call    resume                              ; resume scheduler 
            jmp     drone_loop
        


    mayDestroy:
        startFunc
        mov         dword[mayDestroy_result], 0 ; set initial result (0)
            .print_debug:
                    mov     ebx,dword[CURR]
                    drones_printf dword[ebx + drone_id], debug_format_id                   ; //DEBUG - print id//
        
        calc_distance:
            mov     ebx,dword[target]
            fld     dword[ebx + cor_x_loc]      ; insert target x loc into x87 stack
            mov     ebx,dword[CURR]
            fsub    dword[ebx + cor_x_loc]      ; ST(0) = (target_xloc - drone_xloc)
            fst     dword[temp_val_1]           ; temp_val_1 = (target_xloc - drone_xloc)
            fmul    dword[temp_val_1]           ; ST(0) = (target_xloc - drone_xloc)^2
            fld     dword[ebx + cor_y_loc]      ; insert CURR drone y loc into x87 stack at ST(0)
            mov     ebx,dword[target]           ; ebx = target adress
            fsub    dword[ebx + cor_y_loc]      ; ST(0) =  (drone_y - target_y)
            fst     dword[temp_val_1]           ; temp_val_1 = (drone_y - target_y)
            fmul    dword[temp_val_1]           ; ST(0) = (target_y - drone_y)^2 and ST(1) = (target_xloc - drone_xloc)^2
            faddp                               ; ST(0) = target_y - drone_y)^2 + (target_xloc - drone_xloc)^2
            fsqrt                               ; ST(0) = root(target_y - drone_y)^2 + (target_xloc - drone_xloc)^2) = distance
            fst     dword[temp_val_1]           ; temp_val_1 = distance (DEBUG)
            
            drones_float_print temp_val_1, debug_format_distance             ; //DEBUG - print distance from target//
            
            fld     dword[destroy_distance]     ; load destroy_distance
            fcomip                              ; compare ST(0) = destroy_distance with ST(1) = drone target distance and pop both
            jb      .skip_kill
            mov     dword[mayDestroy_result], 1 ; set result 1
            
            
            .skip_kill:
                fstp dword[temp_val_1]
            drones_printf dword[mayDestroy_result], debug_print_result         ; //DEBUG - print result of attemp//
        
        endFunc
        

    generate_new_alpha: 
        startFunc
        .speed:
            mov     dword[scale_high],10
            mov     dword[scale_low],-10
            call    get_random_scaled_num 
            fld     dword[scaled_result]
            fstp    dword[speed_change]
        .heading:
            mov     dword[scale_high],60
            mov     dword[scale_low],-60
            call    get_random_scaled_num 
            fld     dword[scaled_result]
            fstp    dword[heading_change]
        endFunc


    compute_new_loc:
        startFunc
        call generate_new_alpha                     ; genereate new alpha

        .convert_headings_to_radian:
            mov     ebx,dword[CURR]
            fld     dword[ebx + drone_headings]     ; load angle to x87 stack
            fdiv    dword[angle_180]                ; divide angle by 180
            fldpi                                   ; load pi to stack
            fmulp                                   ; ST(0) = (heading / 180) * pi =< angle in radians
            fsincos                                 ; now ST(0) = cos(heading)  ST(1) = sin(heading)

        .calc_x_loc:

            fld     dword[ebx + drone_speed]        ; insert speed to stack            
            fmulp                                   ; ST(0) = cos(heading) * speed, ST(1) = sin(heading)
            fld     dword[ebx + cor_x_loc]
            faddp                                   ; ST(0) = (cos(heading) * speed + curr_x), ST(1) = sin(heading)
            .check_x_above_100:
                fld     dword[max_location]               
                fcomip                              ; check if passed 100
                jae     .check_x_below_0
                fsub    dword[max_location]         ; subsract 100 from x_loc
                jmp     .finish_update_x
                
            .check_x_below_0:
                fld     dword[min_location] 
                fcomip
                jbe     .finish_update_x
                fadd    dword[max_location]         ; if below 0 add 100    
            
            .finish_update_x:
                fstp    dword[ebx + cor_x_loc]      ; first update x_loc, now ST(0) = sin(heading)
        
        .calc_y_loc:
            
            fld     dword[ebx + drone_speed]
            fmulp                                   ; now ST(0) = sin(heading) * speed, 
            fld     dword[ebx + cor_y_loc]
            faddp                                   ; now ST(0) = (cos(heading) * speed + curr_y) 
            
            .check_y_above_100:    
                fld     dword[max_location]
                fcomip                                      ; check if passed 100
                jae     .check_y_below_0
                fsub    dword[max_location]                 ; subsract 100 from y_loc
                jmp     .finish_update_y
                
            .check_y_below_0:
                fld     dword[min_location] 
                fcomip 
                jbe     .finish_update_y
                fadd    dword[max_location]           ; if below 0 add 100

            .finish_update_y:
                fstp dword[ebx + cor_y_loc]
  
            endFunc

    compute_new_delta:
        startFunc
        speed:                                      ; add speed change to current speed, and if exceeded range fix accordingly
            mov     ebx,dword[CURR]
            fld     dword[ebx + drone_speed]            ; ST(0) = current speed
            fld     dword[speed_change]                 ; ST(0) = alpha speed
            faddp                                       ; ST(0) = newly speed (tmp)
            
            .check_if_above_100:
                fld     dword[max_speed]
                fcomip                                   ; cmp with 100                               
                jae     .check_if_under_zero            ; check 2nd case
                fld     dword[max_speed]                ; drone_speed = 100
                fstp    dword[ebx + drone_speed]        ; speed = 100
                fstp    dword[temp_val_1]               ; clean stack
                jmp     heading

            .check_if_under_zero:
                fldz
                fcomip                                  ; compare newly result to 0
                jbe     .update_speed                   ; if not, continue
                fld     dword[min_speed]                ; edx = 0
                fstp    dword[ebx + drone_speed]        ; new speed = zero
                fstp    dword[temp_val_1]               ; clean stack
                jmp     heading
            
            .update_speed:
                fstp     dword[ebx + drone_speed]        ; update speed

        heading:                                        ; add heading (angle) change to current headings, and if exceeded range fix accordingly
            fstp    dword[temp_val_1]                   ; pop the speed arg
            mov     ebx,dword[CURR]
            fld     dword[ebx + drone_headings]         ; ST(0) = current speed
            fld     dword[heading_change]               ; ST(0) = alpha speed
            faddp                                       ; ST(0) = newly speed (tmp)
            .check_if_above_360:
                fld     dword[max_heading]
                fcomip                                  ; cmp with 100
                jae     .check_if_under_zero            ; check 2nd case
                fsub    dword[max_heading]
                jmp     .update_heading
            
            .check_if_under_zero:
                fld     dword[min_heading]
                fcomip                                  ; compare newly result to 0
                jbe     .update_heading                 ; if not, continue
                fadd    dword[max_heading]
            
            .update_heading:
                fstp    dword[ebx + drone_headings]     ; update heading

        endFunc