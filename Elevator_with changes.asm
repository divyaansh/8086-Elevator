
; You may customize this and other start-up templates; 
; The location of this template is c:\emu8086\inc\0_com_template.txt

org 100h

PUSH_ALL MACRO; Macro to push various registers on to the stack
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH BP
ENDM 


POP_ALL MACRO; Macro to pop various registers from the stack
    POP BP
    POP DX
    POP CX
    POP BX
    POP AX
ENDM


MOTOR_UP MACRO;Macro to make the motor move up
    PUSH_ALL
    MOV AL,0A0H;The motor moves up if it receives a signal 1010b
    OUT PORTC,AL;This is done using the portc upper
    POP_ALL
ENDM         


MOTOR_DOWN MACRO;Macro to make the motor move down
    PUSH_ALL
    MOV AL,50H;The motor moves down if it receives a signal 0101b
    OUT PORTC,AL;This is done using portc upper
    POP_ALL
ENDM 


MOTOR_OFF MACRO;Macro to turn off the motor
    PUSH_ALL
    XOR AL,AL;The motor switches off if it receives a signal 0000b
    OUT PORTC,AL;This done by using portc upper
    POP_ALL
ENDM


DOOR_OPEN MACRO;Macro to open the door
    PUSH_ALL
    MOV AL,0AH;Door opens if it receives the signal 1010b
    OUT PORTC,AL;This is done using the portc lower
    POP_ALL
ENDM


DOOR_CLOSE MACRO;Macro to close the door
    PUSH_ALL
    MOV AL,05H;Door closes if it receives the signal 0101b
    OUT PORTC,AL;This is done using portc lower
    POP_ALL
ENDM

.ORG 0100H

.MODEL TINY

.DATA
    TABLE_1 DB 06H,05H,03H;Lookup Table - limit switches
    TABLE_2 DB 00H,01H,02H;Lookup Table - 7 seg displays
    ;TABLE_3 DB
    PORTA EQU 10H;Address of porta
    PORTB EQU 12H;Address of portb
    PORTC EQU 14H;Address of portc
    CREG1 EQU 16H;Address of the control register of the 8255


.CODE
    .STARTUP
    ;CLI
    MOV AL,90h; Control word to the 8255,basic i/o mode,porta-input(mode 0),portb-
    ;output(mode 0),portc-output
    OUT CREG1,AL;
    XOR AX,AX; Initializing the Interrupt Vector Table
    MOV ES,AX; The DI register acts as a pointer to the extra segment
    MOV DI,08H; The starting address location for the interrupt vector corresponding to NMI
    MOV AX,OFFSET EMERGENCY;IP is stored
    STOSW
    MOV AX,CS;CS is stored
    STOSW
    CALL RESET;Bringing the lift to the ground floor, as the system is reset
    CALL DOOR;Opening the door
    ;STI;Setting the interrupt flag
    ;CALL SWITCH_STATUS; Waiting for an interrupt
    HERE: CALL SWITCH_STATUS
	CALL WAIT  
    CMP BX,03H
    JZ HERE
    CMP AX,BX
    JZ HERE
    CALL STANDARD
	JMP HERE
.EXIT

WAIT PROC NEAR;   
 	PUSH AX
  	PUSH CX
 	PUSH DX  
	IN AL,PORTA
	CALL DELAY_10MS
	CALL DELAY_10MS
	IN AL,PORTA
 	XOR BX,BX
 	MOV BL,AL
 	AND BL,38H
	XOR DI,DI
    SHR BL,03H
 	MOV CX,03H
  	YS1: CMP BL,TABLE_1[DI]
  	JZ YS2
	INC DI
             LOOP YS1
             YS2: MOV BX,DI
 	POP DX
	POP CX
	POP AX
	RET
WAIT ENDP
	

RESET PROC NEAR; Reset Procedure
    PUSH_ALL
    XOR AX,AX; AX register is used to store the status
    CALL SWITCH_STATUS
    MOV DX,00H
    CMP AX,DX;Checking if the Lift is already in the ground Floor
    JZ DONE1
    MOTOR_DOWN
    AGAIN1:XOR AX,AX
    CALL SWITCH_STATUS
    CMP AX,DX
    JNZ AGAIN1
    MOTOR_OFF
    DONE1:POP_ALL
    RET
RESET ENDP 

    
    

EMERGENCY PROC NEAR;Emergency Procedure
    PUSH_ALL
    XOR AX,AX; AX register is used to store the status
    CALL SWITCH_STATUS
    MOV DX,00H
    CMP AX,DX;Checking if the Lift is already in the ground Floor
    JZ DONE
    MOTOR_DOWN
    AGAIN:XOR AX,AX
    CALL SWITCH_STATUS
    CMP AX,DX
    JNZ AGAIN
    MOTOR_OFF
    DONE:POP_ALL
    IRET
EMERGENCY ENDP 





STANDARD PROC NEAR
    PUSH_ALL
    SUB AX,BX ; Present Floor-Destination floor
    JZ LAST;
    AND AX,8000H; Obtaining the MSBit
    JZ DOWN; If positive the lift must move down
    MOTOR_UP; If not, the lift must move up
    WHILE1:CALL SWITCH_STATUS
    CMP AX,BX
    JNZ WHILE1
    MOTOR_OFF
    JMP LAST
    DOWN:MOTOR_DOWN
    WHILE2:CALL SWITCH_STATUS
    CMP AX,BX
    JNZ WHILE2
    MOTOR_OFF
    LAST: CALL DOOR
    POP_ALL
    RET
STANDARD ENDP


DOOR PROC NEAR
    PUSH_ALL
    DOOR_OPEN
    MOV CX,3E8H; 10s Counter value
    X:IN AL,PORTA
    AND AL,38H
    MOV BL,38H
    CMP AL,BL
    JNZ ENDING
    CALL DELAY_10MS
    LOOP X
    ENDING:DOOR_CLOSE
    POP_ALL
    RET
DOOR ENDP


SWITCH_STATUS PROC NEAR; Procedure that obtains the present status of the lift through
;the limit switches and returns it through AL.
    PUSH BX
    PUSH DI
    PUSH CX
    IN AL,PORTA
	CALL DELAY_10MS
	CALL DELAY_10MS
    IN AL,PORTA
	MOV BX,AX;
    AND BX,0007H;Obtaining the status of the limit switches
    XOR DI,DI;DI will act as counter
    MOV CX,03H
    XS1:CMP BL,TABLE_1[DI]
    JZ XS2
    INC DI
    LOOP XS1
    XS2:MOV AX,DI
    LEA BX,TABLE_2
    XLAT
    OUT PORTB,AL; Glowing the indicator panel through a 7447
    POP CX
    POP DI
    POP BX
    RET
SWITCH_STATUS ENDP 


DELAY_10MS PROC NEAR;Procedure to produce a 10 ms delay
    MOV DX,2272d
    X1:NOP
    DEC DX
    JNZ X1
    RET
DELAY_10MS ENDP



ret




