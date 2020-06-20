
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



;;1st= buffer adress , 2nd = format 3th= argument adress
%macro drones_sscanf 3
    pushad
    push    %3      ; push argument adress
    push    %2      ; push format
    push    %1      ; push buffer adress 
    call sscanf     ; sscanf(buffer, format, argument)
    add esp, 12
    popad
    
%endmacro



;;1st= float adress , 2nd = format
%macro drones_float_print 2
    pushad
    fld  dword[%1]        
    fstp qword[float_printer_arg]       
    push dword[float_printer_arg +  4]
    push dword[float_printer_arg ]
    push %2
    call printf
    add esp, 12
    popad
%endmacro 

;;1st = register, 2nd = size (in bytes)
%macro allocate_space 2
    pushad
    push %2
    ;push 1
    call malloc
    add esp, 4
    mov    dword[new_cor_address],eax
    popad
    mov %1, dword[new_cor_address]
%endmacro    



;1st=drone_addrr,2nd = ID
%macro init_drone 2
    pushad  
    
    ;;setup struct:
    ;mov     dword[new_cor_address],%1
    mov     dword[%1 + drone_id],%2                           ; set ID
    mov     dword[%1+ cor_CODEP],drone_exec                   ; set func pointer  
    
    
    ;;set location of drone:
    mov     dword[scale_high],100                           ; set bound = 100 
    mov     dword[scale_low],0                              ; set scale = 0
    call    get_random_scaled_num
    mov     edx,dword[scaled_result]                        ; edx holds new scaled random number
    mov     dword[%1 + cor_x_loc] ,edx                      ; set new y loc
    call    get_random_scaled_num                                                  
    mov     edx,dword[scaled_result]                        ; edx holds new scaled random number
    mov     dword[%1 + cor_y_loc] ,edx                      ; set new x loc
     
    
    ;;set speed
    call    get_random_scaled_num
    mov     edx,dword[scaled_result]                            ; edx holds new scaled random number
    mov     dword[%1 + drone_speed],edx                         ; set drone speed
    
    
    ;;set heading
    mov     dword[scale_high],360                               
    mov     dword[scale_low], 0
    call    get_random_scaled_num
    mov     edx,dword[scaled_result]                           ; edx holds new scaled random number
    mov     dword[%1+ drone_headings],edx                      ;set heading angle 
    
    ;;set score & id
    mov     dword[%1 + drone_score], 0                        ;set score = 0 (maybe not neccasary due to calloc)
    mov     dword[%1 + drone_id],   %2                        ;set drone ID                  
 
%endmacro
;1st = cour struct pointer
%macro initCo 1
    pushad
    allocate_space edx, STK_SIZE                          ;allocate space for stack
    mov dword[%1 + cor_ST_START],edx                       ;save pointer to beginning of dynamic stack (for freeing )
    add edx, STK_SIZE                                     ;make edx point to end of stack (because we are writing from the top -> down)
    mov dword[%1 + cor_SPP],edx                           ;update stack pointer      
    mov  ebx,%1
    mov  eax,[ebx+cor_CODEP]        ;get initial EIP value - pointer to Cour func
    mov  [SPT],ESP                  ;save esp value
    mov esp, [ebx+cor_SPP]          ;get initial ESP value - pointer to cour stack
    push eax                        ;push initial "return" new_cor_address
    pushfd
    pushad
    mov [ebx + cor_SPP],esp         ;save new esp Stack pointer value (after all the pushes)
    mov esp,[SPT]                   ;restore esp value to previous one
    popad
    
%endmacro
    

; 1st = argument to print, 2nd = format
%macro drones_printf 2
    pushad
    push    %1                         ; push string agrument on stack
    push    %2                         ; format_string
    call    printf                     ; printf(%1, %2)
    add      esp ,8                    ; remove fun arguments of stack
    popad
%endmacro

; 1st = argument to print, 2nd = format, 3rd = file pointer
%macro drones_fprintf 3
    pushad
    push    %1                          ; push string agrument on stack
    push    %2                          ; format_string
    push    %3                          ; file pointer
    call    fprintf                     ; fprintf(...)
    add      esp ,12                    ; remove fun arguments of stack
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
    global drone_num
    global drone_arr
    global print_k
    global seed
    global target
    global printer
    global scheduler
    global CURR
    global SPMAIN
    global cycles_R
    global active_drones_num
    global scaled_result
    global scale_low
    global scale_high
    


    drone_num:              resd 1                      ; will hold amount of drones (param of main)
    print_k:                resd 1                      ; how many rounds between each print
    cycles_R:               resd 1                      ; amount of rounds between each elimintaion(param)
    
    seed:                   resd 1                      ; seed for initialization of LFSR shift register
    read_float_var:         resb 8                      ; max distance for legal destruction of target (float)
    drone_arr:              resd 1                      ; array for the bloody drones
    active_drones_num:      resd 1                      ; number of active in-game drones
    new_cor_address:        resd 1                      ; link adress (used for creating numbers)
    temp_float:             resd 1                      ; temp float var for x87 cals
    target_addres:          resd 1                      ; target adress
    SPT:                    resd 1                      ; temporary stack pointer
    SPMAIN:                 resd 1                      ; saves stack pointer of main
    CURR:                   resd 1                      ; saves curr co-routine working
    printer:                resd 1                      ; pointer to printer CoRoutine
    target:                 resd 1                      ; pointer to target CoRoutine
    scheduler:              resd 1                      ; pointer to scheduler CoRoutine
    scale_high:             resd 1                      ; represents boundry for scale
    scale_low:              resd 1                      ; represents boundry for scale
    scaled_result:          resd 1

section .data
    global destroy_distance
    global curr_state
    global float_printer_arg

    curr_state:           dw  0                       ; inital current for lfsr
    float_printer_arg:    dq 0.0
    destroy_distance:     dd 0.0                      ; max distance for legal destruction of target (float)

section	.rodata
    welcome_msg:                    db "Welcome to our game!" ,0                                ; calc_loop message
    exit_ungracefully_msg:          db "Not enougth arguments, good bye :(" ,0                  ; exit(1) message
    format_string:                  db "%s", 10, 0	                                            ; format string_string
    format_string_without_new_line: db "%s", 0
    format_decimal:                 db "%d", 10, 0                                              ; format string_int
    format_score_decimal:           db "drone score: %d", 10, 0                                 ; format string_int
    format_float:                   db "%.2f", 10, 0                                            ; format string_hexa
    format_float_without_new_line:  db "%f",0                                                   ; format string_hexa for first digit
    format_decimal_without_line:    db "%d", 0                                                  ; format string_int
    
    debug_msg_lfsr:                 db "DEBUG -> LFSR result: %u", 10, 0
    debug_msg_get_scale:            db "DEBUG -> get scale result: %.2f", 10, 10, 0
    debug_msg_destroy:              db "DEBUG -> destroy_distance input: %.2f", 10, 10, 0
    debug_msg_iniCO:                db "init 1 -> init Co", 0
    debug_msg_initDrone:            db "init 2 -> init drone array", 0
    debug_msg_initscheduler:        db "init 3 -> init scheduler", 0
    debug_msg_initTarget:           db "init 4 -> init Target", 0
    debug_msg_initPrinter:          db "init 5 -> init printer", 0
    debug_msg_startCo:              db "init 6 -> StartCo                           START GAME!", 10, 0


section .text
  align 16
  global main
  global resume
  global generate_new_cordinates
  global get_random_scaled_num
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
  extern scheduler_exec
  extern drone_exec
  extern target_exec
  extern printer_exec
  extern createTarget



main:
    startFunc
    ;pushad
    drones_printf welcome_msg, format_string                            ; DEBUG ONLY
    ;some code
    finit                   ; init x87 stack



    parse_input:

        .check_argc:
            mov     eax, dword[ebp + 8]                     ; eax = argc 
            cmp     eax, 6                                  ; argc == 6
            jne     exit_ungracefully                       ; not enougth arguments
            mov     esi, dword[ebp + 12]                    ; esi = argv 
        
        .check_argv1:
            mov             ebx, dword[esi + 4]                                     ; ebx = argument[1] (ebx = string's adress)
            drones_sscanf   ebx, format_decimal_without_line, drone_num             ; scan string to find N

        .check_argv2:
            mov             ebx, dword[esi + 8]                                     ; ebx = argument[2] (ebx = string's adress)
            drones_sscanf   ebx, format_decimal_without_line, cycles_R              ; scan string to find R
        
        .check_argv3:
            mov             ebx, dword[esi + 12]                                    ; ebx = argument[3] (ebx = string's adress)
            drones_sscanf   ebx, format_decimal_without_line, print_k               ; scan string to find K
        
        .check_argv4:
            mov             ebx, dword[esi + 16]                                     ; ebx = argument[4] (ebx = string's adress)
            drones_sscanf   ebx, format_float_without_new_line, destroy_distance     ; scan string to find d
            
            ;drones_float_print destroy_distance, debug_msg_destroy
        .check_argv5:
            mov             ebx, dword[esi + 20]                                     ; ebx = argument[5] (ebx = string's adress)
            drones_sscanf   ebx, format_decimal_without_line, seed                   ; scan string to find Seed
            mov             ax, word[seed]
            mov             word[curr_state], ax

    
    alloc_co_routines:
    
        mov ebx,dword[drone_num]
        shl ebx,2
        allocate_space eax, ebx                             ; allocate space for drone arr
        mov ebx,dword[drone_num]
        mov dword[active_drones_num], ebx                   ; set initial number of active_drones
        mov dword[drone_arr],eax                            ; drone_arr var holds pointer to arr            
        
    allocate_drones_arr:
        
        mov ecx,dword[drone_num]                ; ecx = counter for init drone loop
        build_drone_arr:
            allocate_space eax,drone_size       ; allocate memory for drone i'th, ebx = adress
            init_drone eax,ecx                  ; init drone with id = i, ecx gets starting status (speed, location ,etc...)
            mov ebx, dword[drone_arr]           ; ebx = adress of array
            mov dword[ebx+(ecx*4)-4],eax        ; adress of drone is store in the respected place in array
            initCo eax                          ;initialize drone's stack (with flags and registers, and func pointer)
            dec ecx
            cmp ecx,0
            jne build_drone_arr
    
    init_scheduler:
        
        allocate_space eax,scheduler_size                       ;allocate space in memory for scheduler
        mov dword[eax + cor_CODEP],scheduler_exec               ;set scheduler's func pointer
        initCo eax                                              ;init scheduler's stack
        mov [scheduler],eax                                     ;save pointer to scheduler
    
        
    init_target:
        
        allocate_space eax,target_size                          ; same as scheduler
        mov dword[eax + cor_CODEP],target_exec
        initCo eax
        mov dword[target],eax
        call createTarget
    
    init_printer:                                               ; same as scheduler
        
        allocate_space eax,printer_size
        mov dword[eax + cor_CODEP],printer_exec
        initCo eax
        mov dword[printer],eax


    StartCo:                                                    ; start scheduling
        
        pushfd
        pushad                                                  ; save main's register
        mov dword[SPMAIN],esp                                   ; save esp of main
        mov ebx,dword[scheduler]                                ; ebx holds pointer to scheduler
        jmp do_resume                                           ; resume a scheduler co-routine


    at_exit:       
        popad
        endFunc
 
 


exit_ungracefully:
    drones_printf exit_ungracefully_msg, format_string      ; print error
    endFunc                                                 ; finish run

func_lsfr:
    startFunc
    pushad                                      ; CHECK IF NEEDED
    xor edx, edx
    .setup:
        mov dx, word[curr_state]                ; set dx as current state
        mov ecx, 16                             ; ecx = counter

    fibonacci_lfsr_loop:
        mov ax, dx                              ; ax = curr_state 
        bit_16th:       
            and ax, 0x1                         ; ax = 16th bit
        bit_14th:
            mov dx, word[curr_state]            ; set dx as current state
            and dx, 0x4                         ; dx = 14th bit
            shr dx, 2                           ; mov the bit to left most bit
            xor ax, dx                          ; ax = xor result
        bit_13th:
            mov dx, word[curr_state]            ; set dx as current state
            and dx, 0x8                         ; dx = 13th bit
            shr dx, 3                           ; mov the bit to left most bit
            xor ax, dx                          ; ax = xor result
        bit_11th:
            mov dx, word[curr_state]            ; set dx as current state
            and dx, 0x20                        ; dx = 11th bit
            shr dx, 5                           ; mov the bit to left most bit
            xor ax, dx                          ; ax = xor result
        .update_curr:
            mov dx, word[curr_state]            ; set dx as current state
            shr dx, 1                           ; move bits of curr state right
            shl ax, 15                          ; set result of calculation as 1st bit
            or  dx, ax                          ; set result as 1st bit
            mov word[curr_state],  dx           ; set curr_state as result 
        loop fibonacci_lfsr_loop                ; repeat on process
    
    popad
    endFunc




    resume:
        pushfd 
        pushad
        mov edx,dword[CURR]
        mov dword[edx + cor_SPP],esp                            ; save current ESP
    
    do_resume:
        mov esp,dword[ebx + cor_SPP]
        mov dword[CURR],ebx
        popad                                                   ; restore resumed co-routine state
        popfd
        ret                                                     ; return to resumed co-routine

    
  

get_random_scaled_num:
    startFunc
    pushad
    
    call    func_lsfr                        ; generate random num

    xor     ebx, ebx
    mov     bx, word[curr_state]
    mov     dword[temp_float], ebx 
    fild    dword[temp_float]               ; load random short to x87 stack
    
    movzx   edx, word[curr_state]           
    mov     dword[temp_float],MAX_WORD      ; temp_float = max word (unsigned)
    fidiv   dword[temp_float]               ; ST(0) = randomnum / MAX_WORD
    mov     ebx,dword[scale_high]
    sub     ebx,dword[scale_low]
    mov     dword[temp_float],ebx           ; temp_float =  (scale_high  -scale_low)
    fimul   dword[temp_float]               ; ST(0) = (randomnum / MAX_WORD) * (scale_high - scale_low)
    fiadd   dword[scale_low]                ; ST(0) = ST(0) + scale_low
    fstp    dword[scaled_result]            ; scaled result points to 

    popad                                   
    endFunc