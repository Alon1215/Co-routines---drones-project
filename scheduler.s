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


; 1st = adress of co-routine
%macro free_co_routine 1
        pushad
        mov     esi, dword[%1]
        mov     edi, dword[esi + cor_ST_START]
        %%free_stack:
                pushad
                push    edi
                call    free
                add     esp, 4
                popad
                ;drones_printf debug_free_stack, format_string
        %%free_struct:
                pushad
                push    esi
                call    free
                add     esp, 4
                popad
                ;drones_printf debug_free_struct, format_string
        popad
%endmacro


; 1st = argument to print, 2nd = format
%macro drones_printf 2
    pushad
    push    %1                          ; push string agrument on stack
    push    %2                          ; format_string
    call    printf                      ; printf(%1, %2)
    add     esp ,8                      ; remove fun arguments of stack
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




section .bss
    
section .data
        drone_index:                    dd 0
        min_score:                      dd 0

section	.rodata        
        format_winner:                  db "And this winner is... %d !",10,"GoodBye!", 10, 0                ; string for end of game
        msg_scheduler:                  db "-> scheduler()", 0                
        format_string:                  db "%s", 10, 0	                                                ; format 
        debug_msg_eliminate_drone:      db "Death round activated-> eliminate drone", 10, 0
        format_string_debug_drone_id:   db "drone id : %d", 10, 0	                                ; format 
        format_debug_elimination:       db "                            -> eliminate drone #%d", 10, 10, 0
        debug_free_stack:               db "                            -> free_co_stack() -> succeed", 0
        debug_free_struct:              db "                            -> free_co_struct() -> sucseed", 10, 0
        
section .text
        align 16
        global scheduler_exec
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
        extern cycles_R
        extern print_k
        extern drone_num
        extern printer
        extern drone_arr
        extern target
        extern printer
        extern scheduler
        extern active_drones_num
        extern resume
        extern SPMAIN
        extern target

scheduler_exec:
        .prepare_scheduler:
                xor ecx,ecx                                     ; set counter (ecx) as number of cycles
                
        .loop:
                            
                .check_if_print:
                        
                        xor edx,edx
                        mov eax, ecx                    ; set eax as number of cycles 
                        mov ebx, dword[print_k]         ; eax = k
                        cwd
                        div bx                          ; i/k, edx = remainder
                        cmp edx, 0                      ; i%k == 0 ?    
                        jne .check_death_round          ; skip print
                        mov ebx, dword[printer]         ; put printer's adress in ebx
                        call resume                     ; activate printer's co-routine
                        
                .check_death_round:
                        .skip_first_round:
                                cmp ecx,0
                                je .finish_round
                        
                        cmp dword[drone_index],0        ; check if i%N == 0
                        jne activate_drone_if_ok        ; (i%N) != 0
                        mov     eax,ecx                 ; eax = i
                        mov     ebx,dword[drone_num]    ; esi = N
                        cwd
                        div bx                          ; eax = i\N
                        mov ebx,dword[cycles_R]         ; esi = R
                        cwd
                        div bx                          ; eax = (i\N)\R,edx=(i\N)%R
                        cmp edx,0                       ; check if (i\N)%R == 0
                        jne activate_drone_if_ok        ; (i\N)%R != 0 
                        
                        .eliminate_loser:
                                drones_printf debug_msg_eliminate_drone, format_string
                                call turn_off_loser_drone
                
                .finish_round:
                        cmp dword[active_drones_num], 1         ; check if only last participant servived
                        jne activate_drone_if_ok                ; if not - repeat
                        print_n_exit:
                                call print_winner               ;  print winner
                                .free_heap_memory:
                                        call free_program
                                .exit_gracefully:
                                        mov esp, dword[SPMAIN]
                                        popad
                                        popfd
                                        mov eax, 1
                                        int 0x80
                                        
                                      
        
                activate_drone_if_ok:
                        mov edx, dword[drone_arr]       ; edx = adress of drone array
                        mov esi, dword[drone_index]     ; esi = index
                        mov ebx,dword[edx+esi*4]        ; get current drone index
                        cmp ebx,0                       ; check if drone is active
                        je .update_variables            ; skip dead drone 
                        call resume                     ; transfer control to drone co routine
                
                .update_variables:
                        update_drone_index              ; get next valid drone_index
                        inc ecx                         ; i++
                        jmp scheduler_exec.loop
                        
                
turn_off_loser_drone:
        startFunc
        pushad
        call find_min                                   ; find_min(), store value in variable
                        
        ;; now that we have a min score,turn off first drone with that score
        xor ecx,ecx                                                     ; ecx = 0
        mov ebx, dword[drone_arr]                                       ; edx = drone array address        
        
        turn_off_loop:
                mov edi, dword[min_score]                               ; edi = min score
                
                .compare_score_if_ok:
                        mov edx,dword[ebx + ecx*4]                      ; edx = current drone
                        cmp edx,0                                       ; check if drone is relevant
                        je .next
                        cmp dword[edx + drone_score],edi                ; is drone's score == min ?
                        je turn_off                                     ; diactivate it

                .next:
                        inc ecx                                         ; continue iterating
                        jmp turn_off_loop
        

        turn_off:
                drones_printf dword[edx + drone_id],format_debug_elimination
                alon_debug:
                free_co_routine (ebx + ecx*4)   ; free drone's memory allocation
                mov dword[ebx + ecx*4],0        ; set drone's adress 0 (in drone_arr)
                dec dword[active_drones_num]    ; decrease active drones count 

        popad
        endFunc
        
;; print winner
print_winner:
        startFunc
        mov ecx, -1
        mov edx, dword[drone_arr]                       ; edx = drone array address       
        .find_winner_loop:
                inc ecx                                 ; counter ++
                mov eax,dword[edx + ecx*4]              ; edx = current drone
                cmp eax,0                               ; check if drone is relevant
                je .find_winner_loop
                inc ecx                                 ; fix ecx for printing
                drones_printf ecx, format_winner
        endFunc
        
find_min:
        startFunc
        pushad
        xor ecx, ecx                                    ; i = 0
        mov eax, MAX_INT                                ; eax = max int
        mov ebx, dword[drone_arr]                       ; ebx = array's adress
        
        .loop:
                mov edx,dword[ebx + ecx*4]              ; edx = current drone
                cmp edx,0                               ; check if null (not active)
                je .skip_update_min                     ; not relevant drone

                cmp dword[edx + drone_score],eax        ; check if this is a new min score
                jge .skip_update_min                    ; no new min score
                mov eax,dword[edx + drone_score]        ; update the new min

                .skip_update_min:
                        inc ecx                         ; i++
                        cmp ecx,dword[drone_num]        ; check if 
                        jl .loop                        ; continue
        mov dword[min_score], eax
        popad
        endFunc

free_program:
        startFunc
        pushad
        
        free_drone_array:
                mov eax, dword[drone_arr]
                mov ecx, -1
                .loop:
                        inc ecx
                        cmp ecx, dword[drone_num]
                        je .free_array
                        mov ebx, dword[eax + 4*ecx]
                        cmp ebx, 0
                        je .loop
                        .free_drone:
                                free_co_routine (eax + 4*ecx)
                        jmp .loop
                
                .free_array:
                        pushad
                        push dword[drone_arr]
                        call free
                        add esp, 4
                        popad
        free_target:
                free_co_routine target
        free_scheduler:
                free_co_routine scheduler
        free_printer:
                free_co_routine printer
        
        free_done:
        popad
        endFunc


