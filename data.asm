.386
.387
.MODEL SMALL

 WAVE_FREQUENCY EQU 7000.0
 PI2            EQU 6.283185307179586476925286766559

_DATI SEGMENT PARA PUBLIC 'DATA' USE16

  WavePulsation 	dd 43982.0                                        ;WAVE_FREQUENCY * PI2
  WaveAmplitude         dd 10000.0 
  WavePeriod            dd 0.00014285714285714285714285714285714          ;1.0 / WAVE_FREQUENCY

 
  deltaT                dd 0.000022675736961451247165532879818594         ;How much time a sample is at 44100
  T                     dd 0.0

  
  strWaveFile           db "coin.wav", 0
  strFileNotFound       db "File not found!", 24h
  strFileError          db "Error while reading WAV file!", 24h

  fileHandle            dw 0

  sampleRate            dw 0

_DATI ENDS

_CODE SEGMENT PARA PUBLIC 'CODE' USE16
 ASSUME CS:_CODE, DS:_DATI, ES:_DATI

 ;This is called to update the block given

 TTT dd 3.0

 ;AX = Block number (Either 0 or 1)
 ;BX = Block mask (0 for block 0, 0ffffh for block 1)
 UpdateBuffer2:
  push es
  push di
  push bx

  ;Set ES:DI to point to start of the current block

  mov di, WORD PTR [bufferSegment]
  mov es, di
  mov di, BLOCK_SIZE
  and di, bx
  add di, WORD PTR [bufferOffset]

  xor bx, bx

  fld DWORD PTR ds:[T]              ;ST(0) = t
  

 _fb_fill:
  fld QWORD PTR [WavePulsation]     ;ST(0) = W          ST(1) = t
  fmul st(0), st(1)                 ;ST(0) = W*t        ST(1) = t

  fcos                              ;ST(0) = cos(W*t)   ST(1) = t
  fmul DWORD PTR [WaveAmplitude]    ;ST(0) = A*cos(Wt)  ST(1) = t
  
  fist WORD PTR es:[di]             
  fstp st(0)                        ;ST(0) = t 

  fadd DWORD PTR [deltaT]  	    ;ST(0) = t + dt

  add di, 02h
  add bx, 02h
  cmp bx, BLOCK_SIZE
 jb _fb_fill

  fstp DWORD PTR [T]                ;Save T

  ;Take the modulo

  fld DWORD PTR [WavePeriod]        ;ST(0) = T
  fld DWORD PTR [T]                 ;ST(0) = t      ST(1) = T
  fprem1                            ;ST(0) = t % T  ST(1) = T
  fstp DWORD PTR [T]                ;ST(0) = T
  fstp st(0)                        ;/

  pop bx
  pop di
  pop es
  ret


 ;AX = Block number (Either 0 or 1)
 ;BX = Block mask (0 for block 0, 0ffffh for block 1)
 UpdateBuffer:
  push es
  push di
  push bx
  push ax
  push si
  push cx
  push dx

  ;Set ES:DI to point to start of the current block

  mov di, WORD PTR [bufferSegment]
  mov es, di
  mov di, BLOCK_SIZE
  and di, bx
  add di, WORD PTR [bufferOffset]

  ;Read from file

  push ds
 
  mov ax, es
  mov ds, ax
  mov dx, di

  mov ah, 3fh
  mov bx, WORD PTR [fileHandle]
  mov cx, BLOCK_SIZE
  int 21h

  pop ds  

  ;Check if EOF

  cmp ax, BLOCK_SIZE
  je _ub_end

  mov ax, 4200h
  mov bx, WORD PTR [fileHandle]
  xor cx, cx
  mov dx, 44d
  int 21h

 _ub_end:
  pop dx
  pop cx
  pop si
  pop ax
  pop bx
  pop di
  pop es
  ret

 ;This is called to initialize both blocks
 ;Set CF on return (and set DX to the offset of a string) to show an error and exit
 InitBuffer:
  push ax
  push bx

  ;finit

  ;xor ax, ax
  ;mov bx, ax
  ;call UpdateBuffer

  ;inc al
  ;not bx
  ;call UpdateBuffer


  mov ax, 3d00h
  mov dx, OFFSET strWaveFile
  int 21h

  mov dx, OFFSET strFileNotFound
  mov WORD PTR [fileHandle], ax
 jc _ib_end

  ;Read sample rate

  mov bx, ax
  mov ax, 4200h
  xor cx, cx
  mov dx, 18h
  int 21h
 
  mov dx, OFFSET strFileError
 jc _ib_end

  mov ah, 3fh
  mov bx, WORD PTR [fileHandle]
  mov cx, 2
  mov dx, OFFSET sampleRate
  int 21h

  mov dx, WORD PTR [sampleRate]				;DEBUG

  mov dx, OFFSET strFileError
 jc _ib_end

  ;Set file pointer to start of data

  mov ax, 4200h
  mov bx, WORD PTR [fileHandle]
  xor cx, cx
  mov dx, 44d
  int 21h
 

 _ib_end:
  pop bx
  pop ax
  ret


 ;Closed to finalize the buffer before exits

 FinitBuffer:
  push ax
  push bx
  push dx

  mov bx, WORD PTR [fileHandle]
  test bx, bx
 jz _fib_end

  mov ah, 3eh
  int 21h

 _fib_end:
  pop dx
  pop bx
  pop ax
  ret

_CODE ENDS