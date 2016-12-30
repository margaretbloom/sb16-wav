.8086
.MODEL SMALL

_DATI SEGMENT PARA PUBLIC 'DATA' USE16

 ;This is a pointer to the ISR we will install 

 nextISR         dw OFFSET Sb16Isr
                 dw _CODE

 ;This is the internal status managed by the ISR

 blockNumber     dw 0
 blockMask       dw 0

_DATI ENDS

_CODE SEGMENT PARA PUBLIC 'CODE' USE16
 ASSUME CS:_CODE, DS:_DATI, ES:_DATI

 ;Swaps two far pointers

 ;DS:SI = ptr to ptr1
 ;ES:DI = ptr to ptr2
 SwapFarPointers:
  push bx

  mov bx, WORD PTR [si]
  xchg WORD PTR es:[di], bx
  mov WORD PTR [si], bx

  mov bx, WORD PTR [si+02h]
  xchg WORD PTR es:[di+02h], bx
  mov WORD PTR [si+02h], bx

  pop bx
  ret  

 ;Swaps the ISR vector of the IRQ of the card with a saved value

 SwapISRs:
  push es
  push si
  push di
  push dx
  push ax

  cli

  mov si, OFFSET nextISR
  xor di, di
  mov es, di
  mov di, ISR_VECTOR
  call SwapFarPointers

  sti

  ;Toggle PIC mask bit
  mov dx, PIC_DATA
  in al, dx
  xor al, PIC_MASK
  out dx, al

  pop ax
  pop dx
  pop di
  pop si
  pop es
  ret  

 
 ;This is the ISR

 Sb16Isr:
  push ax
  push dx
  push ds
  push es

  ;Ack IRQ to SB16

  mov dx, REG_DSP_ACK_16
  in al, dx

  ;EOI to PICs

  mov al, 20h
  out 20h, al

IF SB16_IRQ SHR 3 
  out 0a0h, al
ENDIF

  mov ax, _DATA
  mov ds, ax

  mov ax, WORD PTR [BlockNumber]
  mov bx, WORD PTR [BlockMask]  
  call UpdateBuffer

  not bx
  inc ax
  and al, 01h

  mov WORD PTR [BlockNumber], ax
  mov WORD PTR [BlockMask], bx

  pop es
  pop ds
  pop dx
  pop ax
  iret


_CODE ENDS
