.8086
.MODEL SMALL


 ;Block size is 1/100 of a second at 44100 samplings per seconds
 
 BLOCK_SIZE      EQU 44100 / 100 * 2

 ;Buffer size allocated, it is twice the BLOCK_SIZE because there are two blocks.
 ;Size is doubled again so that we are sure to find an area that doesn't cross a
 ;64KiB boundary
 ;Total buffer size is about 3.5 KiB

 BUFFER_SIZE     EQU  BLOCK_SIZE * 2 * 2

_DATI SEGMENT PARA PUBLIC 'DATA' USE16

 ;This is the buffer

 buffer            db BUFFER_SIZE DUP(0)


 bufferOffset      dw OFFSET buffer
 bufferSegment     dw _DATI

_DATI ENDS


_CODE SEGMENT PARA PUBLIC 'CODE' USE16
 ASSUME CS:_CODE, DS:_DATI


 ;Allocate a buffer of size BLOCK_SIZE * 2 that doesn't cross
 ;a physical 64KiB
 ;This is achieved by allocating TWICE as much space and than
 ;Aligning the segment on 64KiB if necessary
 
 
 AllocateBuffer:
  push bx
  push cx
  push ax
  push dx

  ;Compute linear address of the buffer
  
  mov bx, _DATI
  shr bx, 0ch
  mov cx, _DATI
  shl cx, 4
  add cx, OFFSET buffer
  adc bx, 0                                 ;BX:CX = Linear address
    
 

  ;Does it starts at 64KiB?

  test cx, cx
 jz _ab_End                                ;Yes, we are fine

  mov dx, cx
  mov ax, bx

  ;Find next start of 64KiB

  xor dx, dx
  inc ax

  push ax
  push dx

  ;Check if next boundary is after our buffer

  sub dx, cx
  sub ax, bx

  cmp dx, BUFFER_SIZE / 2

  pop dx
  pop ax

 jae _ab_end



  mov bx, dx
  and bx, 0fh
  mov WORD PTR [bufferOffset], bx
    
  mov bx, ax
  shl bx, 0ch
  shr dx, 04h
  or bx, dx
  mov WORD PTR [bufferSegment], bx

 _ab_end:
  clc

  pop dx
  pop ax
  pop cx
  pop bx

  ret


 ;Free the buffer

 FreeBufferIfAllocated:

  ;Nothing to do

  ret




_CODE ENDS