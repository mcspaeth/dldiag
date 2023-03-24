	#define	aydatar	$c000
	#define	ctls	$c008
	#define	svc	$c010
	#define	ldr	$c020
	#define	aydataw $e000
	#define	miscw	$e008
	#define	ayaddr	$e010
	#define	ldw	$e020
	#define	led2	$e030
	#define	led1	$e038
	
	.org	$0000
	di			; Disable interrupts
	im	1		; Interrupt mode 1
	ld	sp,$a7ff	; Set stack pointer

	;; Clear all RAM
	xor	a
	ld	bc,$07ff
	ld	hl,$a000
	ld	de,$a001
	ld	(hl),a
	ldir

	;; Clear display
	ld	b,$10
	ld	hl,led2
cledl:	
	ld	(hl),$0a	; Dash
	inc	hl
	djnz	cledl

	ld	a,$0e		; DSWA
	ld	(ayaddr),a
	ld	a,(aydatar)	; Get test #
	;; 	and	$1f		; At most 32 tests
 	and	$0f		; At most 16 tests
	ld	c,a
	and	$07
	ld	($e037),a	; Lo octal of test #
	ld	a,c
	rrca
	rrca
	rrca
	ld	($e036),a	; Hi octal of test #
	jp 	$100		; Continue ahead -- out of space here

	
	;; Interrupt vector
	.org	$0038
	di
	push	af
	ld	a,$01
	ld	($a000),a	; Set interrupted flag
	ld	a,($a001)	; Decrement counter if non-zero
	and	a
	jr	z,irqnodec
	dec	a
	ld	($a001),a
irqnodec:
	pop	af
	ei
	reti

	;; NMI vector
	;; Should never happen!
	.org 	$0066
fail:	
	ld	bc,$0008
	ld	hl,help
	ld	de,led1
	ldir
nmil:	
	jr	nmil

help:
	.db	$0a,$0c,$0b,$0d,$0e,$0a,$0f,$0f



	.org	$0080
tests:
	.dw	ramtest		; 00
	.dw	ledcnt		; 01
	.dw	ledscr		; 02
	.dw	ledtest		; 03
	.dw	u20cnt		; 04
	.dw	u20dip		; 05
	.dw	u8cnt		; 06
	.dw	u8dip		; 07
	.dw	dips		; 08
	.dw	ins		; 09
	.dw	ledcnt		; 0a
	.dw	ledcnt		; 0b
	.dw	ledcnt		; 0c
	.dw	ledcnt		; 0d
	.dw	alladdr		; 0e
	.dw	ayout		; 0f


	.org	$0100

	;; Special case RAM test -- no IRQs!
	xor	a
	or	c
	jp	z,ramtest
	
	;; Show IRQs are working
	ei	
	ld	b,$08
irql
	ld	a,$01
	call	irqwait
	ld	a,b
	dec	a
	or	$38		; LED1
	ld 	l,a
	ld	h,$e0
	ld	(hl),$0f
	djnz	irql
	
	;; Delay to show test #
	ld	a,$08
	call	irqwait

	;; Run test
	ld 	a,c		; Get test #
	add	a,a
	ld 	hl,tests	; Index into table
	add	a,l
	ld	l,a		
	ld	e,(hl)		; Get address
	inc	hl
	ld	d,(hl)
	ex	de,hl
	jp	(hl)		; Run test


	
	;;  TESTS

	;; 2k RAM test
ramtest:	
	ld	de,$a000	; Start address
	ld	c,$10		; 20 loops
rtloop
	ld	h,d		; Store address
	ld	l,e

	;; Write crap
	ld	b,$08		; 8 pages
	ld	a,c
rtwl:
	add	a,$2f
	ld	(hl),a
	inc	l
	jr	nz,rtwl
	inc	a
	inc	h
	djnz	rtwl

	ld	h,d		; Get address
	ld	l,e

	;; Check crap
	ld	b,$08		; 8 pages
	ld	a,c
rtcl:	
	add	a,$2f
	cp	(hl)
	jp	nz,fail
	inc	l
	jr	nz,rtcl
	inc	a
	inc	h
	djnz	rtcl

	dec	c
	jr	nz,rtloop

	;; Passed
	jp 	pass


	
	;; Count up on LEDs
ledcnt:
	ld	c,$00
ledcl1:
	ld	de,led2
	ld	b,$10
ledcl2:	
	ex	de,hl
	ld	(hl),c
	ex	de,hl
	
	ld	a,$02		; Set counter
	call	irqwait
	
	inc	e
	djnz	ledcl2
	inc	c
	jr	ledcl1

	
	
	;; Scroll numbers through LEDs
ledscr:	
	ld	c,$00
ledsl1:
	ld	de,led2
	ld	b,$10
ledsl2:
	ld	a,c
	ld	(de),a
	
	ld	a,$02	; Set counter
	call	irqwait
	
	inc	c
	inc	e
	djnz	ledsl2
	inc	c
	jr	ledsl1


	
	;; Write LED digits from DIPs
ledtest:
	ld	de,led2

	ld	a,$02		; Set counter
	call	irqwait

	;; Check DIP A
	ld	a,$0e
	ld	(ayaddr),a
	ld	a,(aydatar)
	and	$80
	jr	nz,ledtest	; Dip A7 off

	;; Read DIP B
	ld	a,$0f
	ld	(ayaddr),a
	ld	a,(aydatar)	; Dip B
	ld	b,a
	and	$0f		; Mask low 4 bits for addr
	or	$30
	ld	e,a		; Set address

	ld	a,b		; High 4 bits = data
	rrca
	rrca
	rrca
	rrca
	ld	(de),a		; Write LED
	jr	ledtest

	

	;; U20 Count
	;; Writes to U21, Reads back from U20
u20cnt:	
	call 	drawio
	xor	a
	ld	($a002),a	; Error flags
	ld	c,a		; Data to write
	ld	a,$10
	ld	(miscw),a	; Set WRLDDATA low
	
u20cl:
	ld	a,c
	ld	(ldw),a		; Write data to u21
	ld	hl,$e03d	; P1 ones
	call	doct		; Draw output value

	ld	a,$04		; Counter
	call	irqwait

	ld	a,(ldr)
	ld	e,a
	ld	hl,$e035	; P2 ones
	call 	doct

	ld	a,e
	xor	c
	ld	hl,$a002
	or	(hl)
	ld	(hl),a
	dec	l
	
	ld	a,$04		; Counter
	call	irqwait

	inc	c
	ld	a,c
	and	a
	jr	nz,u20cl	; Loop if c != 0

	inc	l
	ld	a,(hl)
	and	a
	jp 	z,pass		; No flags set

	ld	hl,$e035	; P2 score
	call	doct
	jp	fail


	;; Check U20 with data from DIPs
u20dip:	
	call 	drawio
	ld	a,$10
	ld	(miscw),a	; Set WRLDDATA low

u20dl:	
	ld	a,$04		; Counter
	call	irqwait

	ld	a,$0f
	ld	(ayaddr),a
	ld	a,(aydatar)	; Dip B
	ld	(ldw),a		; Write data to u21
	ld	c,a

	ld	hl,$e03d	; P1 ones
	call	doct		; Draw output value

	ld	a,$04		; Counter
	call	irqwait

	ld	a,(ldr)
	ld	hl,$e035	; P2 ones
	call 	doct

	jr	u20dl		; Loop

	

	;; U8 Count
	;; Writes to U21, Reads back from U8  (with ext cabling)
u8cnt:	
	call 	drawio
	xor	a
	ld	($a002),a	; Error flags
	ld	c,a		; Data to write
	ld	a,$10
	ld	(miscw),a	; Set WRLDDATA low
	
u8cl:
	ld	a,c
	ld	(ldw),a		; Write data to u21
	ld	hl,$e03d	; P1 ones
	call	doct		; Draw output value

	ld	a,$04		; Counter
	call	irqwait

	ld	a,(ctls)
	ld	e,a
	ld	hl,$e035	; P2 ones
	call 	doct

	ld	a,e
	xor	c
	ld	hl,$a002
	or	(hl)
	ld	(hl),a
	dec	l

	ld	a,$04		; Counter
	call	irqwait
	
	inc	c
	ld	a,c
	and	a
	jr	nz,u8cl	; Loop if c != 0

	inc	l
	ld	a,(hl)
	and	a
	jp 	z,pass		; No flags set

	ld	hl,$e035	; P2 score
	call	doct
	jp	fail


	;; Check U20 with data from DIPs
u8dip:	
	call 	drawio
	ld	a,$10
	ld	(miscw),a	; Set WRLDDATA low

u8dl:	
	ld	a,$04		; Counter
	call	irqwait

	ld	a,$0f
	ld	(ayaddr),a
	ld	a,(aydatar)	; Dip B
	ld	(ldw),a		; Write data to u21
	ld	c,a

	ld	hl,$e03d	; P1 ones
	call	doct		; Draw output value

	ld	a,$04		; Counter
	call	irqwait

	ld	a,(ctls)
	ld	hl,$e035	; P2 ones
	call 	doct

	jr	u8dl		; Loop


	
dips:
	ld	a,$04
	call	irqwait

	ld	hl,$e03d
	ld	a,$0f
	ld	(ayaddr),a
	ld	a,(aydatar)	; Dip B
	call	doct
	ld	a,$0e
	ld	(ayaddr),a
	ld	a,(aydatar)	; Dip A
	call	doct
	jr	dips


	
ins:
	ld	c,$30		; Don't write LD data

insl:
	ld	a,$DF		; Toggle everything but WrLD
	xor	c
	ld	c,a
	ld	(miscw),a
	ld	a,$04
	call	irqwait

	ld	hl,$e03d
	ld	a,(ctls)
	call	doct
	ld	a,(svc)
	call	doct

	ld	hl,$e035
	ld	a,(ldr)
	call	doct
	jr	insl



	;; Cycle through accessing everything
alladdr:
	ld	a,($a000)	; RAM
	ld	a,(aydatar)	; AY read
	ld	a,(ctls)	; ~SELCPA
	ld	a,(svc)		; ~SELCPB
	ld	a,(ldr)		; ~rddiscdat
	ld	a,$0a
	ld	(led1),a	; ~den2
	ld	(led2),a	; ~den1
	ld	a,$10
	ld	(miscw),a	; ~ldmisc
	xor	a
	ld	(ayaddr),a	; BC1/0
	ld	(aydataw),a	; BC1/0
	jr	alladdr


	
	;; Test AY-3-8910 sounds
ayout:
	ld	de,aytbl
	ld	b,$00

	;; Initialize AY tones, volumes, etc.
ayl1:
	ld	a,(de)
	ld	c,a
	cp	$ff
	jr	z,ayl1e
	ld	a,b
	ld	(ayaddr),a	; Set register
	inc	b
	ld	a,c
	ld	(aydataw),a	; Write register
	inc	de
	jr	ayl1

ayl1e:	
	ld	de,aytble

ayl2:
	ld	a,$07		; AY Enable register
	ld	(ayaddr),a
	ld	a,(de)
	inc	e
	cp	$ff
	jr	z,ayl1e
	ld	(aydataw),a	; Write register
	xor	$3f
	ld	($e03e),a	; Write channel to LED
	ld	($e03f),a	; Write channel to LED

	ld	a,$20		; Counter
	call	irqwait
	jr	ayl2


	;; AY-3-8910 initial config
aytbl:
	.db	$57,$03		; A tone period
	.db	$ac,$01		; B tone period
	.db	$d6,$00		; C tone period
	.db 	$3f,$3f		; Period, enables
	.db	$07,$0f,$17,$ff	; Volumes

	;; AY-3-8910 enable sequence
aytble:
	.db	$3e,$3d,$3b,$ff
	

	;; 
	;; Common routines
	;;

	;; Write Ps to Score 1 and spin
pass:	
	ld	hl,led1
	ld	b,$06
rtpl:
	ld	(hl),$0e
	inc	l
	djnz	rtpl
spin:	
	jr 	spin


	
	;; Wait for (a) IRQs
irqwait:
	ld	hl,$a001
	ld	(hl),a		; Set counter
irqwl:
	ld	a,(hl)
	and	a
	jr	nz,irqwl
	ret

	
	
	;; Sets P1 credit to 1
	;; Sets P2 credit to 0
drawio:	
	xor	a
	ld	($e03e),a	; P1 credit = 0
	inc	a
	ld	($e03f),a	; P2 credit = 1

	;; Blank out both scores
clrsc:
	ld	hl,led2
	ld	b,$06
clrscl:
	ld	a,l
	ld	(hl),$ff
	or	$08		; Other score
	ld	l,a
	ld	(hl),$ff
	and	$f7		; Other score
	inc	a
	ld	l,a
	djnz	clrscl
	ret

	
	;; Write octal to display
	;; de address of lsb
doct:
	ld	b,a
	and	$07
	ld	(hl),a		; Low octal
	dec	hl
	
	ld	a,b
	rrca
	rrca
	rrca
	
	ld	b,a
	and	$07
	ld	(hl),a		; Mid octal
	dec	hl

	ld	a,b
	rrca
	rrca
	rrca
	and	$03
	ld	(hl),a		; High octal
	dec 	hl
	ret	
	
	
	;; Pad to end of ROM
	.org	$1fff
	.db	$ff
	.end
	