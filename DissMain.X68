*-----------------------------------------------------------
* Title      : 68000 Disassembler (DASM)
* Written by : Team BEQ
*                Jonathan Hendrickson, Guiragos Guiragossian,
*                Dylan Thibault, Omar Nevarez
*
* Class      : CSS 422 A Sp 21 with Jim Hogg
* Description: A disassembler for 68k machine code.
*
* Register Structure: 
* D0 used for TRAP#15 I/O functions
* D1 used for secondary MACRO input (namely as a bit counter)
* D3 used for primary MACRO input (namely stores opcode which is being checked)
* D4 used as filler destination (e.g. we want to increment adr. but not store value)
* D5 used as temporary storage of opcode (when scanning next word for adr mode)
* D6 used for branch conditions (e.g. tracks state of single bit instruction field)
* D7 used for size marker and error validation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
*
* A1 used loading strings (for output and validation)
* A2 used for storing opcode currently being evaluated 
* A3 used for temporary storage when needed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
* NOT USED:   A0, A4 - A7 
*-----------------------------------------------------------

; ========================================================================
; Variables
; ========================================================================

; TEMP
rSTART: DC.B    'Enter the starting address (4 digit hex number):',0
rEND:   DC.B    'Enter the ending address (4 digit hex number):',0

; ------------------------------------------------------------
; "convertAtoH" Helper
; Jonathan
;
; 1st argument is a data register containing an ASCII character
;
; Converts the argument from an ASCII character to hex
; ------------------------------------------------------------
convertAtoH:    MACRO
        CMPI.B  #$39, \1
        BGT     alpha\@
        SUBI.B  #$30, \1    ; Subtract 30 to convert digit char to hex
        BRA     done\@
alpha\@: SUBI.B #$37, \1    ; Subtract 37 to convert A-F char to hex
done\@: NOP
        ENDM
; ------------------------------------------------------------
; "printMoveMBits" Helper
; Dylan
;
; First version which operates through a loop going through each bit
; ------------------------------------------------------------
printMoveMBits:    MACRO
    * load memory into register
    * D1 is loop counter
    * D2 is shift register
    * D3 is AND register
    CLR.L   D1
    CLR.L   D2
    CLR.L   D3

    MOVE.W  \1, D2
    
    * check the last bit
rptShift\@:
    * copy shifted bits into AND register
    MOVE.W  D2, D3
    * and the bits with 1 to get the last bit
    ANDI.W  #1, D3
    * compare with 1
    CMPI.W  #1, D3
    BEQ     bitOne\@

    * left shift
    LSL.W   #1, D2
    ADD.W   #1, D1

    * check if done and repeat
    CMPI.W  #16, D1
    BLT     rptShift\@
    BGE        done\@

    * bit was one, print the register
bitOne\@:
    CMPI.W  #8, D1
    BLT     printData\@
    BSR     printAddr\@

    RTS

    * print the register with number
printData\@:
    * unfinished
    prepareAdrMode  #$1, (A2)
    decodeAdrMode   (A2), D1
    printComma
    RTS

    * print register (subtract 8 from the counter)
printAddr\@:

    RTS

done\@: NOP
        ENDM

; ------------------------------------------------------------
; "readInput" Helper
; Jonathan
;
; 1st argument is data register where input is stored
;
; Reads input and converts ascii to hex.
; ------------------------------------------------------------
readInput:    MACRO
        ; Read user's input
        MOVE.B  #5, D0      ; Read first digit
        TRAP    #15
        convertAtoH D1      ; Convert to hex
        LSL.W   #8, D1      ; Shift left 8 bits
        LSL.W   #4, D1      ; Shift left additional 4 bits (1st digit)
        MOVE.W  D1, D2      ; Store in D2
        
        MOVE.W  #0, D1      ; Clear D1
        TRAP    #15         ; Read second digit
        convertAtoH D1
        LSL.W   #8, D1      
        ADD.W   D1, D2
        
        MOVE.W  #0, D1      ; Clear D1
        TRAP    #15         ; Read third digit
        convertAtoH D1
        LSL.W   #4, D1      
        ADD.W   D1, D2
        
        MOVE.W  #0, D1      ; Clear D1
        TRAP    #15         ; Read final digit
        convertAtoH D1     
        ADD.W   D1, D2
        MOVE.W  D2, \1      ; Move to output
        ENDM

; ENDTEMP

; ------------------------------------------------------------
; "Output" Variables
; Gary
; 
; Set of strings to be used with I/O of given instruction
; ------------------------------------------------------------
oNOP:   DC.B    'NOP',0
oMOVE:  DC.B    'MOVE',0
oMOVEM: DC.B    'MOVEM',0
oADD:   DC.B    'ADD',0
oADDI:  DC.B    'ADDI',0
oSUB:   DC.B    'SUB',0
oMULS:  DC.B    'MULS.W ',0
oDIVU:  DC.B    'DIVU.W ',0
oLEA:   DC.B    'LEA',0
oAND:   DC.B    'AND',0
oNOT:   DC.B    'NOT',0
oLSL:   DC.B    'LSL',0
oLSR:   DC.B    'LSR',0
oASL:   DC.B    'ASL',0
oASR:   DC.B    'ASR',0
oBEQ:   DC.B    'BEQ',0
oBGE:   DC.B    'BGE',0
oBLT:   DC.B    'BLT',0
oJSR:   DC.B    'JSR',0
oRTS:   DC.B    'RTS',0
oBRA:   DC.B    'BRA',0
oBSize  DC.B    '.B ',0
oWSize  DC.B    '.W ',0
oLSize  DC.B    '.L ',0
oDn     DC.B    'D',0
oAn     DC.B    'A',0
oLB     DC.B    '(',0
oRB     DC.B    ')',0
oComma  DC.B    ', ',0
oPreDec DC.B    '-',0
oPstInc DC.B    '+',0
oHash   DC.B    '#',0
oBlank  DC.B    ' ',0
oTab    DC.B    '   ',0
oSLash  DC.B    '\',0
oWelcome DC.B   'Welcome to our 68k DASM!',0
; ------------------------------------------------------------
; "Pattern" Variables
; Jonathan
; 
; Set of strings to be used with verifyOpcode to check that the patterns match
; and the opcode isn't actually data
; ------------------------------------------------------------
pNOP:   DC.B    '0100111001110001',0
pMOVE:  DC.B    '00..............',0
pMOVEM: DC.B    '01001.001.......',0
pADD:   DC.B    '1101............',0
pSUB:   DC.B    '1001............',0
pMULS:  DC.B    '1100...111......',0
pDIVU:  DC.B    '1000...011......',0
pLEA:   DC.B    '0100...111......',0
pAND:   DC.B    '1100............',0
pNOT:   DC.B    '01000110........',0
pLSx_M: DC.B    '1110......001...',0
pLSx_R: DC.B    '1110......101...',0
pLSx_S: DC.B    '1110......100...',0
pASx_M: DC.B    '1110......000...',0
pASx_R: DC.B    '1110......100...',0
pASx_S: DC.B    '1110......100...',0
pBEQ:   DC.B    '01100111........',0
pBGE:   DC.B    '01101100........',0
pBLT:   DC.B    '01101101........',0
pJSR:   DC.B    '0100111010......',0
pRTS:   DC.B    '0100111001110101',0
pBRA:   DC.B    '01100000........',0


; ========================================================================
; Macros
; ========================================================================
; ------------------------------------------------------------
; "convertHtoA" Helper
; Jonathan
;
; 1st argument is a data register containing a single digit of a hex number.
;
; Converts the argument from a hex digit to an ascii character
; ------------------------------------------------------------
convertHtoA:    MACRO
        CMPI.B  #9, \1      ; If greater than 9, this is an alphanumeric char
        BGT     alpha\@
        ADDI.B  #$30, \1    ; Add 30 to convert digit to ascii char
        BRA     done\@
alpha\@: ADDI.B #$37, \1    ; AAdd 37 to convert A-F to ascii char
done\@: NOP
        ENDM
; ------------------------------------------------------------
; adrOut
; Gary
;
; Outputs the adress currently in A2 in hex form.
; ------------------------------------------------------------
adrOut:         MACRO
        MOVE.B  #6, D0      ; Prepare TRAP 15 for outputting a character in D1
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSL.W   #4, D1      ; Remove the first 4 bits (1 digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSL.W   #4, D1      ; Remove the first 4 bits (1 more digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output   
        ENDM     
; ------------------------------------------------------------
; adrOutInput
; Gary
;
; Outputs the given argument register currently in A2 in hex form.
; ------------------------------------------------------------      
        
adrOutInput:         MACRO
        MOVE.L   \1, D7     
        MOVE.B  #6, D0      ; Prepare TRAP 15 for outputting a character in D1
        MOVE.W  D7, D1    
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  D7, D1    
        LSL.W   #4, D1      ; Remove the first 4 bits (1 digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  D7, D1    
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  D7, D1    
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSL.W   #4, D1      ; Remove the first 4 bits (1 more digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output       
        ENDM 
; ------------------------------------------------------------
; "verifyOpcode" Helper
; Jonathan
;
; 1st argument is a template string (e.g. "0100...111......" for LEA)
; 2nd argument is a data register to check against the template
;
; Verifies that the opcode passed through \2 matches the pattern of \1
; If they do not match, branches to outputData
; ------------------------------------------------------------
verifyOpcode:  MACRO
        LEA     \1, A1      ; Input pattern string
        MOVE.W  \2, D3      ; input value
        MOVE.B  #15, D1     ; Counter tracking the bit position of D3
        
loop\@: 
        CMP.B   #$30, (A1)  ; Check if the template wants a 0
        BEQ     checkFor0\@
        CMP.B   #$31, (A1)  ; Check if the template wants a 1
        BEQ     checkFor1\@
        BRA     next\@      ; Template has a wildcard, go to next iteration
        
checkFor0\@: 
        BTST    D1, D3      ; Check if contains 0
        BNE     outputData  ; Missing a 0 -> Not a valid opcode
        BRA     next\@

checkFor1\@:
        BTST    D1, D3      ; Check if contains 1
        BEQ     outputData  ; Missing a 1 -> Not a valid opcode

next\@: 
        CMP.B   #0, D1      ; Compare bit counter to 0
        BEQ     complete\@  ; Branch to complete if bit counter reached 0
        SUB.B   #1, D1      ; Continuing loop -> Decrement bit counter
        MOVE.B  (A1)+, D4   ; Move A1 to the next pointer (D3 irrelevant)
        BRA     loop\@      ; Begin loop again

complete\@:  ; Opcode has been verified
        ENDM
        
; ------------------------------------------------------------
; "printSize" Helper
; Gary
;
; 1st argument is the data register with opcode whose size is being decoded.
;
; Used in opcodes whose size bits are #13 and #12 (e.g. MOVE). It does so
; by sequentally checking both bits. Bit #13 differentiates byte and word size.
; If bit goes to word, bit #12 is checked to differntiate word and long word.
; Once matched, size is printed and appended to already printed opcode (TRAP #15 no CR,LF).
; ------------------------------------------------------------
printSize:  MACRO
        MOVE.W  \1, D3      ; input value
        CLR     D7      
checkForB\@: 
        BTST    #13, D3      ; Check if contains 0
        BNE     checkForW\@  ; If not go to word size
        LEA     oBSize, A1   ; If bit #13 is 0, size is byte and macro ends. 
        MOVE.B  #14,D0          
        TRAP    #15
        BRA     complete\@      
checkForW\@: 
        BTST    #12, D3      ; Check if contains 1
        BEQ     checkForL\@  ; If not, size cannot be word
        LEA     oWSize, A1   ; If bit #12 is 1, size is word and macro ends.  
        MOVE.B  #14,D0          
        TRAP    #15
        BRA     complete\@  
checkForL\@:
        MOVE.B  #$1, D7
        LEA     oLSize, A1   ; If bit #12 is 0, size is longword and macro ends.  
        MOVE.B  #14,D0          
        TRAP    #15
complete\@:  ; Size has been printed
        ENDM
        
; ------------------------------------------------------------
; "printSizeLow" Helper
; Gary
;
; 1st argument is the data register with opcode whose size is being decoded
;
; Used in opcodes whose size bits are #6 and #7 (e.g. ADD). It does so
; by sequentally checking both bits. Bit #6 differentiates byte and word size.
; If bit goes to word, bit #7 is checked to differntiate word and long word.
; Once matched, size is printed and appended to already printed opcode, macro exits.
; ------------------------------------------------------------
printSizeLow:  MACRO
        MOVE.W  \1, D3      ; input value   
        CLR     D7   
checkForB\@: 
        BTST    #6,  D3      ; Check if contains 0
        BNE     checkForW\@  ; If not go to word size
        BTST    #7, D3      ; Check if contains 0
        BNE     checkForL\@ ; If not go to longword size
        LEA     oBSize, A1     
        MOVE.B  #14,D0       ; Print and end macro  
        TRAP    #15
        BRA     complete\@      
checkForW\@: 
        LEA     oWSize, A1     
        MOVE.B  #14,D0       ; Print and end macro       
        TRAP    #15
        BRA     complete\@  
checkForL\@:
        MOVE.B  #$1, D7
        LEA     oLSize, A1   ; If both bits are #1, size is longword and macro ends.  
        MOVE.B  #14,D0       ; Print and end macro  
        TRAP    #15
complete\@:  ; Size has been printed
        ENDM
; ------------------------------------------------------------
; "decodeSizeLow" Helper
; Gary
;
; 1st argument is the data register with opcode whose size is being decoded
;
; Used in opcodes whose size bits are #6 and #7 (e.g. ADD). It does so
; by sequentally checking both bits. Bit #6 differentiates byte and word size.
; If bit goes to word, bit #7 is checked to differntiate word and long word.
; Different from printSize because it does not print. Instead it preapres
; D6 to be used for size validation in decode methods.
; ------------------------------------------------------------
decodeSizeLow:  MACRO
        MOVE.W  \1, D3      ; input value   
        CLR     D6   
checkForBorW\@: 
        BTST    #7, D3      ; Check if contains 0
        BNE     checkForL\@ ; If not go to longword size         
        BRA     complete\@  
checkForL\@:
        MOVE.B  #$1, D6
complete\@:  ; Size has been checeked
        ENDM 
 ; ------------------------------------------------------------
; "decodeDisplacement" Helper
; Gary
; 
; Decodes branching displacement by checking last byte then
; scanning the appropriate amount of subsequent words.
; ------------------------------------------------------------
decodeDisplacement:  MACRO
        MOVE.W \1, D3           
        CLR     D1
        MOVE.W  A2, D7
        CMP.B   #$0, D3
        BEQ     Sbit\@
        CMP.B   #$FF, D3
        BEQ     Tbit\@
Ebit\@:   
        LSL     #08, D3
        LSR     #08, D3
        EXT.L   D3
        ADD.L   D3, D7
        ADD.L   #2, D7
        adrOutInput D7     
        BRA     decodeDisplacement\@
Sbit\@:  
        MOVE.W  (A2)+, D3  ; Increment A2 (D4 isn't relevant)
        EXT.L    D3
        ADD.L   D3, D7
        ADD.L   #2, D7
        adrOutInput D7
        BRA     decodeDisplacement\@
Tbit\@:  
        MOVE.W  (A2)+, D3  ; Increment A2 (D4 isn't relevant)
        EXT.L   D3
        SWAP    D3
        MOVE.W  (A2)+, D3   ; Increment A2 (D4 isn't relevant)
        ADD.L   D3, D7
        ADD.L   #2, D7
        adrOutInput D7
decodeDisplacement\@:
        ENDM        
               
; ------------------------------------------------------------
; "printOpMode" Helper
; Gary
;
; 1st argument holds opcode whose opmode is being decoded
;
; With the opcode in D3, D1 is designated as the bit tracker. Split
; into two sorting mechanisms: first, the macro determines whether
; the register is a source or a destination. Then, the macro determines
; the size and appends it to printed opcode in a similar manner to printSize.
; ------------------------------------------------------------
printOpMode:  MACRO
        MOVE.W  \1, D3      
        MOVE.B  #8, D1    
        CLR     D6
        CLR     D7
checkForDestDn\@: 
        BTST    D1, D3      
        BNE     checkForSrcDn\@
        JSR     next\@
        MOVE.B  #$1, D6
        BTST    D1, D3      
        BEQ     DestDnW\@
DestDnL\@:        
        LEA     oLSize, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.B  #$1, D7
        BRA     complete\@ 
DestDnW\@: 
        JSR     next\@
        BTST    D1, D3      
        BEQ     DestDnB\@
        LEA     oWSize, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        BRA     complete\@ 
DestDnB\@: 
        LEA     oBSize, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        BRA     complete\@ 
checkForSrcDn\@: 
        JSR     next\@
        BTST    D1, D3      
        BEQ     SrcDnW\@
SrcDnL\@:        
        LEA     oLSize, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.B  #$1, D7
        printDnDest D3
        BRA     complete\@ 
SrcDnW\@:
        JSR     next\@
        BTST    D1, D3     
        BEQ     SrcDnB\@
        LEA     oWSize, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        printDnDest D3
        BRA     complete\@ 
SrcDnB\@: 
        LEA     oBSize, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        printDnDest D3
        BRA     complete\@ 

next\@:
        SUB.B   #1, D1      ; Continuing loop -> Decrement bit counter
        RTS                

complete\@:  ; Opcode has been verified
        ENDM
; ------------------------------------------------------------
; "prepareAdrMode" Helper
; Gary
; 
; Shifts bits of a given opcode so that D1 contains only ADRmode.
; ------------------------------------------------------------
prepareAdrMode: MACRO
        MOVE.W  \1, D6      ; input value
        MOVE.W  \2, D1
        CMP.B   #$01, D6
        BEQ     AdrSource\@    
AdrDest\@:
        LSL     #$07, D1   ; If 0 is passed, bits left are 6 to 8
        LSR     #$08, D1
        LSR     #$05, D1
        BRA     complete\@ 
AdrSource\@:                
        LSL     #$08, D1    ; If 1 is passed, bits left are 3 to 5
        LSL     #$02, D1
        LSR     #$08, D1
        LSR     #$05, D1
complete\@:  ; Opcode has been verified
        ENDM        
        
; ------------------------------------------------------------
; "decodeAdrMode" Helper
; Gary
; 
; Executes after prepare macro on D1 which contains only adressing mode
; bits. It sorts by comparing D1 register to value to unique added up
; bits which represent adresssing mode form.
; ------------------------------------------------------------
decodeAdrMode:  MACRO
        MOVE.W  \1, D3      ; holds full opcode
        MOVE.W  \2, D1      ; holds just opmode

        CMP.B   #$01, D1
        BEQ     AdrRegDirect\@    
        CMP.B   #$02, D1
        BEQ     AdrRegInDirect\@  
        CMP.B   #$03, D1
        BEQ     AdrRegPostInc\@  
        CMP.B   #$04, D1
        BEQ     AdrRegPreDec\@
        CMP.B   #$07, D1
        BEQ     AdrAbsolute\@    
        
dataRegDirect\@: 
        CMP.B   #$01, D6
        BEQ     dataRegDirectSrc\@   
dataRegDirectDest\@: 
        printDnDest D3 
        BRA     complete\@ 
dataRegDirectSrc\@: 
        printDnSrc D3 
        BRA     complete\@   
        
AdrRegDirect\@: 
        CMP.B   #$01, D6
        BEQ     AdrRegDirectSrc\@   
AdrRegDirectDest\@:
        printAnDest D3
        BRA     complete\@   
AdrRegDirectSrc\@:
        printAnSrc D3
        BRA     complete\@   
       
AdrRegInDirect\@:   
        CMP.B   #$01, D6
        BEQ     AdrRegInDirectSrc\@   
AdrRegInDirectDest\@:
        printLB
        printAnDest D3  
        printRB
        BRA     complete\@     
AdrRegInDirectSrc\@:   
        printLB
        printAnSrc D3  
        printRB
        BRA     complete\@   
        
AdrRegPostInc\@:   
        CMP.B   #$01, D6
        BEQ     AdrRegPostIncSrc\@   
AdrRegPostIncDest\@: 
        printLB
        printAnDest D3  
        printRB
        printPI
        BRA     complete\@  
AdrRegPostIncSrc\@:           
        printLB
        printAnSrc D3  
        printRB
        printPI
        BRA     complete\@  
AdrRegPreDec\@: 
        CMP.B   #$01, D6
        BEQ     AdrRegPreDecSrc\@   
AdrRegPreDecDest\@:
        printPD  
        printLB
        printAnDest D3  
        printRB
        BRA     complete\@   
AdrRegPreDecSrc\@: 
        printPD  
        printLB
        printAnSrc D3  
        printRB
        BRA     complete\@
       
AdrAbsolute\@:
        CMP.B   #$01, D6
        BNE     AdrAbsoluteDst\@ 
        
        MOVE.W  D3, D5
        BTST    #2, D3
        BNE     AdrImmediate\@
        BTST    #0, D3
        BNE     AdrAbsoluteL\@
        BRA     AdrAbsoluteW\@
AdrAbsoluteDst\@:
        MOVE.W  D3, D5
        BTST    #$B, D3
        BNE     AdrImmediate\@
        BTST    #$09, D3
        BNE     AdrAbsoluteL\@
        BRA     AdrAbsoluteW\@
AdrImmediate\@:
        CMP.B   #1, D7
        BEQ     AdrImmediateL\@
AdrImmediateW\@:
        MOVE.W  (A2)+, D3
        printHash
        printSign
        adrOut
        MOVE.W  D5, D3
        BRA     complete\@
AdrImmediateL\@:
        MOVE.W  (A2)+, D3
        printHash
        printSign
        adrOut 
        MOVE.W  (A2)+, D3
        adrOut
        MOVE.W  D5, D3
        BRA     complete\@ 
AdrAbsoluteW\@:     
        MOVE.W  (A2)+, D3
        printSign
        adrOut
        MOVE.W  D5, D3
        BRA     complete\@  
AdrAbsoluteL\@:  
        MOVE.W  (A2)+, D3
        printSign
        adrOut 
        MOVE.W  (A2)+, D3
        adrOut
        MOVE.W  D5, D3

complete\@:  ; Opcode has been verified
        ENDM
; ------------------------------------------------------------
; "printCount" Helper
; Gary
; 
; Prints bits 9 to 11 with a hash in front.
; ------------------------------------------------------------
printCount:     MACRO
        MOVE.W  \1, D1      ; bits 9 to 11
        LSL     #$04, D1
        LSR     #$08, D1
        LSR     #$05, D1
        LEA     oHash, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.B  #3,D0          
        TRAP    #15
        ENDM
; ------------------------------------------------------------
; "printDnDest" Helper
; Gary
; 
; Prints bits 9 to 11 which represent data register destination.
; ------------------------------------------------------------
printDnDest:    MACRO 
        MOVE.W  \1, D1      ; bits 9 to 11
        LSL     #$04, D1
        LSR     #$08, D1
        LSR     #$05, D1
        LEA     oDn, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.B  #3,D0          
        TRAP    #15
        ENDM
; ------------------------------------------------------------
; "printDnSrc" Helper
; Gary
; 
; Prints bits 0 to 2 which represent data register source.
; ------------------------------------------------------------
printDnSrc:    MACRO   
        CLR.L   D1
        MOVE.W  \1, D1   ; bits 0 to 2
        LSL     #$08, D1
        LSL     #$05, D1
        LSR     #$08, D1
        LSR     #$05, D1
        LEA     oDn, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.B  #3,D0          
        TRAP    #15
        ENDM
; ------------------------------------------------------------
; "printAnDest" Helper
; Gary
; 
; Prints bits 9 to 11 which represent adress register destination.
; ------------------------------------------------------------
printAnDest:    MACRO
        MOVE.W  \1, D1
        LSL     #$04, D1 ; bits 9 to 11
        LSR     #$08, D1
        LSR     #$05, D1
        LEA     oAn, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.B  #3,D0          
        TRAP    #15
        ENDM
; ------------------------------------------------------------
; "printAnSrc" Helper
; Gary
; 
; Prints bits 0 to 2 which represent adress register source.
; ------------------------------------------------------------
printAnSrc:    MACRO   
        MOVE.W  \1, D1   ; bits 0 to 2
        LSL     #$08, D1
        LSL     #$05, D1
        LSR     #$08, D1
        LSR     #$05, D1
        LEA     oAn, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.B  #3,D0          
        TRAP    #15
        ENDM
; ------------------------------------------------------------
; "printAdr" Helper
; Gary
; 
; Unused old version of ADROUT.
; ------------------------------------------------------------        
printAdr:      MACRO
        MOVE.W  A2, D1    ; Move A2 into D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        MOVE.B  #6, D0      ; Read first digit
        TRAP    #15         ; Execute output
        
        MOVE.W  A2, D1    ; Move A2 into D1
        LSL.W   #4, D1      ; Remove the first 4 bits (1 digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        MOVE.B  #6, D0      ; Read first digit
        TRAP    #15         ; Execute output
        
        MOVE.W  A2, D1    ; Move A2 into D1
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        MOVE.B  #6, D0      ; Read first digit
        TRAP    #15         ; Execute output
        
        MOVE.W  A2, D1    ; Move A2 into D1
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSL.W   #4, D1      ; Remove the first 4 bits (1 more digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        MOVE.B  #6, D0      ; Read first digit
        TRAP    #15         ; Execute output       
        ENDM
printComma:    MACRO
        LEA     oComma, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        ENDM
printPI:    MACRO
        LEA     oPstInc, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        ENDM
printPD:    MACRO
        LEA     oPreDec, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        ENDM

printLB:    MACRO
        LEA     oLB, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        ENDM
printRB:    MACRO
        LEA     oRB, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        ENDM
printSign:  MACRO
        MOVE.B  #6, D0      ; Prepare TRAP 15 for outputting a character in D1
        MOVE.W  #36, D1     ; An = sign
        TRAP    #15         ; Output = sign
        ENDM
printHash:  MACRO
        MOVE.B  #6, D0      ; Prepare TRAP 15 for outputting a character in D1
        MOVE.W  #35, D1     ; An = sign
        TRAP    #15         ; Output = sign
        ENDM
        
space:      MACRO
        LEA     oBlank, A1
        MOVE.B  #14,D0          
        TRAP    #15
        ENDM
tab:       MACRO
        LEA     oTab, A1
        MOVE.B  #14,D0          
        TRAP    #15
        ENDM
        
newLine:    MACRO
        LEA     oBlank, A1
        MOVE.B  #13,D0          
        TRAP    #15
        ENDM

slash:      MACRO
        LEA     oSlash, A1
        MOVE.B  #13,D0          
        TRAP    #15
        ENDM
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; "main" routine
; Dylan, Gary, Jonathan
; 
; Iterates through memory word-by-word using post increment mode after
; requesting user input.
; ========================================================================
        ORG     $1000
        OPT     MEX
        
main:   LEA     oWelcome, A1  ; Welcome Message
        MOVE.B  #13, D0
        TRAP    #15
        newline
        
        LEA     rSTART, A1  ; Request starting address
        MOVE.B  #13, D0
        TRAP    #15
        readInput   D2      ; Read 4 digit hex input
        MOVE.W  D2, A2      ; Store the address in A2
        newline
        
        LEA     rEND, A1    ; Request ending address
        MOVE.B  #13, D0
        TRAP    #15
        readInput   D2      ; Read 4 digit hex input
        MOVE.W  D2, ($990)  ; Store at mem location $990
        newline
        newline
        
goLoop: MOVE.L  #0, D1
        MOVE.W  ($990), D1
        MOVE.L  A2, D2
        CMP.L   D2, D1    ; Check if the loop is over
        BLE     endSim      ; A2 is past the loop start if this is reached
        printAdr
        tab
        JSR     identifyOpcode  ; Decode what is at A2
        MOVE.W  (A2)+, D4   ; Increment A2 (D1 isn't relevant)
        newline
        BRA     goLoop
        
        
        
endSim: SIMHALT             ; halt simulator
        
        
; ========================================================================
; "identifyOpcode" subroutine
; Jonathan
; 
; Reads the Word at A2 and determines which opcode it represents.
; When the opcode is identified, the appropriate "decodeX" subroutine
; is invoked.
;
; Uses a generated Trie structure to determine where to split on which bits
; in order to efficiently identify the exact opcode
; ========================================================================
identifyOpcode:
        MOVE.W  (A2), D3    ; Move the value at A2 into D3 for bit testing
        BTST    #$F, D3     ; Check the 1st bit (from the left)
        BEQ     split0      ; Split based on the first bit
        BRA     split1

split0: 
        BTST    #$E, D3     ; Check the 2nd bit
        BEQ     split000    ; MOVE follows 00+        
        BRA     split01
        
split000:        
        BTST    #$D, D3     ; Check the 3rd bit
        BNE     decodeMOVE
        BTST    #$C, D3     ; Check the 3rd bit
        BNE     decodeMOVE
        BRA     decodeImmediate
split01:
        BTST    #$D, D3     ; Check the 3rd bit
        BEQ     split0100   ; Code is 010, but all subcodes are 0100
        BRA     split0110   ; Code is 011, but all subcodes are 0110        

split0100:
        BTST    #$8, D3     ; Check the 8th bit for LEA
        BNE     decodeLEA   ; LEA follows 0100XXX1+
        BTST    #$B, D3     ; Check the 5th bit for NOT
        BEQ     decodeNOT   ; NOT follows 01000+
        BTST    #$9, D3     ; Check the 7th bit
        BEQ     decodeMOVEM ; MOVEM follows 01001x0+
        BRA     split0100111

split0100111:
        BTST    #$7, D3     ; Check the 9th bit for JSR
        BNE     decodeJSR   ; JSR follows 010011101+
        BTST    #$2, D3     ; Check the 14th bit
        BEQ     decodeNOP   ; NOP follows 01001110011100+
        BRA     decodeRTS   ; RTS follows 01001110011101+

split0110:
        BTST    #$B, D3     ; Check the 5th bit
        BEQ     split01100
        BRA     split01101

split01100:
        BTST    #$A, D3     ; Check the 6th bit
        BEQ     decodeBRA   ; BRA starts with 011000
        BTST    #$C, D3     ; Check the 6th bit
        BNE     outputData  ; MOVEQ
        BRA     decodeBEQ   ; BEQ starts with 011001
        
split01101:
        BTST    #$8, D3     ; Check the 8th bit
        BEQ     decodeBGE   ; BGE starts with 01101100
        BRA     decodeBLT   ; BLT starts with 01101101
        
split1: 
        BTST    #$E, D3     ; Check the 2nd bit
        BEQ     split10
        BRA     split11

split10:
        BTST    #$C, D3     ; Check the 4th bit
        BEQ     decodeDIVU  ; DIVU follows 1000+
        BRA     decodeSUB   ; SUB follows 1001+

split11:
        BTST    #$D, D3     ; Check the 3rd bit
        BEQ     split110
        BRA     split111

split110:
        BTST    #$C, D3     ; Check the 4th bit for ADD
        BNE     decodeADD   ; ADD follows 1101+
        BTST    #$8, D3     ; MULS.W has all 3 bits at 8, 9, and 10 set
        BEQ     decodeAND   ; If any of these BTSTs show a 0, opcode is AND
        BTST    #$7, D3
        BEQ     decodeAND
        BTST    #$6, D3
        BEQ     decodeAND
        BRA     decodeMULS  ; All 3 positions (8, 9, 10) were set

split111: 
        BTST    #$3, D3     ; Check 13th bit
        BEQ     ariShift    ; ASL_ASR Memory Shift follows 1110000x11+
   
        BTST    #$5, D3     
        BNE     logReg     
        BRA     decodeLSx_M
logReg: BTST    #12, D3         
        BEQ     decodeLSx_R
        BRA     outputData

ariShift:                   ; Special split specifically for Arithmetic Shift
        BTST    #$5, D3     
        BNE     ariReg
        BRA     decodeASx_M    
ariReg: BRA     decodeASx_R
            

; ========================================================================
; "decodeX" subroutines
; Gary
; 
; Set of subroutines which are invoked by identifyOpcode.
; A decodeX subroutine will read from A2 and use TRAP #15 to output
; the instruction.
;
; For example, the "decodeLEA" subroutine will read A2 (which contains the
; opcode) to record the parameters (such as destination register). If the
; opcode indicates that the next word represents a destination address, then
; decodeLEA will advance A2 to the next word and decode that.
; To finish, decodeLEA will output the decoded instruction with TRAP #15
; ========================================================================

; ------------------------------------------------------------
; 1. "decodeNOP" subroutine
; Gary
;
; Decodes NOP opcode by verifying then printing
; ------------------------------------------------------------
decodeNOP:
        verifyOpcode    pNOP, (A2)
        LEA     oNOP, A1     ; Loads byteVAR
        MOVE.B  #14,D0          
        TRAP    #15
        RTS                 ; Return from decodeNOP subroutine


; ------------------------------------------------------------
; 2. "decodeMOVE" subroutine
; Gary
;
; Decodes MOVE opcode by verifying, checking size and adressing mode
; then printing both.
; ------------------------------------------------------------
decodeMOVE:
        verifyOpcode    pMOVE, (A2)
        
        BTST    #$E, (A2)       ; Second verification step
        BNE     decodeMOVEM

        LEA     oMOVE, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        
        printSize       (A2)
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        printComma
        prepareAdrMode  #$0,  D3
        decodeAdrMode   D3, D1
        RTS                 ; Return from decodeMOVE subroutine


; ------------------------------------------------------------
; 3. "decodeMOVEM" subroutine
; Dylan
;
; Decode MOVEM by scanning register list masks. Currently not 
; properly formatted so instead it just prints memory at location.
; ------------------------------------------------------------
decodeMOVEM:
        verifyOpcode    pMOVEM, (A2)
        JSR     outputData
        RTS                 ; Return from decodeMOVEM subroutine


; ------------------------------------------------------------
; 4. "decodeADD" subroutine
; Gary
;
; Decodes add by verifying, printing, checking the opmode(and size),
; and decoding the adressing modes used.
; ------------------------------------------------------------
decodeADD:
        verifyOpcode    pADD, (A2)
        LEA     oADD, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        printOpMode     (A2)
        CMP.B   #$1, D6             ; If 1, <ea> into Dn otherwise Dn into <ea>
        BEQ     decodeAddDestOp
        printComma
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        BRA     decodeADDcomp
decodeAddDestOp:
        prepareAdrMode  #$1,(A2)
        decodeAdrMode   (A2), D1
        printComma
        printDnDest     D3
decodeADDcomp:
        RTS                ; Return from decodeADD subroutine


; ------------------------------------------------------------
; 5. "decodeSUB" subroutine
; Gary
;
; Decodes sub by verifying, printing, checking the opmode(and size),
; and decoding the adressing modes used.
; ------------------------------------------------------------
decodeSUB:
        verifyOpcode    pSUB, (A2)
        LEA     oSUB, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        printOpMode     (A2)
        CMP.B   #$1, D6             ; If 1, <ea> into Dn otherwise Dn into <ea>
        BEQ     decodeSubDestOp
        printComma
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        BRA     decodeSUBcomp
decodeSubDestOp:
        prepareAdrMode  #$1,(A2)
        decodeAdrMode   (A2), D1
        printComma
        printDnDest     D3
decodeSUBcomp:
        RTS                ; Return from decodeSUBcomp subroutine


; ------------------------------------------------------------
; 6. "decodeMULS" subroutine
; Gary
;
; Decodes muls by verifying, printing, then checking adressing
; modes and printing them in a formatted form.
; ------------------------------------------------------------
decodeMULS:
        verifyOpcode    pMULS, (A2)
        LEA     oMULS, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        CLR     D7
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        printComma
        printDnDest     D3
        RTS                 ; Return from decodeMULS subroutine
        
; ------------------------------------------------------------
; 7. "decodeDIVU" subroutine
; Gary
;
; Decodes divu by verifying, printing, then checking adressing
; modes and printing them in a formatted form.
; ------------------------------------------------------------
decodeDIVU:
        verifyOpcode    pDIVU, (A2)
        LEA     oDIVU, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        CLR     D7
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        printComma
        printDnDest     D3
        RTS                 ; Return from decodeDIVU subroutine


; ------------------------------------------------------------
; 8. "decodeLEA" subroutine
; Gary
;
; Decodes lea by verifying, printing in a formatted form,
; then decoding adressing modes and outputing them in formatted form.
; ------------------------------------------------------------
decodeLEA:
        verifyOpcode    pLEA, (A2)
        LEA     oLEA, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        LEA     oBlank, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        MOVE.W  (A2), D5
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        printComma
        printAnDest     D5
        RTS                 ; Return from decodeLEA subroutine


; ------------------------------------------------------------
; 9. "decodeAND" subroutine
; Gary
;
; Decodes and by verifying, printing in a formatted form,
; then decoding adressing modes and outputing them in formatted form.
; ------------------------------------------------------------
decodeAND:
        verifyOpcode    pAND, (A2)
        LEA     oAND, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        printOpMode     (A2)
        CMP.B   #$1, D6             ; If 1, <ea> into Dn otherwise Dn into <ea>
        BEQ     decodeAndDestOp
        printComma
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        BRA     decodeANDcomp
decodeAndDestOp:
        prepareAdrMode  #$1,(A2)
        decodeAdrMode   (A2), D1
        printComma
        printDnDest     (A2)
decodeANDcomp:
        RTS                ; Return from decodeANDcomp subroutine


; ------------------------------------------------------------
; 10. "decodeNOT" subroutine
; Gary
;
; Decodes not by verifying, printing in a formatted form,
; then decoding adressing modes and outputing them in formatted form.
; ------------------------------------------------------------
decodeNOT:
        verifyOpcode    pNOT, (A2)
        BTST    #$B, (A2)
        BNE     decodeMOVEM
        BTST    #$C, (A2)
        BNE     decodeMOVEM ;Second verification step
        
        LEA     oNOT, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        
        printSizeLow       (A2)
        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1
        RTS                 ; Return from decodeNOT subroutine

; ------------------------------------------------------------
; 11a. "decodeLSx_M" subroutine
; Gary
;
; Decodes Logical Shifts by checking if its memory or registers
; it receives then prints. 
; ------------------------------------------------------------
decodeLSx_M:
        verifyOpcode    pLSx_M, (A2)
        BTST    #$08, D3     ; Check the 8th bit
        BEQ     LSR_M
LSL_M:  LEA     oLSL, A1
        MOVE.B  #14,D0          
        TRAP    #15 
        BRA     reg_M        
  
LSR_M:  LEA     oLSR, A1
        MOVE.B  #14,D0          
        TRAP    #15      
reg_M:  printSizeLow       (A2) 
        printCount       (A2)
        printComma
        printDnSrc     (A2)        
        RTS                 ; Return from decodeLSx_M subroutine


; ------------------------------------------------------------
; 11b. "decodeLSx_R" subroutine
; Gary
;
; Decodes Logical Shifts by checking if its memory or registers
; it receives then prints. 
; ------------------------------------------------------------
decodeLSx_R:
        verifyOpcode    pLSx_R, (A2)
        BTST    #$08, D3     ; Check the 8th bit
        BEQ     LSR_R
LSL_R:  LEA     oLSL, A1
        MOVE.B  #14,D0          
        TRAP    #15 
        BRA     reg_R       
  
LSR_R:  LEA     oLSR, A1
        MOVE.B  #14,D0          
        TRAP    #15      
reg_R:  printSizeLow       (A2)
        printDnDest    (A2)
        printComma
        printDnSrc     (A2)
        RTS                 ; Return from ddecodeLSx_R subroutine
        
; ------------------------------------------------------------
; 12a. "decodeASx_M" subroutine
; Gary
;
; Decodes Arithmetical Shifts by checking if its memory or registers
; it receives then prints. 
; ------------------------------------------------------------
decodeASx_M:
        verifyOpcode    pASx_M, (A2)
        BTST    #$08, D3     ; Check the 8th bit
        BEQ     ASR_M
ASL_M:  LEA     oASL, A1
        MOVE.B  #14,D0          
        TRAP    #15 
        BRA     Areg_M        
  
ASR_M:  LEA     oASR, A1
        MOVE.B  #14,D0          
        TRAP    #15      
Areg_M: printSizeLow       (A2) 
        printCount       (A2)
        printComma
        printDnSrc     (A2)          
        RTS                 ; Return from decodeASx_M subroutine


; ------------------------------------------------------------
; 12b. "decodeASx_R" subroutine
; Gary
;
; Decodes Arithmetical Shifts by checking if its memory or registers
; it receives then prints. 
; ------------------------------------------------------------
decodeASx_R:
        verifyOpcode    pASx_R, (A2)
        BTST    #$08, D3     ; Check the 8th bit
        BEQ     ASR_R
ASL_R:  LEA     oASL, A1
        MOVE.B  #14,D0          
        TRAP    #15 
        BRA     Areg_R       
  
ASR_R:  LEA     oASR, A1
        MOVE.B  #14,D0          
        TRAP    #15      
Areg_R: printSizeLow       (A2)
        printDnDest    (A2)
        printComma
        printDnSrc     (A2)
        RTS                 ; Return from decodeASx_R subroutine
        
        ; ------------------------------------------------------------


; ------------------------------------------------------------
; 13a. "decodeBEQ" subroutine
; Gary
;
; Decodes Branching by verifying then decoding displacement.
; ------------------------------------------------------------
decodeBEQ:
        verifyOpcode    pBEQ, (A2)
        LEA     oBEQ, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        space
        printSign
        decodeDisplacement (A2)
        RTS                 ; Return from decodeBEQ subroutine


; ------------------------------------------------------------
; 13b. "decodeBGE" subroutine
; Gary
;
; Decodes Branching by verifying then decoding displacement.
; ------------------------------------------------------------
decodeBGE:
        verifyOpcode    pBGE, (A2)
        LEA     oBGE, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        space
        printSign
        decodeDisplacement (A2)

        RTS                 ; Return from decodeBGE subroutine


; ------------------------------------------------------------
; 13c. "decodeBLT" subroutine
; Gary
;
; Decodes Branching by verifying then decoding displacement.
; ------------------------------------------------------------
decodeBLT:
        verifyOpcode    pBLT, (A2)
        LEA     oBLT, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        space
        printSign
        decodeDisplacement (A2)

        RTS                 ; Return from decodeBLT subroutine


; ------------------------------------------------------------
; 14. "decodeJSR" subroutine
; Gary
;
; Decodes Branching by verifying then decoding displacement.
; ------------------------------------------------------------
decodeJSR:
        verifyOpcode    pJSR, (A2)
        LEA     oJSR, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        
        LEA     oBlank, A1     
        MOVE.B  #14,D0          
        TRAP    #15

        prepareAdrMode  #$1, (A2)
        decodeAdrMode   (A2), D1        
        RTS                 ; Return from decodeJSR subroutine


; ------------------------------------------------------------
; 15. "decodeRTS" subroutine
; Gary
;
; Decodes RTS by verifying then printing
; ------------------------------------------------------------
decodeRTS:
        verifyOpcode    pRTS, (A2)
        LEA     oRTS, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        RTS                 ; Return from decodeRTS subroutine


; ------------------------------------------------------------
; 16. "decodeBRA" subroutine
; Gary
;
; Decodes Branching by verifying then decoding displacement.
; ------------------------------------------------------------
decodeBRA:
        verifyOpcode    pBRA, (A2)
        LEA     oBRA, A1     
        MOVE.B  #14,D0          
        TRAP    #15
        space
        printSign
        decodeDisplacement (A2)
        RTS                 ; Return from decodeBRA subroutine
        
; ------------------------------------------------------------
; 17. "decodeImmediate" subroutine
; Gary
;
; Decodes cases where an immediate mode is encountered.
; Does so by calculating how many words it needs to scan before
; moving on. This is calculated through the adressing mode and the
; opcode size.
; ------------------------------------------------------------
decodeImmediate:
        JSR     outputData
        CLR     D1
        CLR     D6
        MOVEA   A2, A3
        MOVE.W  (A2)+, D4   ; Increment A2 (D4 isn't relevant)
        prepareAdrMode  #$1,(A3)  
        decodeSizeLow   (A3)
        MOVE.B  D1, D7
        CMP.B   #1, D6
        BEQ     decodeImmediateL
        space
        adrOut
        
        CMP.B   #$07, D7
        BEQ     decodeImmediateDest
        
        BRA     decodeImmediateComp
decodeImmediateL:
        space
        adrOut
        space
        MOVE.W  (A2)+, D4   ; Increment A2 (D4 isn't relevant)
        adrOut
        
        CMP.B   #$07, D7
        BEQ     decodeImmediateDest

        BRA     decodeImmediateComp
decodeImmediateDest:
        MOVE.W  (A3), D7
        MOVE.W  (A2)+, D4   ; Increment A2 (D4 isn't relevant)
        BTST    #0, D7
        BNE     decodeImmediateDestL
decodeImmediateDestW:        
        space
        adrOut 
        BRA     decodeImmediateComp
decodeImmediateDestL:
        space
        adrOut
        MOVE.W  (A2)+, D4   ; Increment A2 (D1 isn't relevant)
        adrOut
        
decodeImmediateComp:
        RTS                 ; Return from decodeDIVU subroutine

; ========================================================================
; Generic Helper Functions
; 
; Set of subroutines which do various tasks which are repeated frequently.
; Each helper function should be commented with required input and output.
; 
; If input is required, request through D0, D1, etc
; Return using D0
; ========================================================================

; ------------------------------------------------------------
; outputData
; Jonathan
;
; Converts the hex in A2 to ASCII and outputs it, then increments A2.
; ------------------------------------------------------------
outputData:
        MOVE.B  #6, D0      ; Prepare TRAP 15 for outputting a character in D1
        MOVE.W  #61, D1     ; An = sign
        TRAP    #15         ; Output = sign
        
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSL.W   #4, D1      ; Remove the first 4 bits (1 digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        
        MOVE.W  (A2), D1    ; Move A2 into D1
        LSL.W   #8, D1      ; Remove the first 8 bits (2 digits) of D1
        LSL.W   #4, D1      ; Remove the first 4 bits (1 more digit) of D1
        LSR.W   #8, D1      ; Get the first hex digit of D1
        LSR.W   #4, D1      
        ConvertHtoA D1      ; Convert D1 to a character
        TRAP    #15         ; Execute output
        RTS





; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            ; End of Code
        END    main         ; last line of source

















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
