%include "common"
_Model "R2.*"
;Z80 emulator for the R216
;Assemble with tptasm

;Functions with names starting with "_" modify only r6 and r7 (+ Z80 registers)
;Z80 REG | ' = Shadow register
;        A  - r08
;        F  - r09
;       HL  - r10
;       BC  - r11
;       DE  - r12
;       PC  - r13
;       SP  - [M_SP]
;       AF' - [M_SAF]
;       HL' - [M_SHL]
;       BC' - [M_SBC]
;       DE' - [M_SDE]

;Z80 FLAGS | X=USED (X)=UNUSED
;   7   6   5   4   3   2   1   0
;   S   Z  (F5)(H) (F3) PV  (N) C
;Sign | Zero | - | - | - | Parity/Overflow | - | Carry

;Z80 current memory map | Edit _read_mem: and _write_mem: to change
;       0000-01FF   RAM (From M_RAM:)


entry_point:
            mov     r0,  0
            mov     r8,  0
            mov     r9,  0
            mov     r10, 0
            mov     r11, 0
            mov     r12, 0
            mov     r13, 0
            mov     r14, 0;R2 SP
            send    r0, 0x1000;Cursor 0,0 (0x10YX)
            send    r0, 0x200F;Color W on B
.loop:      call    executePC
            jmp     .loop

RT2_LINE:   dw      0x1010

;#################Z80 emulator code starting here!##################
_read_mem:;r7 = MEM[r7]
            and     r7, 0x01FF
            mov     r7, [M_RAM+r7]
            ret
_write_mem:;MEM[r7] = r6
            and     r7, 0x01FF
            mov     [M_RAM+r7], r6
            ret

_stack_push:;Push r7_16
            mov     r6, r7
            push    r6
            shr     r6, 8
            mov     r7, [M_SP]
            sub     r7, 1
            call    _write_mem  ;val >> 8, --SP
            pop     r6
            and     r6, 0xFF
            sub     [M_SP], 2
            mov     r7, [M_SP]
            call    _write_mem  ;val & 0xFF, --SP
            ret
_stack_pop:;Pop to r7_16
            mov     r7, [M_SP]
            call    _read_mem   ;SP++
            push    r7
            mov     r7, [M_SP]
            add     r7, 1
            add     [M_SP], 2
            call    _read_mem   ;SP++
            shl     r7, 8
            pop     r6
            or      r7, r6
            ret
_read_nn:;r7_16 = MEM[r7]
            push    r8
            mov     r8, r7
            call    _read_mem   ;r7 + 0
            xor     r8, r7
            xor     r7, r8      ;swap
            xor     r8, r7
            add     r7, 1
            call    _read_mem   ;r7 + 1
            shl     r7, 8
            or      r7, r8
            pop     r8
            ret
_write_nn:;MEM[r7] = r6_16
            push    r7
            push    r6
            shr     r6, 8
            call    _write_mem  ;val >> 8, addr
            pop     r6
            and     r6, 0xFF
            pop     r7
            add     r7, 1
            call    _write_mem  ;val & 0xFF, addr+1
            ret

_get_parity8:;r7 = parity(r7)
            mov     r6, r7
            shr     r6, 4
            xor     r7, r6
            mov     r6, r7
            shr     r6, 2
            xor     r7, r6
            mov     r6, r7
            shr     r6, 1
            xor     r7, r6
            and     r7, 1
            xor     r7, 1
            ret
_update_SZP:;Update SZP flags based on r7, and clear carry
            mov     r9, 0;Clear all flags
            mov     r6, r7
            and     r6, 0x80
            or      r9, r6;Sign
            mov     r6, r7
            jnz     .noZero
            or      r9, 0x40;Zero
.noZero:    call    _get_parity8
            shl     r7, 2
            or      r9, r7;Parity
            ret

_table_cc:;r7 <- cc[r7]
            mov     r6, r9
            test    r7, 1
            jnz     .noInvert
            xor     r6, 0xFF
.noInvert:  and     r7, 0xFE
            add     r7, .table
            jmp     r7
.table:     shr     r6, 6;Z
            jmp     .done
            shr     r6, 0;C
            jmp     .done
            shr     r6, 2;PV
            jmp     .done
            shr     r6, 7;S
.done:      and     r6, 1
            mov     r7, r6
            ret
_table_rp_read:;r7_16 <- rp[r7]
            shl     r7, 1
            add     r7, .table
            jmp     r7
.table:     mov     r7, r11;BC
            ret
            mov     r7, r12;DE
            ret
            mov     r7, r10;HL
            ret
            mov     r7, [M_SP];SP
            ret
_table_rp_write:;rp[r7] <- r6_16
            shl     r7, 1
            add     r7, .table
            jmp     r7
.table:     mov     r11, r6;BC
            ret
            mov     r12, r6;DE
            ret
            mov     r10, r6;HL
            ret
            mov     [M_SP], r6;SP
            ret
_table_rp2_read:;r7_16 <- rp2[r7]
            shl     r7, 1
            add     r7, .table
            jmp     r7
.table:     mov     r7, r11;BC
            ret
            mov     r7, r12;DE
            ret
            mov     r7, r10;HL
            ret
            mov     r7, r8;A
            shl     r7, 8
            or      r7, r9;F
            ret
_table_rp2_write:;rp2[r7] <- r6_16
            shl     r7, 1
            add     r7, .table
            jmp     r7
.table:     mov     r11, r6;BC
            ret
            mov     r12, r6;DE
            ret
            mov     r10, r6;HL
            ret
            mov     r7, r6
            and     r7, 0xFF
            mov     r9, r7;F
            shr     r6, 8
            mov     r8, r6;A
            ret
_table_r_read:;r7 <- r[r7]
            mov     r6, .table
            add     r6, r7;Multiply by 3
            add     r6, r7
            add     r6, r7
            jmp     r6
.table:     mov     r7, r11;(B)C
            shr     r7, 8
            ret
            mov     r7, r11;B(C)
            and     r7, 0xFF
            ret
            mov     r7, r12;(D)E
            shr     r7, 8
            ret
            mov     r7, r12;D(E)
            and     r7, 0xFF
            ret
            mov     r7, r10;(H)L
            shr     r7, 8
            ret
            mov     r7, r10;H(L)
            and     r7, 0xFF
            ret
            mov     r7, r10;[HL]
            call    _read_mem
            ret
            mov     r7, r8;A
            ret
_table_r_write:;r[r7] <- r6
            shl     r7, 2;Multiply by 4
            add     r7, .table
            jmp     r7
.table:     and     r11, 0xFF;(B)C
            shl     r6, 8
            or      r11, r6
            ret
            and     r11, 0xFF00;B(C)
            or      r11, r6
            ret
            nop
            and     r12, 0xFF;(D)E
            shl     r6, 8
            or      r12, r6
            ret
            and     r12, 0xFF00;D(E)
            or      r12, r6
            ret
            nop
            and     r10, 0xFF;(H)L
            shl     r6, 8
            or      r10, r6
            ret
            and     r10, 0xFF00;H(L)
            or      r10, r6
            ret
            nop
            mov     r7, r10;HL
            call    _write_mem;MEM[HL] = r6
            ret
            nop
            mov     r8, r6;A
            ret
_table_alu_exec:;Execute alu[r7] on A(r8) and r6
            jmp     [.table+r7]
.table:     dw      .ADD0
            dw      .ADC1
            dw      .SUB2
            dw      .SBC3
            dw      .AND4
            dw      .XOR5
            dw      .OR6
            dw      .CP7

.ADC1:      and     r9, 1   ;Keep only carry
            add     r6, r9  ;Add carry flag to r6
.ADD0:      mov     r7, r8  ;Save old A
            add     r8, r6  ;Add r6 to A
            mov     r9, r8
            and     r8, 0xFF;8 bit only
            shr     r9, 8   ;Carry flag set/clear
            mov     r6, r8
            jnz     .ADD_NZ
            or      r9, 0x40;Zero flag set/clear
    .ADD_NZ:and     r6, 0x80
            or      r9, r6  ;Sign flag set/clear
            mov     r6, r8
            shr     r6, 7   ;Get sign - new a
            shr     r7, 7   ;Get sign - old a
            cmp     r7, r6  ;Check if sign got cleared
            ja      .ADD_S
            ret
    .ADD_S: or      r9, 0x04;Set signed overflow
            ret
.SBC3:      and     r9, 1   ;Keep only carry
            add     r6, r9  ;Add carry flag to r6
.SUB2:      mov     r7, r8  ;Save old A
            sub     r8, r6  ;Sub r6 from A
            mov     r9, r8
            and     r8, 0xFF;8 bit only
            shr     r9, 8   ;Carry flag set/clear
            and     r9, 1
            mov     r6, r8
            jnz     .SUB_NZ
            or      r9, 0x40;Zero flag set/clear
    .SUB_NZ:and     r6, 0x80
            or      r9, r6  ;Sign flag set/clear
            mov     r6, r8
            shr     r6, 7   ;Get sign - new a
            shr     r7, 7   ;Get sign - old a
            cmp     r6, r7  ;Check if sign got set
            ja      .SUB_S
            ret
    .SUB_S: or      r9, 0x04;Set signed overflow
            ret
.AND4:      and     r8, r6
            mov     r7, r8
            call    _update_SZP
            ret
.XOR5:      xor     r8, r6
            mov     r7, r8
            call    _update_SZP
            ret
.OR6:       or      r8, r6
            mov     r7, r8
            call    _update_SZP
            ret
.CP7:       mov     r7, r8  ;Temp value
            sub     r7, r6  ;Sub r6 from TMP_A
            mov     r9, r7
            shr     r9, 8
            and     r9, 0x01;Leave carry
            mov     r6, r7
            jnz     .SUB_NZ
            or      r9, 0x40;Zero flag set/clear
    .SUB_NZ:and     r6, 0x80
            or      r9, r6  ;Sign flag set/clear
            mov     r6, r8
            and     r6, 0x80;Get sign - old a
            and     r7, 0x80;Get sign - new a
            cmp     r6, r7  ;Check if sign got set
            ja      .SUB_S
            ret
    .SUB_S: or      r9, 0x04;Set signed overflow
            ret
_table_rot_exec:;Execute rot[r7] on r[r6]
            push    r5;Get more registers free
            push    r6;Save source register index for later
            mov     r5, r7
            mov     r7, r6
            call    _table_r_read;r7 = value
            jmp     [.table+r5]
.table:     dw      .RLC0
            dw      .RRC1
            dw      .RL2
            dw      .RR3
            dw      .SLA4
            dw      .SRA5
            dw      .SLL6
            dw      .SRL7

.RLC0:      shl     r7, 1
            shl     r9, 7
            or      r7, r9;Carry flag to bit 0
            mov     r5, r7
            call    _update_SZP;r7
            mov     r7, r5
            shr     r7, 8
            or      r9, r7
            mov     r6, r5
            and     r6, 0xFF
            pop     r7;Get old r6
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
.RRC1:      ror     r7, 1;save bit 0 in MSB_16
            mov     r6, r7
            shr     r6, 8
            or      r7, r6
            mov     r5, r7
            call    _update_SZP;r7
            mov     r7, r5
            shr     r7, 7
            or      r9, r7;Carry flag to bit 0
            mov     r6, r5
            and     r6, 0xFF
            pop     r7;Get old r6
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
.RL2:       shl     r7, 1
            and     r9, 1
            or      r7, r9;Copy carry flag to bit 0
            mov     r5, r7
            and     r7, 0xFF
            call    _update_SZP;r7
            mov     r6, r5
            and     r6, 0xFF
            shr     r5, 8
            or      r9, r5
            pop     r7;Get old r6
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
.RR3:       ror     r7, 1;save bit 0 in MSB_16
            shl     r9, 7;Carry flag to MSB
            or      r7, r9;Copy carry flag to MSB
            mov     r5, r7
            and     r7, 0xFF;Drop MSB_16
            call    _update_SZP;r7
            mov     r7, r5
            shr     r7, 15;Get MSB_16 = old bit 0
            or      r9, r7;Carry flag set to old bit 0
            mov     r6, r5
            and     r6, 0xFF
            pop     r7
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
.SLA4:      shl     r7, 1
            mov     r5, r7
            and     r7, 0xFF
            call    _update_SZP;r7
            mov     r7, r5
            shr     r7, 8
            or      r9, r7
            mov     r6, r5
            and     r6, 0xFF
            pop     r7
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
.SRA5:      mov     r9, r7
            ror     r7, 1
            and     r9, 0x80
            or      r7, r9
            mov     r5, r7
            and     r7, 0xFF
            call    _update_SZP;r7
            mov     r7, r5
            shr     r7, 15
            or      r9, r7
            mov     r6, r5
            and     r6, 0xFF
            pop     r7
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
.SLL6:      shl     r7, 1;Undocumented instruction (?)
            or      r7, 1
            mov     r5, r7
            and     r7, 0xFF
            call    _update_SZP;r7
            mov     r7, r5
            shr     r7, 8
            or      r9, r7
            mov     r6, r5
            and     r6, 0xFF
            pop     r7
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
.SRL7:      mov     r5, r7
            shr     r7, 1
            call    _update_SZP;r7
            mov     r7, r5
            and     r7, 1
            or      r9, r7;Carry flag
            mov     r6, r5
            shr     r6, 1
            pop     r7
            call    _table_r_write;r[r7] = r6
            pop     r5
            ret
_table_bli_exec:;Execute bli[r7], CP* and IO instructions not supported
            push    r5;Get more registers free
            mov     r5, .RET
            jmp     [{.table 4 -}+r7]   ;[.table-4+r7]
.table:     dw      .LDI4
            dw      .LDD5
            dw      .LDIR6
            dw      .LDDR7

.LDI4:      and     r9, 0xFB;Clear PV
            cmp     r11, 1
            je      .LDI_2
            or      r9, 0x04
    .LDI_2: mov     r7, r10;HL
            add     r10, 1;HL++
            call    _read_mem
            mov     r7, r12;DE
            add     r12, 1;DE++
            call    _write_mem
            sub     r11, 1;BC--
            jmp     r5
.LDD5:      and     r9, 0xFB;Clear PV
            cmp     r11, 1
            je      .LDD_2
            or      r9, 0x04
    .LDD_2: mov     r7, r10;HL
            sub     r10, 1;HL--
            call    _read_mem
            mov     r7, r12;DE
            sub     r12, 1;DE--
            call    _write_mem
            sub     r11, 1;BC--
            jmp     r5
.LDIR6:     mov     r5, .LDIR_2
    .LDIR_2:cmp     r11, 0
            jne     .LDI_2
            jmp     .RET
.LDDR7:     mov     r5, .LDDR_2
    .LDDR_2:cmp     r11, 0
            jne     .LDD_2
            ;jmp    .RET
.RET:       pop     r5
            ret

;  7  6  5  4  3  2  1  0
;  X--X  Y--Y--Y  Z--Z--Z
;  X=r0  Y=r1  Z=r2
executeCBprefix:;Execute bit instruction at PC+1, r0 r1 r2 r3 r4 r5 (r6) (r7)
            mov     r7, r13;Load PC
            add     r7, 1;Add 1
            add     r13, 2
            call    _read_mem;Read a byte from memory
            mov     r0, r7
            shr     r0, 6;X
            mov     r1, r7
            shr     r1, 3
            and     r1, 0x07;Y
            mov     r2, r7
            and     r2, 0x07;Z

            jmp     [.X_+r0]
.X_:        dw      .X0
            dw      .X1
            dw      .X2
            dw      .X3
.X0:        ;<rot[y] r[z]>
                mov     r7, r1;Y
                mov     r6, r2;Z
                call    _table_rot_exec
                ret
.X1:        ;<BIT y, r[z]>
                mov     r7, r1;Y
                call    _table_r_read
                shr     r7, r2;Z
                jz      .X1_1
                and     r9, 0xBF;Clear zero flag
                ret
        .X1_1:  or      r9, 0x40;Set zero flag
                ret
.X2:        ;<RES y, r[z]>
                mov     r7, r2;Z
                call    _table_r_read
                mov     r0, 1
                shl     r0, r1;Y
                xor     r0, 0xFF
                and     r7, r0;Clear bit
                mov     r6, r7
                mov     r7, r2;Z
                call    _table_r_write
                ret
.X3:        ;<SET y, r[z]>
                mov     r7, r2;Z
                call    _table_r_read
                mov     r0, 1
                shl     r0, r1;Y
                or      r7, r0;Set bit
                mov     r6, r7
                mov     r7, r2;Z
                call    _table_r_write
                ret
;  7  6  5  4  3  2  1  0
;  X--X  Y--Y--Y  Z--Z--Z
;  X=r0  Y=r1  Z=r2
executeEDprefix:;Execute extended instruction at PC+1, r0 r1 r2 r3 r4 r5 (r6) (r7)
            add     r13, 1
            mov     r7, r13     ;Load PC
            call    _read_mem   ;Read a byte from memory
            mov     r0, r7
            shr     r0, 6       ;X

            jmp     [.X_+r0]
.X_:        dw      .X0
            dw      .X1
            dw      .X2
            dw      .X3
.X0:        ;INVALID
.X3:        ;INVALID
                add     r13, 1  ;NOP
                ret
.X1:            mov     r0, r7
                shr     r0, 3   ;Y
                and     r0, 7   ;Only Y
                jmp     [.X1Z_+r0]
.X1Z_:          dw      .X1Z0
                dw      .X1Z1
                dw      .X1Z2
                dw      .X1Z3
                dw      .X1Z4
                dw      .X1Z5
                dw      .X1Z6
                dw      .X1Z7
.X1Z0:          ;<IN (C)> or <IN r[y], (C)> - Not supported
.X1Z1:          ;<OUT (C), r[y]> or <OUT (C), 0> - Not supported
                    ;add        r13, 1
                    hlt;ret
.X1Z2:              test    r7, 0x08;Test Q
                    jnz     .X1Z2Q1
.X1Z2Q0:            ;<ADC HL, rp[p]>
                        and     r9, 1;Keep only carry
                        shr     r7, 4;Get P
                        and     r7, 3;Only P
                        call    _table_rp_read
                        add     r7, r9;Add carry flag
                        mov     r9, 0;Clear all flags
                        mov     r0, r10;Copy of HL
                        add     r0, r7;HL(copy) += rp[p] + C
                        jno     .X1Z2Q0_1
                        or      r9, 0x04;Set PV
            .X1Z2Q0_1:  mov     r0, r10
                        add     r0, r7
                        jnc     .X1Z2Q0_2
                        or      r9, 1;Set carry
            .X1Z2Q0_2:  mov     r10, r0;Write back to HL
                        jnz     .X1Z2Q0_3
                        or      r9, 0x40;Set zero
            .X1Z2Q0_3:  shr     r0, 8
                        and     r0, 1
                        or      r9, r0;Set sign
                        ret
.X1Z2Q1:            ;<SBC HL, rp[p]>
                        and     r9, 1;Keep only carry
                        shr     r7, 4;Get P
                        and     r7, 3;Only P
                        call    _table_rp_read
                        add     r7, r9;Add carry flag
                        mov     r9, 0;Clear all flags
                        mov     r0, r10;Copy of HL
                        sub     r0, r7;HL(copy) -= rp[p] + C
                        jno     .X1Z2Q1_1
                        or      r9, 0x04;Set PV
            .X1Z2Q1_1:  mov     r0, r10
                        sub     r0, r7
                        jnc     .X1Z2Q1_2
                        or      r9, 1;Set carry
            .X1Z2Q1_2:  mov     r10, r0;Write back to HL
                        jnz     .X1Z2Q1_3
                        or      r9, 0x40;Set zero
            .X1Z2Q1_3:  shr     r0, 8
                        and     r0, 1
                        or      r9, r0;Set sign
                        ret
.X1Z3:              test    r7, 0x08;Test Q
                    jnz     .X1Z3Q1
.X1Z3Q0:            ;<LD (nn), rp[p]>
                        shr     r7, 4;Get P
                        and     r7, 3;Only P
                        call    _table_rp_read
                        mov     r0, r7
                        mov     r7, r13
                        add     r7, 1
                        call    _read_nn
                        mov     r6, r0
                        call    _write_nn
                        ret
.X1Z3Q1:            ;<LD rp[p], (nn)>
                        mov     r7, r13
                        add     r7, 1
                        call    _read_nn;Get address
                        call    _read_nn;Get 2 byte from address
                        mov     r6, r7
                        shr     r7, 4;Get P
                        and     r7, 3;Only P
                        call    _table_rp_write
                        ret
.X1Z4:          ;<NEG>
                    mov     r9, 0;Reset flags
                    cmp     r8, 0;A
                    jnz     .X1Z4_1
                    or      r9, 1;Set carry
            .X1Z4_1:cmp     r8, 0x80
                    jne     .X1Z4_2
                    or      r9, 0x04;Set PV
            .X1Z4_2:mov     r1, 0
                    sub     r1, r8;0 - a
                    mov     r8, r1
                    jnz     .X1Z4_3
                    or      r9, 0x40;Set zero
            .X1Z4_3:and     r1, 0x80
                    or      r9, r1;Set sign
                    add     r13, 1
                    ret
.X1Z5:          ;<RETN> or <RETI> - Not supported
.X1Z6:          ;<IM im[y]> - Not supported
                    ;add        r13, 1
                    hlt;ret
.X1Z7:          mov     r0, r7
                shr     r0, 3;Y
                and     r0, 7;Only Y
                cmp     r0, 4
                je      .X1Z7Y4
                cmp     r0, 5
                je      .X1Z7Y5
                ;Not supported (I and R register)
                    ;add        r13, 1
                    hlt;ret
.X1Z7Y4:        ;<RRD>
                    mov     r7, r10;HL
                    call    _read_mem
                    mov     r0, r7
                    and     r0, 0x0F;Low mem
                    shr     r7, 4;High mem to low mem
                    mov     r1, r8;A
                    and     r1, 0x0F;Low A only
                    shl     r1, 4;Low to high
                    or      r7, r1;Low A to high mem
                    and     r8, 0xF0;Clear low A
                    or      r8, r0;Low mem to low A
                    mov     r0, r7
                    mov     r6, r7
                    mov     r7, r10;HL
                    call    _write_mem
                    mov     r7, r0
                    call    _update_SZP
                    ret
.X1Z7Y5:        ;<RLD>
                    mov     r7, r10;HL
                    call    _read_mem
                    mov     r0, r7
                    shr     r0, 4;High mem
                    and     r7, 0x0F
                    shl     r7, 4;Low mem to high mem
                    mov     r1, r8;A
                    and     r1, 0x0F;Low A
                    or      r7, r1;Low a to low mem
                    and     r8, 0xF0;Clear low A
                    or      r8, r0;High mem to low A
                    mov     r0, r7
                    mov     r6, r7
                    mov     r7, r10;HL
                    call    _write_mem
                    mov     r7, r0
                    call    _update_SZP
                    ret
.X2:        ;<bli[y,z]>
                cmp     r2, 0;Z
                jne     .X2_1;Not supported/invalid
                cmp     r1, 4;Y
                jb      .X2_1;Invalid
                mov     r7, r1;Y
                call    _table_bli_exec
        .X2_1:  ;add        r13, 1;Either not supported or invalid
                hlt;ret

;  7  6  5  4  3  2  1  0
;  X--X  Y--Y--Y  Z--Z--Z
;        P--P  Q
;  X=r0  Y=r1  Z=r2  P=r3  Q=r4
executePC:  ;Execute the instruction starting from PC, r0 r1 r2 r3 r4 r5 (r6) (r7)
            mov     r7, r13;Load PC
            call    _read_mem;Read a byte from memory
            mov     r0, r7
            shr     r0, 6;X
            mov     r1, r7
            shr     r1, 3
            and     r1, 0x07;Y
            mov     r2, r7
            and     r2, 0x07;Z
            mov     r3, r1
            shr     r3, 1;P
            mov     r4, r1
            and     r4, 1;Q

            jmp     [.X_+r0]
.X_:        dw      .X0
            dw      .X1
            dw      .X2
            dw      .X3
.X0:            jmp     [.X0Z_+r2]
.X0Z_:          dw      .X0Z0
                dw      .X0Z1
                dw      .X0Z2
                dw      .X0Z3
                dw      .X0Z4
                dw      .X0Z5
                dw      .X0Z6
                dw      .X0Z7
.X0Z0:              cmp     r1, 4
                    jae     .X0Z0Y47
                    jmp     [.X0Z0Y_+r1]
.X0Z0Y_:            dw      .X0Z0Y0
                    dw      .X0Z0Y1
                    dw      .X0Z0Y2
                    dw      .X0Z0Y3
.X0Z0Y0:            ;<NOP>
                        add     r13, 1;PC++
                        ret
.X0Z0Y1:            ;<EX AF,AF'>
                        mov     r0, [M_SAF]
                        shr     r8, 8;A <<= 8
                        or      r8, r9;A |= F
                        mov     [M_SAF], r8
                        mov     r8, r0
                        shr     r8, 8;A = AF >> 8
                        mov     r9, r0
                        and     r9, 0xFF;F = AF & 0xFF
                        ret
.X0Z0Y2:            ;<DJNZ d>
                        mov     r0, r11;BC
                        shr     r0, 8;B
                        sub     r0, 1;B--
                        jz      .X0Z0Y2_1
                        mov     r7, r13
                        add     r7, 1
                        call    _read_mem;Read next byte
                        test    r7, 0x80;Test sign bit
                        jz      .X0Z0Y2_0
                        or      r7, 0xFF00;Negative int8_t to int16_t
            .X0Z0Y2_0:  add     r13, r7;Add signed value to PC
                        jmp     .X0Z0Y2_2;Skip PC+=2
            .X0Z0Y2_1:  add     r13, 2;PC+=2
            .X0Z0Y2_2:  and     r11, 0x00FF
                        shl     r0, 8
                        or      r11, r0;B to BC
                        ret
.X0Z0Y3:            ;<JR d>
                        mov     r7, r13
                        add     r7, 1
                        call    _read_mem;Read next byte
                        test    r7, 0x80;Test sign bit
                        jz      .X0Z0Y3_0
                        or      r7, 0xFF00;Negative int8_t to int16_t
            .X0Z0Y3_0:  add     r13, r7;Add signed value to PC...
                        add     r13, 2;...from the end of the inst
                        ret
.X0Z0Y47:           ;<JR cc[y-4], d>
                        mov     r7, r1
                        sub     r7, 4
                        call    _table_cc
                        jz      .X0Z0Y47_0
                        mov     r7, r13
                        add     r7, 1
                        call    _read_mem
                        test    r7, 0x80;Test sign bit
                        jz      .X0Z0Y47_1
                        or      r7, 0xFF00;Negative int8_t to int16_t
            .X0Z0Y47_1: add     r13, r7;Add signed value to PC...
            .X0Z0Y47_0: add     r13, 2;PC+=2
                        ret
.X0Z1:              cmp     r4, 0;Q
                    jnz     .X0Z1Q1
.X0Z1Q0:            ;<LD rp[p], nn>
                        mov     r7, r13
                        add     r7, 1
                        call    _read_nn
                        mov     r6, r7;NN
                        mov     r7, r3;P
                        call    _table_rp_write
                        add     r13, 3
                        ret
.X0Z1Q1:            ;<ADD HL, rp[p]>
                        mov     r7, r3;P
                        call    _table_rp_read
                        and     r9, 0xFE;Clear carry
                        add     r10, r7;HL+=rp[p]
                        adc     r9, 0;Add carry flag to the carry flag
                        add     r13, 1
                        ret
.X0Z2:              cmp     r4, 0;Q
                    jnz     .X0Z2Q1
.X0Z2Q0:                jmp     [.X0Z2Q0P_+r3]
.X0Z2Q0P_:              dw      .X0Z2Q0P0
                        dw      .X0Z2Q0P1
                        dw      .X0Z2Q0P2
                        dw      .X0Z2Q0P3
.X0Z2Q0P0:              ;<LD (BC),A>
                            mov     r7, r11;BC
                            mov     r6, r8;A
                            call    _write_mem
                            add     r13, 1
                            ret
.X0Z2Q0P1:              ;<LD (DE),A>
                            mov     r7, r12;DE
                            mov     r6, r8;A
                            call    _write_mem
                            add     r13, 1
                            ret
.X0Z2Q0P2:              ;<LD (nn),HL>
                            mov     r7, r13
                            add     r7, 1
                            call    _read_nn
                            mov     r6, r10;HL
                            call    _write_nn
                            add     r13, 3
                            ret
.X0Z2Q0P3:              ;<LD (nn),A>
                            mov     r7, r13
                            add     r7, 1
                            call    _read_nn
                            mov     r6, r8;A
                            call    _write_mem
                            add     r13, 3
                            ret
.X0Z2Q1:                jmp     [.X0Z2Q1P_+r3]
.X0Z2Q1P_:              dw      .X0Z2Q1P0
                        dw      .X0Z2Q1P1
                        dw      .X0Z2Q1P2
                        dw      .X0Z2Q1P3
.X0Z2Q1P0:              ;<LD A, (BC)>
                            mov     r7, r11;BC
                            call    _read_mem
                            mov     r8, r7;to A
                            add     r13, 1
                            ret
.X0Z2Q1P1:              ;<LD A, (DE)>
                            mov     r7, r12;DE
                            call    _read_mem
                            mov     r8, r7;to A
                            add     r13, 1
                            ret
.X0Z2Q1P2:              ;<LD HL, (nn)>
                            mov     r7, r13
                            add     r7, 1
                            call    _read_nn
                            mov     r10, r7;to HL
                            add     r13, 3
                            ret
.X0Z2Q1P3:              ;<LD A, (nn)>
                            mov     r7, r13
                            add     r7, 1
                            call    _read_mem
                            mov     r8, r7;to A
                            add     r13, 3
                            ret
.X0Z3:              cmp     r4, 0;Q
                    jne     .X0Z3Q1
.X0Z3Q0:            ;<INC rp[p]>
                        mov     r7, r3;P
                        call    _table_rp_read
                        mov     r6, r7
                        add     r6, 1
                        mov     r7, r3;P
                        call    _table_rp_write
                        add     r13, 1
                        ret
.X0Z3Q1:            ;<DEC rp[p]>
                        mov     r7, r3;P
                        call    _table_rp_read
                        mov     r6, r7
                        sub     r6, 1
                        mov     r7, r3;P
                        call    _table_rp_write
                        add     r13, 1
                        ret
.X0Z4:          ;<INC r[y]>
                    mov     r7, r1;Y
                    call    _table_r_read
                    add     r7, 1
                    mov     r0, r7
                    mov     r6, r7
                    and     r6, 0xFF
                    mov     r7, r1;Y
                    call    _table_r_write
                    mov     r1, r9
                    and     r1, 1;Carry save
                    mov     r9, r0
                    and     r9, 0x80;Sign remains
                    cmp     r0, 0
                    jne     .X0Z4_1
                    or      r9, 0x40;Set zero flag
            .X0Z4_1:cmp     r9, 128
                    jne     .X0Z4_2
                    or      r9, 0x04;Set PV
            .X0Z4_2:or      r9, r1;Keep carry flag
                    add     r13, 1
                    ret
.X0Z5:          ;<DEC r[y]>
                    mov     r7, r1;Y
                    call    _table_r_read
                    sub     r7, 1
                    mov     r0, r7
                    mov     r6, r7
                    and     r6, 0xFF
                    mov     r7, r1;Y
                    call    _table_r_write
                    mov     r1, r9
                    and     r1, 1;Carry save
                    mov     r9, r0
                    and     r9, 0x80;Sign remains
                    cmp     r0, 0
                    jne     .X0Z4_1
                    or      r9, 0x40;Set zero flag
            .X0Z4_1:cmp     r9, 127
                    jne     .X0Z4_2
                    or      r9, 0x04;Set PV
            .X0Z4_2:or      r9, r1;Keep carry flag
                    add     r13, 1
                    ret
.X0Z6:          ;<LD r[y], n>
                    mov     r7, r13
                    add     r7, 1
                    call    _read_mem
                    mov     r6, r7
                    mov     r7, r1
                    call    _table_r_write
                    add     r13, 2
                    ret
.X0Z7:              add     r13, 1;PC++
                    cmp     r1, 4
                    jbe     .X0Z7Y03
                    jmp     [{.X0Z7Y_ 4 -}+r1]  ;[.X0Z7Y_-4+r1]
.X0Z7Y_:            dw      .X0Z7Y4
                    dw      .X0Z7Y5
                    dw      .X0Z7Y6
                    dw      .X0Z7Y7
.X0Z7Y03:           ;Bit-op on A
                        mov     r7, r1;Y
                        mov     r6, 7;A
                        call    _table_rot_exec
                        ret
.X0Z7Y4:            ;<DAA> Not supported
                        ;add        r13, 1
                        hlt;ret
.X0Z7Y5:            ;<CPL>
                        xor     r8, 0xFF;Invert A
                        ret
.X0Z7Y6:            ;<SCF>
                        or      r9, 1;Set carry flag
                        ret
.X0Z7Y7:            ;<CCF>
                        xor     r9, 1;Invert carry flag
                        ret
.X1:            cmp     r7, 0x76
                je      .X1_HALT
    .X1_LD:     ;<LD r[y], r[z]>
                    mov     r7, r2;Z
                    call    _table_r_read
                    mov     r6, r7
                    mov     r7, r1;Y
                    call    _table_r_write
                    add     r13, 1
                    ret
    .X1_HALT:   ;<HALT>     TODO
                    ;add        r13, 1
                    hlt;ret
.X2:        ;<alu[y] r[z]>
                mov     r7, r2;Z
                call    _table_r_read
                mov     r6, r7
                mov     r7, r1;Y
                call    _table_alu_exec
                add     r13, 1
                ret
.X3:            jmp     [.X3Z_+r2]
.X3Z_:          dw      .X3Z0
                dw      .X3Z1
                dw      .X3Z2
                dw      .X3Z3
                dw      .X3Z4
                dw      .X3Z5
                dw      .X3Z6
                dw      .X3Z7
.X3Z0:          ;<RET cc[y]>
                    mov     r7, r1;Y
                    call    _table_cc
                    jz      .X3Z0_1
                    call    _stack_pop
                    mov     r13, r7
            .X3Z0_1:add     r13, 1
                    ret
.X3Z1:              cmp     r4, 0;Q
                    jne     .X3Z1Q1
.X3Z1Q0:            ;<POP rp2[p]>
                        call    _stack_pop
                        mov     r6, r7
                        mov     r7, r3;P
                        call    _table_rp2_write
                        add     r13, 1
                        ret
.X3Z1Q1:                jmp     [.X3Z1Q1P_+r3]
.X3Z1Q1P_:              dw      .X3Z1Q1P0
                        dw      .X3Z1Q1P1
                        dw      .X3Z1Q1P2
                        dw      .X3Z1Q1P3
.X3Z1Q1P0:              ;<RET>
                            call    _stack_pop
                            mov     r13, r7
                            ret
.X3Z1Q1P1:              ;<EXX>
                            mov     r0, [M_SHL]
                            mov     [M_SHL], r10;HL
                            mov     r10, r0;HL
                            mov     r1, [M_SBC]
                            mov     [M_SBC], r11;BC
                            mov     r11, r1;BC
                            mov     r2, [M_SDE]
                            mov     [M_SDE], r12;DE
                            mov     r12, r2;DE
                            add     r13, 1
                            ret
.X3Z1Q1P2:              ;<JP HL>
                            mov     r13, r10
                            ret
.X3Z1Q1P3:              ;<LD SP, HL>
                            mov     [M_SP], r10
                            add     r13, 1
                            ret
.X3Z2:          ;<JP cc[y], nn>
                    mov     r7, r1;Y
                    call    _table_cc
                    jz      .X3Z1_1
                    mov     r7, r13
                    add     r7, 1
                    call    _read_nn
                    mov     r13, r7
                    ret
            .X3Z1_1:add     r13, 3
                    ret
.X3Z3:              jmp     [.X3Z3Y_+r1]
.X3Z3Y_:            dw      .X3Z3Y0
                    dw      executeCBprefix;<CB prefix>
                    dw      .X3Z3Y2
                    dw      .X3Z3Y3
                    dw      .X3Z3Y4
                    dw      .X3Z3Y5
                    dw      .X3Z3Y6
                    dw      .X3Z3Y7
.X3Z3Y0:            ;<JP nn>
                        mov     r7, r13
                        add     r7, 1
                        call    _read_nn
                        mov     r13, r7
                        ret
.X3Z3Y2:            ;<OUT (n), A> TODO
                        mov     r0, 0
                        cmp     r8, 0xFF
                        jne     .X3Z3Y2_2
                        mov     r1, [RT2_LINE]
                        send    r0, r1;Cursor 0,0 (0x10YX)
                        add     r1, 0x0010
                        cmp     r1, 0x10C0
                        jb      .X3Z3Y2_1
                        mov     r1, 0x1000
            .X3Z3Y2_1:  mov     [RT2_LINE], r1
                        jmp     .X3Z3Y2_3
            .X3Z3Y2_2:  send    r0, r8;R2IO 0,A
            .X3Z3Y2_3:  add     r13, 2
                        ret
.X3Z3Y3:            ;<IN A, (n)> TODO
                        ;add        r13, 1
                        hlt;ret
.X3Z3Y4:            ;<EX (SP), HL>
                        mov     r0, r10;HL
                        mov     r1, [M_SP]
                        mov     r7, r1
                        call    _read_nn
                        mov     r10, r7
                        mov     r7, r1
                        mov     r6, r0
                        call    _write_nn
                        add     r13, 1
                        ret
.X3Z3Y5:            ;<EX DE, HL>
                        xor     r10, r12
                        xor     r12, r10
                        xor     r10, r12
                        add     r13, 1
                        ret
.X3Z3Y6:            ;<DI> Interrupts not supported
                        ;add        r13, 1
                        hlt;ret
.X3Z3Y7:            ;<EI> Interrupts not supported
                        ;add        r13, 1
                        hlt;ret
.X3Z4:          ;<CALL cc[y], nn>
                    add     r13, 3
                    mov     r7, r1;Y
                    call    _table_cc
                    jz      .X3Z4_1
                    call    _stack_push
                    mov     r7, r13
                    sub     r7, 2
                    call    _read_nn
                    mov     r13, r7
            .X3Z4_1:ret
.X3Z5:              cmp     r4, 0;Q
                    jne     .X3Z5Q1
.X3Z5Q0:            ;<PUSH rp2[p]>
                        mov     r7, r3;P
                        call    _table_rp2_read
                        call    _stack_push
                        add     r13, 1
                        ret
.X3Z5Q1:                jmp     [.X3Z5Q1P_+r3]
.X3Z5Q1P_:              dw      .X3Z5Q1P0
                        dw      .X3Z5Q1P1
                        dw      executeEDprefix;<ED prefix>
                        dw      .X3Z5Q1P3
.X3Z5Q1P0:              ;<CALL nn>
                            mov     r7, r13
                            add     r7, 3
                            call    _stack_push
                            mov     r7, r13
                            add     r7, 1
                            call    _read_nn
                            mov     r13, r7
                            ret
.X3Z5Q1P1:              ;<DD prefix> Not supported
                            ;add        r13, 1
                            hlt;ret
.X3Z5Q1P3:              ;<FD prefix> Not supported
                            ;add        r13, 1
                            hlt;ret
.X3Z6:          ;<alu[y] n>
                    mov     r7, r13
                    add     r7, 1
                    call    _read_mem
                    mov     r6, r7
                    mov     r7, r1;Y
                    call    _table_alu_exec
                    add     r13, 2
                    ret
.X3Z7:          ;<RST y*8>
                    mov     r7, r13
                    add     r7, 1
                    call    _stack_push
                    mov     r13, r1;Y
                    shl     r13, 3;y*8
                    ret
;#################Z80 emulator code ending here!##################

;###########Z80 memory starting here!###############
            ;org        0x0800

            ;SP and shadow registers
M_SP:       dw      0x0000
M_SAF:      dw      0x0000
M_SHL:      dw      0x0000
M_SBC:      dw      0x0000
M_SDE:      dw      0x0000

            ;Demo program (16 bit Fibonacci seq)
M_RAM:      dw      0x21, 0x00, 0x00, 0x01, 0x01, 0x00, 0x54, 0x5D
            dw      0x09, 0x42, 0x4B, 0xCD, 0x10, 0x00, 0x18, 0xF6
            dw      0x7C, 0xCD, 0x1D, 0x00, 0x7D, 0xCD, 0x1D, 0x00
            dw      0x3E, 0xFF, 0xD3, 0x00, 0xC9, 0x5F, 0xCB, 0x3F
            dw      0xCB, 0x3F, 0xCB, 0x3F, 0xCB, 0x3F, 0xCD, 0x30
            dw      0x00, 0x7B, 0xE6, 0x0F, 0xCD, 0x30, 0x00, 0xC9
            dw      0xC6, 0x30, 0xFE, 0x3A, 0x38, 0x02, 0xC6, 0x07
            dw      0xD3, 0x00, 0xC9
;###########Z80 memory ending here!###############
