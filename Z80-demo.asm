ENTRY_POINT:
            LD      HL,0x0000
            LD      BC,0x0001
FIBONACCI_LOOP:
            LD      D,H
            LD      E,L
            ADD     HL,BC
            LD      B,D
            LD      C,E
            CALL    PRINT_HEX16
            JR      fibonacci_loop

PRINT_HEX16:
            LD      A,H
            CALL    PRINT_HEX8
            LD      A,L
            CALL    PRINT_HEX8
            LD      A,0xFF
            OUT     (0),A
            RET
PRINT_HEX8:
            LD      E,A
            SRL     A
            SRL     A
            SRL     A
            SRL     A
            CALL    PRINT_HEX4
            LD      A,E
            AND     0x0F
            CALL    PRINT_HEX4
            RET
PRINT_HEX4:
            ADD     A,"0"
            CP      "9"+1
            JR      c,notAf
            ADD     A,"A"-"9"-1
NOTAF:      OUT     (0),A
            RET
