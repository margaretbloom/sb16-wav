.386
.387
.MODEL SMALL

.STACK


INCLUDE cfg.asm
INCLUDE buffer.asm


_DATI SEGMENT PARA PUBLIC 'DATA' USE16

 ;This is the segment to the buffer for the sampling

 samplingBuffer   dw 0 

 ;Strings

 strErrorBuffer   db "Cannot allocate or find a buffer for the samplings :(", 24h

 strPressAnyKey   db "Press any key to exit", 13, 10, 24h
 strBye           db "Sound should stop now", 13, 10, 24h

_DATI ENDS

INCLUDE data.asm
INCLUDE isr.asm
INCLUDE dsp.asm
INCLUDE dma.asm

_CODE SEGMENT PARA PUBLIC 'CODE' USE16
 ASSUME CS:_CODE, DS:_DATI, ES:_DATI

__START__:
 
 ;Basic initialization

 mov ax, _DATI
 mov ds, ax
 


 ;S E T   T H E   N E W   I S R
 
 call SwapISRs



 ;A L L O C A T E   T H E   B U F F E R

 call AllocateBuffer
 mov dx, OFFSET strErrorBuffer
jc _error



 ;I N I T   T H E   B U F F E R

 call InitBuffer
jc _finit_buffer


 ;S E T U P   D M A
 
 mov si, WORD PTR [bufferSegment]
 mov es, si
 mov si, WORD PTR [bufferOffset]
 mov di, BLOCK_SIZE * 2
 call SetDMA



 ;S T A R T   P L A Y B A C K

 call ResetDSP

 mov ax, WORD PTR [sampleRate]            ;Sampling
 mov bx, FORMAT_MONO OR FORMAT_SIGNED     ;Format
 mov cx, BLOCK_SIZE                       ;Size
 call StartPlayback



 ;W A I T

 mov ah, 09h
 mov dx, OFFSET strPressAnyKey
 int 21h

 xor ah, ah
 int 16h



 ;S T O P
 
 call StopPlayback

 mov dx, OFFSET strBye

_finit_buffer:

 ;F R E E   B L O C K   R E S O U R C E S
 call FinitBuffer


 ;E R R O R   H A N D L I N G

 ;When called DX points to a string

_error:
 ;R E S T O R E   T H E   O L D   I S R s
 
 call SwapISRs



 call FreeBufferIfAllocated
 
 mov ah, 09h
 int 21h

 ;E N D

_end:
 mov ax, 4c00h
 int 21h

_CODE ENDS

END __START__