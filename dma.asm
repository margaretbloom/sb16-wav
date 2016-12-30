.8086
.MODEL SMALL


_CODE SEGMENT PARA PUBLIC 'CODE' USE16
 ASSUME CS:_CODE


 ;ES = buffer segment
 ;SI = buffer offset
 ;DI = count
 SetDMA:
  push dx
  push ax
  push cx
  push bx
  push si

  ;Disable SB16 DMA channel

  mov dx, REG_DMA_MASK
  mov al, 4 + SB16_HDMA MOD 4
  out dx, al

  ;Clear counter FF

  mov dx, REG_DMA_CLEAR_FF
  out dx, al

  ;Set transfert mode
  
  mov dx, REG_DMA_MODE
  mov al, 58h + SB16_HDMA MOD 4
  out dx, al


  ;Set address (in WORDs)

  ;SSSS SSSS SSSS SSSS 0000
  ;0SSS SSSS SSSS SSSS S000

  mov bx, es
  shr bx, 0dh        ;BL = addr[20:16]  
  mov cx, es
  shl cx, 3          ;CX = addr[15:0]
  shr si, 1
  add cx, si
  adc bx, 0             
  
  mov dx, REG_DMA_ADDRESS
  mov al, cl
  out dx, al
  mov al, ch
  out dx, al

  mov dx, REG_DMA_PAGE
  mov al, bl
  out dx, al

  ;Set count

  mov ax, di
  shr ax, 1

  mov dx, REG_DMA_COUNT
  out dx, al
  mov al, ah
  out dx, al

  ;Enable DMA channel

  mov dx, REG_DMA_MASK
  mov al, SB16_HDMA MOD 4
  out dx, al

  pop si
  pop bx
  pop cx
  pop ax
  pop dx

  ret

_CODE ENDS