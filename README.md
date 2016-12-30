# sb16-wav
Play a specific WAV file with SoundBlaster 16

Related to this SO answer: https://stackoverflow.com/questions/41359112/playing-wav-files-on-dosboxs-sound-blaster-device/41386810#41386810

>This present a demo program that plays a specific WAV file (to avoid introducing a RIFF parser to the already too-long-for-SO code.  
The program has been tested in DOSBox, but a lot of things can go wrong on different configurations.  

>Finally, I was forced to split the code into two answers.  
This is **part 1**.

Though the question may classify as off-topic<sup>1</sup> I believe it could be a precious resource to have on this site.  
So I'm attempting to respond it.  

A few notes on the environment: 
 
* I've used [TASM](https://stackoverflow.com/documentation/x86/2403/assemblers/7933/microsoft-assembler-masm#t=201612291526228279574) as the assembler, 
there is no particular reason behind this choice but childhood memories.   
The code should be compatible with [MASM](https://stackoverflow.com/documentation/x86/2403/assemblers/7933/microsoft-assembler-masm#t=201612291526228279574).

* I'm using [DOSBox](http://www.dosbox.com/download.php?main=1) to emulate a DOS environment.   
DOSBox ships with a preconfigured [SoundBlaster 16](https://en.wikipedia.org/wiki/Sound_Blaster_16) card.  
TASM can be run under DOSBox without any problem.  

A scanned version of the [TASM 5 manual](http://bitsavers.informatik.uni-stuttgart.de/pdf/borland/turbo_assembler/Turbo_Assembler_Version_5_Users_Guide.pdf)<sup>2</sup> is 
available online.  
Though no uncommon syntax has been used, being unfamiliar with the assembler directives makes any code harder to read and understand.    
[The TASM 5 pack is available](http://www.phatcode.net/downloads.php?id=280) online.  

Assembling, general source format and debugging
---

As a matter of convenience, the code developed for this answer can be found on [GitHub](https://github.com/margaretbloom/sb16-wav).  
The binary format is the [MZ executable](https://en.wikipedia.org/wiki/DOS_MZ_executable) with memory model *SMALL*, one data segment named `_DATI`<sup>3</sup> and one 
code segment named `_CODE`.  
Each segment is defined multiple times for convenience<sup>4</sup>, both segments are *PUBLIC* so all these different definitions are merged together by the linker, resulting
in just two segments<sup>5</sup>.  

The sources target the 8086 as per OP request.  

The sources use conditional macro and symbolic values<sup>6</sup> in order to be configurable, only three values need to be adjusted eventually.  
The default values match the default configuration of DOSBox.  
We will see the configuration soon.

Due to the not elementary nature of this task, **debugging is essential**.  
To facilitate it, TASM and TLINK can be instructed to generate, and include, *debugging symbols*.  
Coupled with the use of TD debugging is *greatly simplified*.  

Assemble the sources with

    tasm /zi sb16.asm
    tlink /v sb16.obj 

to	generates full debugging symbols.  
Use `td sb16` to debug the program.  
Some notes on debugging:

* Sometimes DOSBox crashes. 
* During debugging the DOS environment can be corrupted if the program acts incorrectly or is terminated earlier. Be ready to restart DOSBox often.
* Place an `int 03h` (opcode *CC*) instruction where you want TD to break. This is handy to debug the [ISR](http://wiki.osdev.org/Interrupt_Service_Routines).
	
Soundcard configuration 
---

The SoundBlaster 16 (SB16) had a simple [DSP](https://en.wikipedia.org/wiki/Digital_signal_processing) that when filled with [
digital samples](https://en.wikipedia.org/wiki/Pulse-code_modulation) converted them into an analogue output.   
To read the samples the card took advantage of a special transfer mode called Direct Memory Access (DMA), the chip that handled
such transfers was capable of handling 4x2 in flight data movements.   
The SB16 had a jumper, or a switch, to configure the channel to use to read the samplings.  

When a block of sampling was over the card requested the attention of the CPU through an [interrupt](http://wiki.osdev.org/Interrupts),
the chip handling the interrupts had 8x2 request lines.  
The SB16 had another jumper to select the Interrupt ReQuest line (IRQ) to use.

Finally, as every legacy device, the SB16 was mapped in the [IO address space](http://wiki.osdev.org/I/O_Ports) where it occupied sixteen
continuous bytes.  
The starting address, a.k.a. base address, of this block was configurable too.  A part was fixed and a part was variable, the base address 
had a form of 2x0h where *x* was configurable.

All these options are reflected in the [DOSBox configuration file](http://www.dosbox.com/wiki/dosbox.conf).  
The program given has been tested with these options<sup>7</sup>:

    [sblaster]
    sbtype=sb16
    sbbase=220
    irq=7
    dma=1
    hdma=5
    sbmixer=true
    oplmode=auto
    oplemu=default
    oplrate=44100

Sources configuration 
---
	
Though this is a premature introduction to the sources, it is handy to present the configuration constants now that we have just seen the DOSBox configurations.  

In the file `cfg.asm` there are these constants

    ;IO Base
    SB16_BASE   EQU 220h
     
    ;16-bit DMA channel (must be between 5-7)
    SB16_HDMA   EQU 5
    
    ;IRQ Number
    SB16_IRQ    EQU 7	
	

The values here **must** reflect the ones present in the DOSBox config file.   
Every other constant defined in the file is for the use of the program and not intended to be modified unless you know what you are doing<sup>8</sup>.	  

The `cfg.asm` has nothing else of interest and won't be discussed again.

How to play samples
---

After a long introduction, we are now ready to see how to play a buffer of samples.  
A **very good** and synthetic reference is [available here][tutorial/documentation on the SB16 here](http://homepages.cae.wisc.edu/~brodskye/sb16doc/sb16doc.html).  
This answer is basically an implementation of what is written there, with some verbose explanation.  

These are the step we will follow:

To playback a buffer of samples the step requested are:

>* Allocate a buffer that does not cross a 64k physical page boundary
* Install an interrupt service routine
* Program the DMA controller for background transfer
* Set the sampling rate
* Write the I/O command to the DSP
* Write the I/O transfer mode to the DSP
* Write the block size to the DSP (Low byte/high byte)

The goal is to play [this WAV file of a Super Mario Bros coin](http://themushroomkingdom.net/sounds/wav/smb/smb_coin.wav).

Sources organization 
---

There are seven files:

* `sb16.asm` is the main file that includes the others.  
It performs the steps above.
* `cfg.asm` contains the configuration constants.  
* `buffer.asm` contains the routines for allocating the samples buffer.  
* `data.asm` contains the routines that fill the buffer.    
This is the file to edit to adapt the source to other goals.    
* `isr.asm` contains the routines that set the ISR and the ISR itself.  
* `dma.asm` contains the routines that program the DMA.  
* `dsp.asm` contains the routines that program the DSP.

In general, the files are short.

The sample buffer
---

The high-level process is as follow: the card is given a buffer to read, when done it triggers an interrupt and stops; the software then update the buffer and restart the playback.  
The drawback with this method is that it introduces pauses in the playback that present themselves as audible "clicks".  
The DMA and the DSP support a mode called *auto-initialize* where, when the end of the buffer is reached, the transfer and the playback start over from
the start.   
This is good for a cyclic static buffer but won't help for an ever-updating buffer. 

The trick is to program the DMA to transfer a block *twice* as large as the block the DSP is programmed to read. This will make the card generate an interrupt at the middle of the buffer.  
The software will then resume the playback immediately and then update the half just read. This is explained in the diagram below.

[![Auto-initialization for continuous playback][1]][1]

**How big should the buffer be?**  

I have chose a size of 1/100 sec at 44100 samples per second, mono, 16-bit per sample. This is 441 samples times 1 audio channel times 2 bytes per sample.  
This is the *block size*.  Since we have two blocks, the buffer size *should be* twice as much.  
In practice, it is four times as much (in the end, it is about 3.5 KiB).  

The big problem with the buffer is that *it must not cross a physical 64KiB boundary*<sup>9</sup>.   
Note that this is not the same as not crossing a 64KiB logical boundary (which is impossible without changing segment).  

I couldn't find a suitable allocation routine in the [Ralf Brown Interrupt List](http://www.ctyme.com/intr/int.htm), so I proceeded by abstracting the behaviour in 
two routines.

* `AllocateBuffer` that must set the variables `bufferOffset` and `bufferSegment` with the far pointer to the allocated buffer of size *at least* `BLOCK_SIZE * 2`.   
Upon return, if `CF` it means the procedure failed.
* `FreeBufferIfAllocated` that is called to free the buffer. It is up to this procedure to check if a buffer was effectively allocated or not.  

The default implementation statically allocates in the data segment a buffer that is twice as needed, as said.  
My reasoning was that if this unmoveable buffer crosses a 64KiB boundary than it is split into two halves, *L* and *H*, and it is true that *L* + *H* = *BLOCK_SIZE* * 2 * 2.  
Since the worst case scenario is when *L* = *H*, i.e. the buffer is split in the middle, the double size gives a size of *BLOCK_SIZE* * 2 * 2 / 2 = *BLOCK_SIZE* * 2 in the worst case scenario for both *L* and *H*.  
This guarantees us that we can always find a half as large as *BLOCK_SIZE* * 2, which is what we needed.  

The `AllocateBuffer` just find an appropriate half and set the value of the far pointer mentioned above.  `FreeBufferIfAllocated` does nothing.  

Note that by "buffer" I mean two "blocks" and a "block" is the unit of playback.

**What format should the buffer use?**

To keep the things simple, the DSP is programmed to playback 16-bit mono samplings.  
However, the procedures that fill the blocks have been abstracted into `data.asm`.  

* `UpdateBuffer` is called by the ISR to update a block.   
  The parameters are
  
  >AX = Block number (Either 0 or 1)
  >BX = Block mask (0 for block 0, 0ffffh for block 1)
  
  They are used to compute the offset into the buffer with this code
   
        ;Set ES:DI to point to start of the current block
        
        mov di, WORD PTR [bufferSegment]
        mov es, di
        mov di, BLOCK_SIZE
        and di, bx
        add di, WORD PTR [bufferOffset]
		
  The rest of the procedure read a block of samples from the WAV file.  
  If the file has ended, the file pointer is reset back to the beginning to implement a cycling playback.  
  
  **BEWARE** You are called in an ISR context, while the ACK and the EOI have already been issued, you **must not** clobber any register.  
  Failing to respect this rule will result in difficult to understand bugs and possibly freezes. 
  
 * `InitBuffer` is called one at the beginning to initialize the buffer if needed.  
 The current implementation opens the file *coin.wav*<sup>10</sup>, read the sample rate and set the file pointer to the data section.  
 This procedure uses the *CF* to signal an error. If the *CF* is set, an error has been encountered and *DX* holds a pointer to a *$* terminated string that will be printed.  
 
 * `FinitBuffer` used at the end to free the buffer resources.  
 The buffer memory itself is freed as said above.  
 This is called even if `InitBuffer` fails.  
 
We will talk about the WAV reading below.  

Installing the ISR
---

I assume you are familiar with the [IVT](http://wiki.osdev.org/Interrupt_Vector_Table).  
I suggest reading about the twos [8259A PIC](http://www.alldatasheet.com/datasheet-pdf/pdf/66107/INTEL/8259A.html) used to [routes IRQs](http://wiki.osdev.org/8259_PIC).

In shorts:

* There are 15 IRQ lines, from 0 to 15, 2 excluded.  
* An IRQ line must be enabled (unmasked) before the use.
* After an IRQ has been served, an End of Interrupt (EOI) must be sent to the PIC that served it.  IRQs above 7 are served by both PICs.  
* IRQ 0-7 are mapped to interrupt numbers 08h-0fh, IRQ 8-15 to 70h-78h

The file `isr.asm` is very short.  
The routine `SwapISRs` swap the current ISR pointer for the IRQ of the SB16 with a local pointer.  
Initially, this pointer points to the ISR `Sb16Isr`, so that the first call to `SwapISRs` will install our ISR.  
The second call will restore the original one.  

`Sb16Isr` does a few things:

* It acknowledges the IRQ to the SB16 (more on this later).  
* It files the EOI to the PIC(s).  
* It calls `UpdateBuffer`.
* It updates the block number and block mask passed to the routine above.  

**NOTE** `SwapISRs` also toggles the bit for the IRQ mask. It assumes that the IRQ is masked at the beginning of the program. You may want to change this to a more 
robust setting (or restart DOSBox if you abruptly interrupt the program).

Programming the DMA controller
---

The SB16 was an [ISA](https://en.wikipedia.org/wiki/Industry_Standard_Architecture) card, it couldn't read the memory directly.  
To solve this problem the DMA chip, [8357](http://pdf.datasheetcatalog.com/datasheets/2300/251823_DS.pdf) was invented.  
It had four channels, independently configurable, that when triggered performed a read from the memory to the ISA bus or vice-versa.  
There were two DMA controllers, the first one handled only 8-bit data transfers and channels 0-3.  
The second one used 16-bit data transfers and handled the channels 4-7.  

We are going to use the 16-bit transfers so, the DMA channel must be one of 5-7 (channel four is a bit special).  
The SB16 can also use 8-bit transfers, so it has two configurations for the DMA channel: one for the 8-bit moves and one for the 16-bit moves.   

Each channel, but channel four, has three parts:

* A 16-bit start address.
* A 16-bit counter for the size.
* An 8-bit page number. 

The address is a physical address (linear)! So in theory only the first 64KiB were accessible.  
The page number was used as the upper part of the address.    
However, the counter logic is still 16-bit, so the pointer to the data to read/write still wrap around at 64 KiB boundaries (should be 128 KiB for 16-bit).

The `dma.asm` files contain a single routine `SetDMA` that given the logical start address and the size, program the DMA.  
There isn't anything esoteric here besides a few arithmetic to compute the value to use.  

The mode is *Single mode* and *auto-initialization* is on.  
The document about the SB16 programming liked at the beginning has a very clear step-by-step procedure on this.   

Programming the DSP
---

The SB16 IO layout was as follow:


	ADDR    READ                        WRITE   
		
	2x6h    DSP Reset*                  DSP reset**

	2xAh    DSP Read***  

	2xCh    DSP Write                   DSP write (command and data)
			(bit7 set if ok to write)
			
	2xEh    DSP Read Status****
			(bit7 set if ok to read)
			
	2xFh    DSP 16-bit interrupt acknowledge 

	* bit 7 set after the reset completes
	** toggle bit 7, with a 3us interval between setting and clearing, to start a reset
	*** Wait for reading a 0AAh after a reset
	**** Also used to ACK 8-bit IRQs


The file `dsp.asm`  contains the basic routines `ResetDSP`, `WriteDSP` and `ReadDSP` that performs a reset, write a byte to the DSP after 
waiting for right conditions, read a byte from the DSP.

The DSP is used through commands.  

* To set the sampling of the playback use the command `41h`, followed by the low byte of the sampling frequency and then by the high byte.  
The routine `SetSampling` takes the sampling frequency in *AX* and set it.  

* To playback use the command `b6h`, followed by a *mode* byte and then by the block length (two bytes, low byte first).  
The routine `StartPlayback` takes the sampling frequency in *AX*, the mode byte in *BL* and the size in *CX* and start a playback (after setting the sample rate).  
**Note** that the DSP doesn't need to know the address of the buffer, it just triggers the channel request pin of the DMA and it will have the data on the bus.  
It is the DMA that have to know where the buffer is.  

* To stop a playback use the command `d5h`.  
`StopPlayback` does this.


Playing the WAV file
---

What the demo program do is playing the *coin.wav* file.  
This is file is *specific* it is a 16-bit mono file.  

The demo program doesn't parse the full RIFF format (you can [see this nice page](http://soundfile.sapp.org/doc/WaveFormat/), it is hardwired to work with that 
specific file.  
Though any file with identical format, yet different data, should do.

After the steps introduce at the beginning, the program simply wait for a keystroke.  
After that it performs all the de-initializations (including stopping the playback) and exit.

To continue from here, you have "only" to properly implement the routine in `data.asm`.  
It should be straightforward to make each key plays a different file.  

If the number of file is small I would open all the files in `InitBuffer`, then in `sb16.asm` implement a loop liked

	xor ah, ah
	int 16h

	cmp al, ...
	je ...

	cmp al, ...
	je ...

where each jump gets the file handle to play. (a lookup table would be better).  
Then:

1. Reset the file pointer of the file to play to the start of the samples.  
2. `xchg` the new file pointer with `fileHandle` (used by `UpdateBuffer`).

I leave to you how to make the playback stop when the key is released and resume when it is pressed. 

---
<sup>1</sup> For example because it asks for a non-trivial amount of code or for a resource.

<sup>2</sup> Beware that the Table Of Content has some pages switched.  

<sup>3</sup> `_DATA` is already defined.  

<sup>4</sup> Each source file redefine those segments if used.  

<sup>5</sup> The symbols `_DATI` and `_CODE` can be used to denote the segment part of the starting address of the final segments.   

<sup>6</sup> I don't remember the exact technical name for the `EQU` values.  

<sup>7</sup> These values are DOSBox defaults but be sure to check the config file anyway.  

<sup>8</sup> Specially because TASM lacks supports for a lot of conditional and a bit of bit-arithmetic is needed to set some value.  

<sup>9</sup> This should be 128KiB for 16-bit DMA, which we are using, but I don't remember exactly and didn't want to experiment.  

<sup>10</sup> Beware of DOS limitations on file names.


  [1]: https://i.stack.imgur.com/rnrLz.png
