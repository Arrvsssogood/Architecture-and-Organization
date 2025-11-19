section .data
title_line      db "=== STUDENT RECORD MANAGER ===",10,0

menu_text       db 10, "SUPER DUPER STUDENT RECORD",10
                db "[0] Exit", 10
                db "[1] Add Student",10
                db "[2] Delete by Name",10
                db "[3] Delete all failing students (below threshold 75)",10
                db "[4] Display All Students",10
                db "[5] Display Honor Students (90 and above)",10
                db "[6] Search by Name",10
                db "[7] Search by Grade Range",10
                db "Enter choice: ",0

prompt_name     db "Enter student name (max 31 chars): ",0
prompt_grade    db "Enter student grade (0-100): ",0
prompt_delname  db "Enter name to delete: ",0
prompt_low      db "Enter low grade for range search: ",0
prompt_high     db "Enter high grade for range search: ",0

msg_added       db "Student added.",10,0
msg_deleted     db "Record(s) deleted.",10,0
msg_none        db "No matching records found.",10,0
msg_empty       db "No students available.",10,0
msg_full        db "Student list is full.",10,0
msg_invalid     db "Invalid choice/input.",10,0
msg_invalid_grade db "Invalid grade! Must be between 0-100.",10,0

; Format ng table
tbl_top         db "+----+--------------------------------+-------+",10,0
tbl_header      db "| ID | Name                           | Grade |",10,0
tbl_sep         db "+----+--------------------------------+-------+",10,0
tbl_row_fmt     db "| %2d | %-30s | %5d |",10,0
tbl_empty_row   db "| -- | (no records)                   |  --   |",10,0
tbl_bottom      db "+----+--------------------------------+-------+",10,0

found_msg       db 10, "Found %d matching record(s).",10,0
count_msg       db "Total students: %d",10,10,0

fmt_int         db "%d",0

section .bss
MAX_STUDENTS    equ 50
NAME_BYTES      equ 32
RECORD_BYTES    equ (NAME_BYTES + 4)

storage         resb MAX_STUDENTS * RECORD_BYTES
count_students  resd 1

tmp_name        resb NAME_BYTES
tmp_grade       resd 1
choice          resd 1
found_count     resd 1
min_grade       resd 1
max_grade       resd 1
header_printed_flag resd 1

section .text

extern _printf
extern _scanf
extern _gets
extern _getchar
extern _strcmp

global _main

print_header:
    push dword tbl_header
    call _printf
    add esp, 4
    
    push dword tbl_sep
    call _printf
    add esp, 4
    ret

; Helper: clear_input (consume all input until newline or EOF)
clear_input:
.cin:
    call _getchar
    cmp eax, 10
    je .cin_done
    cmp eax, -1
    je .cin_done
    jmp .cin
.cin_done:
    ret

; Helper: shift_left (index on stack)
shift_left:
    push ebp
    mov ebp, esp
    push esi
    push edi
    push ecx
    push ebx

    mov eax, [ebp + 8]
    mov ecx, eax
    imul ecx, RECORD_BYTES
    lea edi, [storage + ecx]
    lea esi, [edi + RECORD_BYTES]

    mov ebx, [count_students]
    mov eax, [ebp + 8]
    sub ebx, eax
    sub ebx, 1
    cmp ebx, 0
    jle .sl_done

    mov ecx, ebx
    imul ecx, RECORD_BYTES
    cld
    rep movsb

.sl_done:
    pop ebx
    pop ecx
    pop edi
    pop esi
    pop ebp
    ret

; Main Entry Point
_main:
    push ebp
    mov ebp, esp

    ; Initialize storage
    pusha
    mov edi, storage
    mov ecx, MAX_STUDENTS * RECORD_BYTES / 4 
    mov eax, 0
    rep stosd
    popa

    mov dword [count_students], 0

menu_loop:
    ; print title
    push dword title_line
    call _printf
    add esp, 4

    ; print total students
    mov eax, [count_students]
    push eax
    push dword count_msg
    call _printf
    add esp, 8

    ; print menu
    push dword menu_text
    call _printf
    add esp, 4

    ; read choice
    push dword choice
    push dword fmt_int
    call _scanf
    add esp, 8
    
    cmp eax, 0
    je .invalid_input_choice

    call clear_input

    mov eax, [choice]
    cmp eax, 0
    je finish
    cmp eax, 1
    je add_student
    cmp eax, 2
    je delete_name
    cmp eax, 3
    je delete_failing
    cmp eax, 4
    je show_all
    cmp eax, 5
    je show_honors
    cmp eax, 6
    je search_name
    cmp eax, 7
    je search_grade_range

    ; invalid choice
    push dword msg_invalid
    call _printf
    add esp, 4
    jmp menu_loop

.invalid_input_choice:
    call clear_input
    push dword msg_invalid
    call _printf
    add esp, 4
    jmp menu_loop

; [1] Add Student
add_student:
    mov eax, [count_students]
    cmp eax, MAX_STUDENTS
    jge add_full

    ; Clear tmp_name
    pusha
    mov edi, tmp_name
    mov ecx, NAME_BYTES / 4 
    mov eax, 0              
    rep stosd               
    popa

    ; prompt name
    push dword prompt_name
    call _printf
    add esp, 4

    push dword tmp_name
    call _gets                  
    add esp, 4

    ; check first byte non-null
    movzx eax, byte [tmp_name]
    cmp al, 0
    je add_reject_name

add_prompt_grade_again:
    ; prompt grade
    push dword prompt_grade
    call _printf
    add esp, 4

    push dword tmp_grade
    push dword fmt_int
    call _scanf
    add esp, 8

    cmp eax, 0
    je add_reject_grade

    call clear_input

    ; Validate grade range (0-100)
    mov eax, [tmp_grade]
    cmp eax, 0
    jl add_invalid_grade_range
    cmp eax, 100
    jg add_invalid_grade_range

    ; compute dest offset
    mov ecx, [count_students]
    mov eax, ecx
    imul eax, RECORD_BYTES
    lea edi, [storage + eax]

    ; copy name
    mov esi, tmp_name
    mov ecx, NAME_BYTES
.copy_name_loop:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy_name_loop

    ; store grade
    mov eax, [tmp_grade]
    mov [edi], eax

    ; increment count
    inc dword [count_students]

    push dword msg_added
    call _printf
    add esp, 4
    jmp menu_loop

add_full:
    push dword msg_full
    call _printf
    add esp, 4
    jmp menu_loop

add_reject_name:
    push dword msg_invalid
    call _printf
    add esp, 4
    jmp menu_loop

add_reject_grade:
    call clear_input
    push dword msg_invalid
    call _printf
    add esp, 4
    jmp menu_loop

add_invalid_grade_range:
    push dword msg_invalid_grade
    call _printf
    add esp, 4
    jmp add_prompt_grade_again

; [2] Delete by Name
delete_name:
    mov eax, [count_students]
    cmp eax, 0
    je no_records

    push dword prompt_delname
    call _printf
    add esp, 4

    push dword tmp_name
    call _gets
    add esp, 4

    mov ecx, [count_students]
    mov edi, 0
    mov dword [found_count], 0

.del_loop:
    cmp edi, ecx
    jge .del_done

    mov eax, edi
    imul eax, RECORD_BYTES
    lea ebx, [storage + eax]

    push edi 
    push ecx

    push dword ebx
    push dword tmp_name
    call _strcmp
    add esp, 8

    pop ecx
    pop edi

    test eax, eax
    jne .del_next

    push dword edi
    call shift_left
    add esp, 4

    dec dword [count_students]
    inc dword [found_count]

    mov ecx, [count_students]
    jmp .del_loop

.del_next:
    inc edi
    jmp .del_loop

.del_done:
    mov eax, [found_count]
    cmp eax, 0
    je .del_notfound

    push dword msg_deleted
    call _printf
    add esp, 4
    jmp menu_loop

.del_notfound:
    push dword msg_none
    call _printf
    add esp, 4
    jmp menu_loop

no_records:
    push dword msg_empty
    call _printf
    add esp, 4
    jmp menu_loop

; [3] Delete all failing students
delete_failing:
    mov eax, [count_students]
    cmp eax, 0
    je no_records

    mov dword [tmp_grade], 75

    mov ecx, [count_students]
    mov edi, 0
    mov dword [found_count], 0

.df_loop:
    cmp edi, ecx
    jge .df_done

    mov eax, edi
    imul eax, RECORD_BYTES
    lea ebx, [storage + eax]

    mov eax, [ebx + NAME_BYTES]
    cmp eax, [tmp_grade]
    jl .df_match

    jmp .df_next

.df_match:
    push dword edi
    call shift_left
    add esp, 4

    dec dword [count_students]
    inc dword [found_count]

    mov ecx, [count_students]
    jmp .df_loop

.df_next:
    inc edi
    jmp .df_loop

.df_done:
    mov eax, [found_count]
    cmp eax, 0
    je .df_notfound

    push dword msg_deleted
    call _printf
    add esp, 4
    jmp menu_loop

.df_notfound:
    push dword msg_none
    call _printf
    add esp, 4
    jmp menu_loop

; [4] Display All Students
show_all:
    mov eax, [count_students]
    cmp eax, 0
    je .show_empty_table 

    push dword tbl_top
    call _printf
    add esp, 4
    
    call print_header

    mov esi, [count_students]
    mov ebx, 0

.print_loop:
    cmp ebx, esi
    jge .print_finish_table

    mov eax, ebx
    imul eax, RECORD_BYTES
    lea ecx, [storage + eax]

    mov edx, [ecx + NAME_BYTES]
    mov eax, ebx
    inc eax

    push edx
    push dword ecx
    push eax
    push dword tbl_row_fmt
    call _printf
    add esp, 16 

    inc ebx
    jmp .print_loop

.print_finish_table:
    push dword tbl_bottom
    call _printf
    add esp, 4
    
    jmp menu_loop
    
.show_empty_table:
    push dword tbl_top
    call _printf
    push dword tbl_header
    call _printf
    push dword tbl_sep
    call _printf
    push dword tbl_empty_row
    call _printf
    push dword tbl_bottom
    call _printf
    add esp, 20
    
    jmp menu_loop

; [5] Display Honor Students (FIXED)
show_honors:
    mov eax, [count_students]
    cmp eax, 0
    je no_records

    mov ecx, [count_students]
    mov edi, 0
    mov dword [found_count], 0
    mov dword [header_printed_flag], 0

.hon_loop:
    cmp edi, ecx
    jge .hon_done

    mov eax, edi
    imul eax, RECORD_BYTES
    lea ebx, [storage + eax]

    mov edx, [ebx + NAME_BYTES]
    cmp edx, 90
    jl .hon_next

    cmp dword [header_printed_flag], 0
    jne .hon_print_row

    push edx
    push ebx
    push edi
    push ecx

    push dword tbl_top
    call _printf
    add esp, 4
    
    call print_header
    inc dword [header_printed_flag]
    
    pop ecx
    pop edi
    pop ebx
    pop edx

.hon_print_row:
    mov eax, edi
    inc eax
    
    push edi
    push ecx

    push edx
    push dword ebx
    push eax
    push dword tbl_row_fmt
    call _printf
    add esp, 16

    pop ecx
    pop edi

    inc dword [found_count]

.hon_next:
    inc edi
    jmp .hon_loop

.hon_done:
    mov eax, [found_count]
    cmp eax, 0
    jne .hon_present

    push dword msg_none
    call _printf
    add esp, 4
    jmp menu_loop

.hon_present:
    push dword tbl_bottom
    call _printf
    add esp, 4

    jmp menu_loop

; [6] Search by Name
search_name:
    mov eax, [count_students]
    cmp eax, 0
    je no_records

    push dword prompt_name
    call _printf
    add esp, 4

    push dword tmp_name
    call _gets
    add esp, 4

    mov ecx, [count_students]
    mov edi, 0
    mov dword [found_count], 0
    mov dword [header_printed_flag], 0

.sbn_loop:
    cmp edi, ecx
    jge .sbn_done

    mov eax, edi
    imul eax, RECORD_BYTES
    lea ebx, [storage + eax]

    push edi 
    push ecx

    push dword ebx
    push dword tmp_name
    call _strcmp
    add esp, 8

    pop ecx
    pop edi

    test eax, eax
    jne .sbn_next

    mov edx, [ebx + NAME_BYTES]

    cmp dword [header_printed_flag], 0
    jne .sbn_print_row

    push edx
    push ebx
    push edi 
    push ecx

    push dword tbl_top
    call _printf
    add esp, 4
    
    call print_header
    inc dword [header_printed_flag]

    pop ecx
    pop edi
    pop ebx
    pop edx

.sbn_print_row:
    mov eax, edi
    inc eax
    
    push edi
    push ecx

    push edx
    push dword ebx
    push eax
    push dword tbl_row_fmt
    call _printf
    add esp, 16
  
    pop ecx
    pop edi

    inc dword [found_count]

.sbn_next:
    inc edi
    jmp .sbn_loop

.sbn_done:
    mov eax, [found_count]
    cmp eax, 0
    jne .sbn_found

    push dword msg_none
    call _printf
    add esp, 4
    jmp menu_loop

.sbn_found:
    push dword tbl_bottom
    call _printf
    add esp, 4
    
    push dword [found_count]
    push dword found_msg
    call _printf
    add esp, 8
    jmp menu_loop

; [7] Search by Grade Range (FIXED)
search_grade_range:
    mov eax, [count_students]
    cmp eax, 0
    je no_records

    ; Read Low Grade
    push dword prompt_low
    call _printf
    add esp, 4

    push dword min_grade
    push dword fmt_int
    call _scanf
    add esp, 8
    
    cmp eax, 0
    je sgr_reject_input

    ; Read High Grade
    push dword prompt_high
    call _printf
    add esp, 4

    push dword max_grade
    push dword fmt_int
    call _scanf
    add esp, 8
    
    cmp eax, 0
    je sgr_reject_input

    call clear_input

    mov ecx, [count_students]
    mov edi, 0
    mov dword [found_count], 0
    mov dword [header_printed_flag], 0

.sgr_loop:
    cmp edi, ecx
    jge .sgr_done

    mov eax, edi
    imul eax, RECORD_BYTES
    lea ebx, [storage + eax]

    mov edx, [ebx + NAME_BYTES]

    mov eax, [min_grade]
    cmp edx, eax
    jl .sgr_next

    mov esi, [max_grade]
    cmp edx, esi
    jg .sgr_next

    cmp dword [header_printed_flag], 0
    jne .sgr_print_row

    push edx
    push ebx
    push edi 
    push ecx

    push dword tbl_top
    call _printf
    add esp, 4
    
    call print_header
    inc dword [header_printed_flag]

    pop ecx
    pop edi
    pop ebx
    pop edx

.sgr_print_row:
    mov eax, edi
    inc eax
    
    push ebx
    push edi
    push ecx
    
    push edx
    push dword ebx
    push eax
    push dword tbl_row_fmt
    call _printf
    add esp, 16

    pop ecx
    pop edi
    pop ebx

    inc dword [found_count]

.sgr_next:
    inc edi
    jmp .sgr_loop

.sgr_done:
    mov eax, [found_count]
    cmp eax, 0
    jne .sgr_found

    push dword msg_none
    call _printf
    add esp, 4
    jmp menu_loop

.sgr_found:
    push dword tbl_bottom
    call _printf
    add esp, 4
    
    push dword [found_count]
    push dword found_msg
    call _printf
    add esp, 8
    jmp menu_loop

sgr_reject_input:
    call clear_input 
    push dword msg_invalid
    call _printf
    add esp, 4
    jmp menu_loop

; Exit
finish:
    mov esp, ebp
    pop ebp
    ret