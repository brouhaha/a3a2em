	cpu	6502

fillto	macro	addr, val
	while	* < addr
size	set	addr-*
	if	size > 256
size	set	256
	endif
	fcb	[size] val
	endm
	endm

fcch	macro	string
	irpc	char,string
	fcb	$80+'char'
	endm
	endm

text_addr function x, y, (((y & 7) * 128) + ((y >> 3) * 40) + x)

text_line	macro	y
	if	(y > 0) && ((y >> 3) == 0)
	org	text_origin + ((y & 7) * 128) + ((y >> 3) * 40) - 8
	fcch	"        "	; screen holes
	else
	org	text_origin + ((y & 7) * 128) + ((y >> 3) * 40)
	endif
	endm


char_bs		equ	$08
char_cr		equ	$0d
char_esc	equ	$1b

Z00	equ	$00
Z02	equ	$02
blk	equ	$04
lstblk	equ	$05

ibbufp	equ	$85	; disk buffer pointer
ibcmd	equ	$87	; disk command, 0 = seek, 1 = read, 2 = write

Zf0	equ	$f0
Zf1	equ	$f1
Zf2	equ	$f2
Zf3	equ	$f3
Zf4	equ	$f4
Zf5	equ	$f5


a2resetvec	equ	$03f2
a2resetvecchk	equ	$03f4

text_page_1	equ	$0400
text_page_2	equ	$0800

r03c01	equ	text_addr(1, 3)
r05c01	equ	text_addr(1, 5)
r07c01	equ	text_addr(1, 7)
r10c01	equ	text_addr(1, 10)
r12c01	equ	text_addr(1, 12)
r14c01	equ	text_addr(1, 14)

r10c00	equ	text_addr(0, 10)
r12c00	equ	text_addr(0, 12)
r14c00	equ	text_addr(0, 14)


D05ab	equ	$05ab
D05b0	equ	$05b0

D0826	equ	$0826


ext_pg	equ	$1400

alt_zp	equ	$1800

D9600	equ	$9600


; keyboard
kbd	equ	$c000
Dc008	equ	$c008
kbd_clr	equ	$c010

Dc040	equ	$c040

Dc051	equ	$c051
Dc054	equ	$c054
Dc056	equ	$c056

Dc0da	equ	$c0da
Dc0db	equ	$c0db

Dc529	equ	$c529
Dc552	equ	$c552
Dc557	equ	$c557
Dc55c	equ	$c55c
Dc561	equ	$c561
Dc729	equ	$c729


; Apple III ROM entry points
blockio	equ	$f479

; Apple III VIA ports
Dffd0	equ	$ffd0
Dffdf	equ	$ffdf
Dffe3	equ	$ffe3
Dffec	equ	$ffec
Dffed	equ	$ffed
Dffee	equ	$ffee
Dffef	equ	$ffef


; Apple II ROM entry points
a2rst		equ	$fa62
a2init		equ	$fb2f
Sfb6f		equ	$fb6f
a2wait		equ	$fca8
a2normal	equ	$fe84
a2setkbd	equ	$fe89
a2setvid	equ	$fe93
a2rtrn		equ	$ff58


	org	$a000

				; Apple ///           Apple II
boot:	fcb	$01		; entry (ORA ZP,X)    boot0 sector count
	nop			; second byte of ORA  entry point

	lda	#$60		; is Apple II emulation alread running?
	cmp	a2rtrn		; RTS in Apple II monitor ROM
	bne	La049		; no

; Apple II emulation is already running, tell user
	ldx	#$00		; copy message to display
La00b:	lda	(La026-$a000)+$0800,x	; Apple II boot block loads at $0800
	sta	D05ab,x
	inx
	cpx	#$23
	bne	La00b

	ldx	#$1e
La018:	lda	#$ff
	jsr	a2wait		; Apple II monitor
	dex
	bne	La018

	inc	a2resetvecchk	; mark Apple II reset vector as invalid
	jmp	a2rst

La026:	fcch	"EMULATION DISK-INSERT APPLE II DISK"


;; real Apple /// entry point
La049:	sei
	cld
	lda	#$77
	sta	Dffdf

	ldx	#$fb
	txs

	bit	kbd_clr

; copy zero page to alt zero page, and clear extend page
	ldy	#$00
La058:	lda	Z00,y
	sta	alt_zp,y
	lda	#$00
	sta	ext_pg,y
	iny
	bne	La058

	lda	#$18
	sta	Dffd0

; read blocks $0001..$000b to $a200..$b7ff
	lda	#$01
	sta	ibcmd
	lda	#$00
	sta	ibbufp
	lda	#$a2
	sta	ibbufp+1
	lda	#$01
	sta	blk
	lda	#$0c
	sta	lstblk
	jsr	Sa094

; read blocks $0010..$004a to $2000..$95ff
	lda	#$10
	sta	blk
	lda	#$4b
	sta	lstblk
	lda	#$20
	sta	ibbufp+1
	jsr	Sa094

	jmp	La0d9


Sa094:	lda	blk
	cmp	lstblk
	bcs	La0a9
	ldx	#$00
	jsr	blockio
	bcs	La0aa
	inc	ibbufp+1
	inc	ibbufp+1
	inc	blk
	bne	Sa094
La0a9:	rts

La0aa:	ldx	#$00		; copy I/O error message to display
La0ac:	lda	Da0c2,x
	sta	D05b0,x
	inx
	cpx	#$17
	bne	La0ac

	lda	Dffdf
	ora	#$10
	sta	Dffdf

La0bf:	jmp	La0bf

Da0c2:	fcc	"** I/O ERROR - RETRY **"


; Everything before this point must be in first disk block
	if	*>$a200
	error	"boot block too long"
	endif


La0d9:	jsr	load_charset_a3
La0dc:	jsr	clear_screen
	ldx	#$00
	stx	Da3c5
	lda	#main_menu&$ff
	sta	Z00
	lda	#main_menu>>8
	sta	Z00+1
	lda	#text_page_1&$ff
	sta	Z02
	lda	#text_page_1>>8
	sta	Z02+1
	jsr	Sa5b7

La0f7:	lda	kbd
	bpl	La0f7
	bit	kbd_clr

	cmp	#char_cr+$80
	bne	La106
	jmp	La4c7
La106:	cmp	#char_esc+$80
	bne	La0f7

La10a:	jsr	clear_screen

	lda	#config_menu&$ff
	sta	Z00
	lda	#config_menu>>8
	sta	Da3c5
	sta	Z00+1

	lda	#text_page_1&$ff
	sta	Z02
	lda	#text_page_1>>8
	sta	Z02+1

	jsr	Sa5b7
	bit	Dc051

	ldy	#$05
La128:	lda	Da4a3,y
	sta	Da496,y
	dey
	bpl	La128

	ldx	#$00
	jsr	Sa301
	inx
	jsr	Sa301
	inx
	jsr	Sa301
	stx	Da4a2
	lda	Da497
	beq	La14e
	jsr	Sa28c
	ldx	#$00
	jmp	La153
La14e:	jsr	Sa29d
	ldx	#$00
La153:	lda	kbd
	bpl	La153
	cmp	#char_cr+$80
	bne	La1d7
	lda	Dc008
	bit	kbd_clr
	and	#$20
	beq	La169
	jmp	La4c7

La169:	ldx	#$05
La16b:	lda	Da496,x
	sta	Da4a3,x
	dex
	bpl	La16b

	lda	#$01	; read block 0 of disk
	sta	ibcmd
	lda	#D9600&$ff
	sta	ibbufp
	lda	#D9600>>8
	sta	ibbufp+1
	lda	#$00
	sta	blk
	ldx	#$00
	jsr	blockio
	bcc	La18e
	jmp	La337	; error

La18e:	ldx	#$00	; is it the emulation disk?
La190:	lda	boot,x
	cmp	D9600,x
	beq	La19b
	jmp	La358
La19b:	inx
	bne	La190

	lda	#$02	; write the page containing the config ($a400)
	sta	ibcmd	; to block 2 of the disk
	lda	#$00
	sta	ibbufp
	lda	#$a4
	sta	ibbufp+1
	lda	#$02
	ldx	#$00
	jsr	blockio
	bcs	La1b6
	jmp	La10a

La1b6:	jsr	clear_screen

	ldx	#$00
La1bb:	lda	msg_remove_write_protect,x
	sta	D05ab,x
	inx
	cpx	#msg_remove_write_protect_len
	bne	La1bb

	bit	Dc040
	ldx	#$ff
La1cb:	jsr	Sa325
	dex
	bne	La1cb
	bit	kbd_clr
	jmp	La10a
La1d7:	bit	kbd_clr
	cmp	#char_bs+$80
	bne	La213
	jsr	Sa2dd
	ldy	Da496,x
	dey
	tya
	bpl	La1eb
	lda	Da490,x
La1eb:	sta	Da496,x
La1ee:	jsr	Sa301
	cpx	#$01
	beq	La1f8
	jmp	La153
La1f8:	lda	Da497
	beq	La208
	jsr	Sa28c
	lda	#$02
	sta	Da4a2
	jmp	La153
La208:	jsr	Sa29d
	lda	#$05
	sta	Da4a2
	jmp	La153
La213:	cmp	#$95
	bne	La22e
	jsr	Sa2dd
	lda	Da496,x
	cmp	Da490,x
	bne	La229
	lda	#$00
	sta	Da496,x
	beq	La1ee
La229:	inc	Da496,x
	bne	La1ee
La22e:	cmp	#$8a
	bne	La243
	jsr	Sa277
	cpx	Da4a2
	bne	La23c
	ldx	#$ff
La23c:	inx
	jsr	Sa263
	jmp	La153
La243:	cmp	#$8b
	bne	La256
	jsr	Sa277
	dex
	bpl	La250
	ldx	Da4a2
La250:	jsr	Sa263
	jmp	La153
La256:	cmp	#$9b
	bne	La25d
	jmp	La10a
La25d:	bit	Dc040
	jmp	La153

Sa263:	txa
	asl
	tay
	lda	Da484,y
	sta	Z02
	lda	Da484+1,y
	sta	Z02+1
	lda	#$a3
	ldy	#$00
	sta	(Z02),y
	rts

Sa277:	lda	#$a0
	sta	text_page_1+r03c01
	sta	text_page_1+r05c01
	sta	text_page_1+r07c01
	sta	text_page_1+r10c01
	sta	text_page_1+r12c01
	sta	text_page_1+r14c01
	rts

Sa28c:	ldy	#$27
	lda	#$00
La290:	sta	text_page_2+r10c00,y
	sta	text_page_2+r12c00,y
	sta	text_page_2+r14c00,y
	dey
	bne	La290
	rts

Sa29d:	ldy	#$27
	lda	#$f0
La2a1:	sta	text_page_2+r10c00,y
	sta	text_page_2+r12c00,y
	sta	text_page_2+r14c00,y
	dey
	bne	La2a1
	txa
	pha
	ldx	#$03
	jsr	Sa301
	inx
	jsr	Sa301
	inx
	jsr	Sa301
	stx	Da4a2
	pla
	tax
	rts


Sa2c2:	clc
	lda	Da49c,x
	adc	Da496,x
	asl
	tay
	lda	Da45a,y
	sta	Z00
	sta	Z02
	lda	Da45a+1,y
	sta	Z02+1
	clc
	adc	#$04
	sta	Z00+1
	rts


Sa2dd:	jsr	Sa2c2
	txa
	pha
	ldx	#$0f
La2e4:	cpx	#$0a
	bcc	La2eb
	jsr	Sa325
La2eb:	ldy	#$00
La2ed:	lda	(Z00),y
	clc
	adc	#$0f
	sta	(Z00),y
	iny
	lda	(Z02),y
	cmp	#$a0
	bne	La2ed
	dex
	bne	La2e4
	pla
	tax
	rts

Sa301:	jsr	Sa2c2
	txa
	pha
	ldx	#$0f
La308:	cpx	#$05
	bcs	La30f
	jsr	Sa325
La30f:	ldy	#$00
La311:	lda	(Z00),y
	sec
	sbc	#$0f
	sta	(Z00),y
	iny
	lda	(Z02),y
	cmp	#$a0
	bne	La311
	dex
	bne	La308
	pla
	tax
	rts

Sa325:	lda	#$18
	sta	Dffed
La32a:	lda	kbd
	bmi	La336
	lda	Dffed
	and	#$10
	beq	La32a
La336:	rts

La337:	jsr	clear_screen

	ldx	#$00
La33c:	lda	msg_emu_disk_error,x
	sta	D05ab,x
	inx
	cpx	#msg_emu_disk_error_len
	bne	La33c

	bit	Dc040
	ldx	#$ff
La34c:	jsr	Sa325
	dex
	bne	La34c
	bit	kbd_clr
	jmp	La10a


La358:	jsr	clear_screen

	ldx	#$00
La35d:	lda	msg_insert_emu_disk,x
	sta	D05ab,x
	inx
	cpx	#msg_insert_emu_disk_len
	bne	La35d

	bit	Dc040
	ldx	#$ff
La36d:	jsr	Sa325
	dex
	bne	La36d
	bit	kbd_clr
	jmp	La10a

La379:	ldx	#$00
La37b:	lda	msg_insert_a2_disk,x
	sta	D05ab,x
	inx
	cpx	#msg_insert_a2_disk_len
	bne	La37b

	bit	Dc040
	ldx	#$ff
La38b:	jsr	Sa325
	dex
	bne	La38b
	bit	kbd_clr
	lda	Da3c5
	bne	La39c
	jmp	La0dc
La39c:	jmp	La10a

La39f:	ldx	#$00
La3a1:	lda	msg_a2_disk_error,x
	sta	D05ab,x
	inx
	cpx	#msg_a2_disk_error_len
	bne	La3a1
	bit	Dc040
	ldx	#$ff
La3b1:	jsr	Sa325
	dex
	bne	La3b1
	bit	kbd_clr
	lda	Da3c5
	bne	La3c2
	jmp	La0dc
La3c2:	jmp	La10a

Da3c5:	fcb	$00


msg_remove_write_protect:
	fcch	"PLEASE REMOVE WRITE PROTECT TAB"
msg_remove_write_protect_len equ *-msg_remove_write_protect

msg_insert_emu_disk:
	fcch	"PLEASE INSERT EMULATION DISK"
msg_insert_emu_disk_len equ *-msg_insert_emu_disk

msg_emu_disk_error:
	fcch	"UNABLE TO READ EMULATION DISK"
msg_emu_disk_error_len equ *-msg_emu_disk_error

msg_insert_a2_disk:
	fcch	"PLEASE INSERT APPLE II BOOT DISK"
msg_insert_a2_disk_len equ *-msg_insert_a2_disk

msg_a2_disk_error:
	fcch	"UNABLE TO READ APPLE II DISK"
msg_a2_disk_error_len equ *-msg_a2_disk_error


; configuration screen field locations
Da45a:	fdb	text_page_1+text_addr(15,3)	; lang: Applesoft
	fdb	text_page_1+text_addr(26,3)	; lang: Integer BASIC

	fdb	text_page_1+text_addr(15,5)	; card: Serial
	fdb	text_page_1+text_addr(23,5)	; card: Communications

	fdb	text_page_1+text_addr(16,7)	; baud: 110
	fdb	text_page_1+text_addr(21,7)	; baud: 300
	fdb	text_page_1+text_addr(26,7)	; baud: 600
	fdb	text_page_1+text_addr(31,7)	; baud: 1200
	fdb	text_page_1+text_addr(15,8)	; baud: 2400
	fdb	text_page_1+text_addr(20,8)	; baud: 4800
	fdb	text_page_1+text_addr(25,8)	; baud: 9600
	fdb	text_page_1+text_addr(30,8)	; baud: 19200

	fdb	text_page_1+text_addr(15,10)	; line feed: enabled
	fdb	text_page_1+text_addr(24,10)	; line feed: disabled

	fdb	text_page_1+text_addr(15,12)	; line width: 40
	fdb	text_page_1+text_addr(18,12)	; line width: 72
	fdb	text_page_1+text_addr(21,12)	; line width: 80
	fdb	text_page_1+text_addr(24,12)	; line width: 132

	fdb	text_page_1+text_addr(28,12)	; characters

	fdb	text_page_1+text_addr(27,14)	; CR delay: on
	fdb	text_page_1+text_addr(31,14)	; CR delay: off


Da484:	fdb	text_page_1+r03c01
	fdb	text_page_1+r05c01
	fdb	text_page_1+r07c01
	fdb	text_page_1+r10c01
	fdb	text_page_1+r12c01
	fdb	text_page_1+r14c01


; default configuration choices
Da490:	fcb	$01,$01,$07,$01,$04,$01

config_start	equ	*

Da496:	fcb	$00	; $00 for Applesoft, $01 for Integer BASIC
Da497:	fcb	$00	; $00 for slot ROMs from $5b00, $01 for $2000
Da498:	fcb	$03
Da499:	fcb	$00
Da49a:	fcb	$04	; line length setting
Da49b:	fcb	$01

config_end	equ	*


Da49c:	fcb	$00,$02,$04,$0c,$0e,$13

Da4a2:	fcb	$05

Da4a3:	fcb	$00,$00,$03,$00,$04,$01

Da4a9:	fcb	$93,$16,$17,$18,$1a,$1c,$1e,$1f	; indexed by Da498
Da4b1:	fcb	$b0,$40,$20,$10,$08,$04,$02,$01	; indexed by Da498

Da4b9:	fcb	$01,$00			; indexed by Da499

Da4bb:	fcb	$00,$80,$80,$80,$80	; indexed for line length (Da49a)

Da4c0:	fcb	$00,$40			; indexed by Da49b

Da4c2:	fcb	41,72,80,132,0		; line lengths (why 41?) (Da49a)


La4c7:	jsr	clear_screen
	jsr	load_charset_a2

	lda	Da496		; copy which ROM image, Integer or Applesoft?
	beq	La4d8
	lda	#$2b		; 2b00..5aff Integer BASIC
	sta	Z00+1
	bne	La4dc
La4d8:	lda	#$66		; 6600..95ff Applesoft
	sta	Z00+1

; copy main ROM image using extended addressing
; (avoids writing to VIA and ACIA registers)
La4dc:	lda	#$8f		; set Z02 to extended addressing
	sta	ext_pg+Z02+1

	lda	#$00
	sta	Z02
	sta	Z00
	lda	#$d0
	sta	Z02+1

	ldy	#$00
La4ed:	lda	(Z00),y
	sta	(Z02),y
	inc	Z00
	inc	Z02
	bne	La4ed
	inc	Z00+1
	inc	Z02+1
	bne	La4ed

; copy peripheral ROM images for slots 5 through 7
	lda	Da497		; which set of ROMs?
	beq	La508
	lda	#$20		; 2000..22ff
	sta	Z00+1
	bne	La50c
La508:	lda	#$5b		; 5b00..5dff
	sta	Z00+1
La50c:	lda	#$00
	sta	Z02
	sta	Z00
	lda	#$c5
	sta	Z02+1
	ldy	#$00
La518:	lda	(Z00),y
	sta	(Z02),y
	inc	Z00
	inc	Z02
	bne	La518
	inc	Z00+1
	inc	Z02+1
	lda	Z02+1
	cmp	#$c8
	bne	La518

	lda	#$00		; change Z02 back to normal addressing
	sta	ext_pg+Z02+1

	lda	Da497
	beq	La545

	ldx	Da498
	lda	Da4a9,x
	sta	Dc529
	sta	Dc729
	jmp	La56f

La545:	ldx	Da498		; slot 5 settings
	lda	Da4a9,x
	sta	Dc552
	lda	Da4b1,x
	sta	Dc557

	ldx	Da499
	lda	Da4b9,x

	ldx	Da49b
	ora	Da4c0,x

	ldx	Da49a
	ora	Da4bb,x
	sta	Dc55c
	lda	Da4c2,x
	sta	Dc561

La56f:	lda	#$00
	sta	Dffd0
	lda	#$fc
	sta	Dffdf
	lda	Dffef
	sta	Dffef
	lda	Dffe3
	ora	#$40
	sta	Dffe3
	lda	Dffef
	and	#$b0
	sta	Dffef

	jsr	a2init
	jsr	a2setvid
	jsr	a2setkbd
	jsr	a2normal

	lda	#$00
	sta	a2resetvec
	lda	#$e0
	sta	a2resetvec+1

	jsr	Sfb6f		; mark Apple II reset vector as valid

	lda	Dc051
	lda	Dc056
	lda	Dc054

	inc	a2resetvecchk	; mark Apple II reset vector as invalid
	jmp	a2rst


Sa5b7:	ldy	#$00
La5b9:	lda	(Z00),y
	beq	La5cd
	sta	(Z02),y
	inc	Z00
	bne	La5c5
	inc	Z00+1
La5c5:	inc	Z02
	bne	La5b9
	inc	Z02+1
	bne	La5b9
La5cd:	rts


clear_screen:
	ldy	#$00
La5d0:	lda	#$a0
	sta	text_page_1,y
	sta	text_page_1+$0100,y
	sta	text_page_1+$0200,y
	sta	text_page_1+$0300,y
	lda	#$f0
	sta	text_page_2,y
	sta	text_page_2+$0100,y
	sta	text_page_2+$0200,y
	sta	text_page_2+$0300,y
	iny
	bne	La5d0
	rts


load_charset_a3:
	lda	#$00
	sta	Zf4
	lda	#charset_a3&$ff
	sta	Zf0
	lda	#charset_a3>>8
	sta	Zf1
	bne	La60a

load_charset_a2:
	lda	#$00
	sta	Zf4
	lda	#charset_a2&$ff
	sta	Zf0
	lda	#charset_a2>>8
	sta	Zf1

La60a:	lda	#$18
	sta	Dffee
	lda	Dffec
	and	#$0f
	ora	#$30
	sta	Dffec
La619:	lda	#$07
	sta	Zf5
La61d:	jsr	Sa652
	inc	Zf4
	clc
	lda	Zf0
	adc	#$08
	sta	Zf0
	bcc	La62d
	inc	Zf1
La62d:	dec	Zf5
	bpl	La61d

	bit	Dc0db

	ldx	#$18
	stx	Dffed

La639:	lda	Dffed
	and	#$10
	beq	La639

	stx	Dffed

La643:	lda	Dffed
	and	#$08
	beq	La643

	bit	Dc0da

	bit	Zf4
	bpl	La619
	rts


Sa652:	ldx	#$00
	ldy	#$00
La656:	lda	Zf5
	and	#$03
	ora	Da67e,y
	sta	Zf2
	lda	Zf5
	lsr
	lsr
	cpy	#$04
	rol
	ora	#$08
	sta	Zf3
	lda	Zf4
	sta	(Zf2,x)
	lda	Zf3
	eor	#$0c
	sta	Zf3
	lda	(Zf0),y
	sta	(Zf2,x)
	iny
	cpy	#$08
	bcc	La656
	rts


Da67e:	fcb	$78,$7c,$f8,$fc,$78,$7c,$f8,$fc


charset_a3:
	fcb	$00,$1c,$22,$2a,$3a,$1a,$02,$3c	; $00
	fcb	$00,$08,$14,$22,$22,$3e,$22,$22	; $01
	fcb	$00,$1e,$22,$22,$1e,$22,$22,$1e	; $02
	fcb	$00,$1c,$22,$02,$02,$02,$22,$1c	; $03
	fcb	$00,$1e,$22,$22,$22,$22,$22,$1e	; $04
	fcb	$00,$3e,$02,$02,$1e,$02,$02,$3e	; $05
	fcb	$00,$3e,$02,$02,$1e,$02,$02,$02	; $06
	fcb	$00,$3c,$02,$02,$02,$32,$22,$3c	; $07
	fcb	$00,$22,$22,$22,$3e,$22,$22,$22	; $08
	fcb	$00,$1c,$08,$08,$08,$08,$08,$1c	; $09
	fcb	$00,$20,$20,$20,$20,$20,$22,$1c	; $0a
	fcb	$00,$22,$12,$0a,$06,$0a,$12,$22	; $0b
	fcb	$00,$02,$02,$02,$02,$02,$02,$3e	; $0c
	fcb	$00,$22,$36,$2a,$2a,$22,$22,$22	; $0d
	fcb	$00,$22,$22,$26,$2a,$32,$22,$22	; $0e
	fcb	$00,$1c,$22,$22,$22,$22,$22,$1c	; $0f
	fcb	$00,$1e,$22,$22,$1e,$02,$02,$02	; $10
	fcb	$00,$1c,$22,$22,$22,$2a,$12,$2c	; $11
	fcb	$00,$1e,$22,$22,$1e,$0a,$12,$22	; $12
	fcb	$00,$1c,$22,$02,$1c,$20,$22,$1c	; $13
	fcb	$00,$3e,$08,$08,$08,$08,$08,$08	; $14
	fcb	$00,$22,$22,$22,$22,$22,$22,$1c	; $15
	fcb	$00,$22,$22,$22,$22,$22,$14,$08	; $16
	fcb	$00,$22,$22,$22,$2a,$2a,$36,$22	; $17
	fcb	$00,$22,$22,$14,$08,$14,$22,$22	; $18
	fcb	$00,$22,$22,$14,$08,$08,$08,$08	; $19
	fcb	$00,$3e,$20,$10,$08,$04,$02,$3e	; $1a
	fcb	$00,$3e,$06,$06,$06,$06,$06,$3e	; $1b
	fcb	$00,$00,$02,$04,$08,$10,$20,$00	; $1c
	fcb	$00,$3e,$30,$30,$30,$30,$30,$3e	; $1d
	fcb	$00,$00,$00,$08,$14,$22,$00,$00	; $1e
	fcb	$00,$00,$00,$00,$00,$00,$00,$7f	; $1f
	fcb	$00,$00,$00,$00,$00,$00,$00,$00	; $20 space
	fcb	$01,$01,$01,$01,$01,$01,$01,$00	; $21
	fcb	$00,$14,$14,$14,$00,$00,$00,$00	; $22
	fcb	$08,$10,$3f,$40,$3f,$10,$08,$00	; $23
	fcb	$00,$00,$00,$00,$00,$00,$7f,$7f	; $24
	fcb	$01,$01,$00,$00,$00,$00,$00,$00	; $25
	fcb	$00,$00,$00,$00,$00,$00,$00,$00	; $26
	fcb	$00,$00,$00,$36,$49,$36,$00,$00	; $27
	fcb	$00,$08,$04,$02,$02,$02,$04,$08	; $28
	fcb	$00,$08,$10,$20,$20,$20,$10,$08	; $29
	fcb	$00,$08,$2a,$1c,$08,$1c,$2a,$08	; $2a
	fcb	$00,$00,$08,$08,$3e,$08,$08,$00	; $2b
	fcb	$00,$00,$00,$00,$00,$08,$08,$04	; $2c
	fcb	$00,$00,$00,$00,$3e,$00,$00,$00	; $2d
	fcb	$00,$00,$00,$00,$00,$00,$00,$08	; $2e
	fcb	$00,$00,$20,$10,$08,$04,$02,$00	; $2f
	fcb	$00,$1c,$22,$32,$2a,$26,$22,$1c	; $30 0
	fcb	$00,$08,$0c,$08,$08,$08,$08,$1c	; $31 1
	fcb	$00,$1c,$22,$20,$18,$04,$02,$3e	; $32 2
	fcb	$00,$3e,$20,$10,$18,$20,$22,$1c	; $33 3
	fcb	$00,$10,$18,$14,$12,$3e,$10,$10	; $34 4
	fcb	$00,$3e,$02,$1e,$20,$20,$22,$1c	; $35 5
	fcb	$00,$38,$04,$02,$1e,$22,$22,$1c	; $36 6
	fcb	$00,$3e,$20,$10,$08,$04,$04,$04	; $37 7
	fcb	$00,$1c,$22,$22,$1c,$22,$22,$1c	; $38 8
	fcb	$00,$1c,$22,$22,$3c,$20,$10,$0e	; $39 9
	fcb	$00,$00,$00,$08,$00,$08,$00,$00	; $3a
	fcb	$00,$00,$00,$08,$00,$08,$08,$04	; $3b
	fcb	$00,$10,$08,$04,$02,$04,$08,$10	; $3c
	fcb	$00,$00,$00,$3e,$00,$3e,$00,$00	; $3d
	fcb	$00,$04,$08,$10,$20,$10,$08,$04	; $3e
	fcb	$00,$1c,$22,$10,$08,$08,$00,$08	; $3f
	fcb	$80,$9c,$a2,$aa,$ba,$9a,$82,$bc	; $40 @
	fcb	$80,$88,$94,$a2,$a2,$be,$a2,$a2	; $41 A
	fcb	$80,$9e,$a2,$a2,$9e,$a2,$a2,$9e	; $42 B
	fcb	$80,$9c,$a2,$82,$82,$82,$a2,$9c	; $43 C
	fcb	$80,$9e,$a2,$a2,$a2,$a2,$a2,$9e	; $44 D
	fcb	$80,$be,$82,$82,$9e,$82,$82,$be	; $45 E
	fcb	$80,$be,$82,$82,$9e,$82,$82,$82	; $46 F
	fcb	$80,$bc,$82,$82,$82,$b2,$a2,$bc	; $47 G
	fcb	$80,$a2,$a2,$a2,$be,$a2,$a2,$a2	; $48 H
	fcb	$80,$9c,$88,$88,$88,$88,$88,$9c	; $49 I
	fcb	$80,$a0,$a0,$a0,$a0,$a0,$a2,$9c	; $4a J
	fcb	$80,$a2,$92,$8a,$86,$8a,$92,$a2	; $4b K
	fcb	$80,$82,$82,$82,$82,$82,$82,$be	; $4c L
	fcb	$80,$a2,$b6,$aa,$aa,$a2,$a2,$a2	; $4d M
	fcb	$80,$a2,$a2,$a6,$aa,$b2,$a2,$a2	; $4e N
	fcb	$80,$9c,$a2,$a2,$a2,$a2,$a2,$9c	; $4f O
	fcb	$80,$9e,$a2,$a2,$9e,$82,$82,$82	; $50 P
	fcb	$80,$9c,$a2,$a2,$a2,$aa,$92,$ac	; $51 Q
	fcb	$80,$9e,$a2,$a2,$9e,$8a,$92,$a2	; $52 R
	fcb	$80,$9c,$a2,$82,$9c,$a0,$a2,$9c	; $53 S
	fcb	$80,$be,$88,$88,$88,$88,$88,$88	; $54 T
	fcb	$80,$a2,$a2,$a2,$a2,$a2,$a2,$9c	; $55 U
	fcb	$80,$a2,$a2,$a2,$a2,$a2,$94,$88	; $56 V
	fcb	$80,$a2,$a2,$a2,$aa,$aa,$b6,$a2	; $57 W
	fcb	$80,$a2,$a2,$94,$88,$94,$a2,$a2	; $58 X
	fcb	$80,$a2,$a2,$94,$88,$88,$88,$88	; $59 Y
	fcb	$80,$be,$a0,$90,$88,$84,$82,$be	; $5a Z
	fcb	$80,$be,$86,$86,$86,$86,$86,$be	; $5b
	fcb	$80,$80,$82,$84,$88,$90,$a0,$80	; $5c
	fcb	$80,$be,$b0,$b0,$b0,$b0,$b0,$be	; $5d
	fcb	$80,$80,$80,$88,$94,$a2,$80,$80	; $5e
	fcb	$80,$80,$80,$80,$80,$80,$80,$ff	; $5f
	fcb	$80,$80,$80,$80,$80,$80,$80,$80	; $60
	fcb	$00,$00,$00,$1e,$11,$11,$11,$16	; $61
	fcb	$00,$00,$00,$0f,$11,$11,$11,$0d	; $62
	fcb	$00,$01,$01,$71,$09,$49,$09,$71	; $63
	fcb	$00,$00,$00,$01,$01,$00,$00,$00	; $64
	fcb	$00,$1b,$0a,$0a,$0a,$0a,$0a,$1b	; $65
	fcb	$01,$01,$00,$00,$00,$00,$7f,$7f	; $66
	fcb	$40,$40,$40,$40,$40,$40,$40,$00	; $67
	fcb	$00,$00,$00,$00,$00,$00,$00,$7f	; $68
	fcb	$00,$00,$00,$00,$00,$00,$00,$3f	; $69
	fcb	$00,$4e,$22,$4e,$02,$6e,$00,$7f	; $6a
	fcb	$00,$19,$44,$44,$45,$58,$00,$7f	; $6b
	fcb	$00,$19,$2a,$1b,$0a,$0a,$00,$7f	; $6c
	fcb	$40,$47,$41,$47,$41,$47,$40,$3f	; $6d
	fcb	$00,$66,$2a,$66,$2a,$6a,$00,$7f	; $6e
	fcb	$00,$5d,$48,$49,$48,$49,$00,$7f	; $6f
	fcb	$00,$1a,$2a,$1a,$2a,$2b,$00,$7f	; $70
	fcb	$40,$49,$4b,$4f,$4d,$49,$40,$3f	; $71
	fcb	$40,$40,$40,$40,$40,$40,$40,$40	; $72
	fcb	$20,$10,$3c,$1e,$1e,$3e,$1c,$7f	; $73
	fcb	$01,$21,$51,$51,$21,$51,$11,$60	; $74
	fcb	$40,$40,$40,$40,$40,$42,$41,$02	; $75
	fcb	$00,$08,$1c,$08,$08,$08,$00,$7f	; $76
	fcb	$41,$41,$41,$41,$41,$49,$49,$04	; $77
	fcb	$00,$08,$08,$08,$1c,$08,$00,$7f	; $78
	fcb	$00,$00,$04,$3e,$04,$00,$00,$7f	; $79
	fcb	$00,$00,$10,$3e,$10,$00,$00,$7f	; $7a
	fcb	$80,$80,$80,$88,$80,$88,$88,$84	; $7b
	fcb	$80,$90,$88,$84,$82,$84,$88,$90	; $7c
	fcb	$80,$80,$80,$be,$80,$be,$80,$80	; $7d
	fcb	$80,$84,$88,$90,$a0,$90,$88,$84	; $7e
	fcb	$80,$9c,$a2,$90,$88,$88,$80,$88	; $7f


charset_a2:
	fcb	$00,$1c,$22,$2a,$3a,$1a,$02,$3c	; $00
	fcb	$00,$08,$14,$22,$22,$3e,$22,$22	; $01
	fcb	$00,$1e,$22,$22,$1e,$22,$22,$1e	; $02
	fcb	$00,$1c,$22,$02,$02,$02,$22,$1c	; $03
	fcb	$00,$1e,$22,$22,$22,$22,$22,$1e	; $04
	fcb	$00,$3e,$02,$02,$1e,$02,$02,$3e	; $05
	fcb	$00,$3e,$02,$02,$1e,$02,$02,$02	; $06
	fcb	$00,$3c,$02,$02,$02,$32,$22,$3c	; $07
	fcb	$00,$22,$22,$22,$3e,$22,$22,$22	; $08
	fcb	$00,$1c,$08,$08,$08,$08,$08,$1c	; $09
	fcb	$00,$20,$20,$20,$20,$20,$22,$1c	; $0a
	fcb	$00,$22,$12,$0a,$06,$0a,$12,$22	; $0b
	fcb	$00,$02,$02,$02,$02,$02,$02,$3e	; $0c
	fcb	$00,$22,$36,$2a,$2a,$22,$22,$22	; $0d
	fcb	$00,$22,$22,$26,$2a,$32,$22,$22	; $0e
	fcb	$00,$1c,$22,$22,$22,$22,$22,$1c	; $0f
	fcb	$00,$1e,$22,$22,$1e,$02,$02,$02	; $10
	fcb	$00,$1c,$22,$22,$22,$2a,$12,$2c	; $11
	fcb	$00,$1e,$22,$22,$1e,$0a,$12,$22	; $12
	fcb	$00,$1c,$22,$02,$1c,$20,$22,$1c	; $13
	fcb	$00,$3e,$08,$08,$08,$08,$08,$08	; $14
	fcb	$00,$22,$22,$22,$22,$22,$22,$1c	; $15
	fcb	$00,$22,$22,$22,$22,$22,$14,$08	; $16
	fcb	$00,$22,$22,$22,$2a,$2a,$36,$22	; $17
	fcb	$00,$22,$22,$14,$08,$14,$22,$22	; $18
	fcb	$00,$22,$22,$14,$08,$08,$08,$08	; $19
	fcb	$00,$3e,$20,$10,$08,$04,$02,$3e	; $1a
	fcb	$00,$3e,$06,$06,$06,$06,$06,$3e	; $1b
	fcb	$00,$00,$02,$04,$08,$10,$20,$00	; $1c
	fcb	$00,$3e,$30,$30,$30,$30,$30,$3e	; $1d
	fcb	$00,$00,$00,$08,$14,$22,$00,$00	; $1e
	fcb	$00,$00,$00,$00,$00,$00,$00,$7f	; $1f
	fcb	$00,$00,$00,$00,$00,$00,$00,$00	; $20 space
	fcb	$00,$08,$08,$08,$08,$08,$00,$08	; $21 !
	fcb	$00,$14,$14,$14,$00,$00,$00,$00	; $22 "
	fcb	$00,$14,$14,$3e,$14,$3e,$14,$14	; $23
	fcb	$00,$08,$3c,$0a,$1c,$28,$1e,$08	; $24
	fcb	$00,$06,$26,$10,$08,$04,$32,$30	; $25
	fcb	$00,$04,$0a,$0a,$04,$2a,$12,$2c	; $26
	fcb	$00,$08,$08,$08,$00,$00,$00,$00	; $27
	fcb	$00,$08,$04,$02,$02,$02,$04,$08	; $28
	fcb	$00,$08,$10,$20,$20,$20,$10,$08	; $29
	fcb	$00,$08,$2a,$1c,$08,$1c,$2a,$08	; $2a
	fcb	$00,$00,$08,$08,$3e,$08,$08,$00	; $2b
	fcb	$00,$00,$00,$00,$00,$08,$08,$04	; $2c
	fcb	$00,$00,$00,$00,$3e,$00,$00,$00	; $2d
	fcb	$00,$00,$00,$00,$00,$00,$00,$08	; $2e
	fcb	$00,$00,$20,$10,$08,$04,$02,$00	; $2f
	fcb	$00,$1c,$22,$32,$2a,$26,$22,$1c	; $30 0
	fcb	$00,$08,$0c,$08,$08,$08,$08,$1c	; $31 1
	fcb	$00,$1c,$22,$20,$18,$04,$02,$3e	; $32 2
	fcb	$00,$3e,$20,$10,$18,$20,$22,$1c	; $33 3
	fcb	$00,$10,$18,$14,$12,$3e,$10,$10	; $34 4
	fcb	$00,$3e,$02,$1e,$20,$20,$22,$1c	; $35 5
	fcb	$00,$38,$04,$02,$1e,$22,$22,$1c	; $36 6
	fcb	$00,$3e,$20,$10,$08,$04,$04,$04	; $37 7
	fcb	$00,$1c,$22,$22,$1c,$22,$22,$1c	; $38 8
	fcb	$00,$1c,$22,$22,$3c,$20,$10,$0e	; $39 9
	fcb	$00,$00,$00,$08,$00,$08,$00,$00	; $3a
	fcb	$00,$00,$00,$08,$00,$08,$08,$04	; $3b
	fcb	$00,$10,$08,$04,$02,$04,$08,$10	; $3c
	fcb	$00,$00,$00,$3e,$00,$3e,$00,$00	; $3d
	fcb	$00,$04,$08,$10,$20,$10,$08,$04	; $3e
	fcb	$00,$1c,$22,$10,$08,$08,$00,$08	; $3f
	fcb	$80,$9c,$a2,$aa,$ba,$9a,$82,$bc	; $40 @
	fcb	$80,$88,$94,$a2,$a2,$be,$a2,$a2	; $41 A
	fcb	$80,$9e,$a2,$a2,$9e,$a2,$a2,$9e	; $42 B
	fcb	$80,$9c,$a2,$82,$82,$82,$a2,$9c	; $43 C
	fcb	$80,$9e,$a2,$a2,$a2,$a2,$a2,$9e	; $44 D
	fcb	$80,$be,$82,$82,$9e,$82,$82,$be	; $45 E
	fcb	$80,$be,$82,$82,$9e,$82,$82,$82	; $46 F
	fcb	$80,$bc,$82,$82,$82,$b2,$a2,$bc	; $47 G
	fcb	$80,$a2,$a2,$a2,$be,$a2,$a2,$a2	; $48 H
	fcb	$80,$9c,$88,$88,$88,$88,$88,$9c	; $49 I
	fcb	$80,$a0,$a0,$a0,$a0,$a0,$a2,$9c	; $4a J
	fcb	$80,$a2,$92,$8a,$86,$8a,$92,$a2	; $4b K
	fcb	$80,$82,$82,$82,$82,$82,$82,$be	; $4c L
	fcb	$80,$a2,$b6,$aa,$aa,$a2,$a2,$a2	; $4d M
	fcb	$80,$a2,$a2,$a6,$aa,$b2,$a2,$a2	; $4e N
	fcb	$80,$9c,$a2,$a2,$a2,$a2,$a2,$9c	; $4f O
	fcb	$80,$9e,$a2,$a2,$9e,$82,$82,$82	; $50 P
	fcb	$80,$9c,$a2,$a2,$a2,$aa,$92,$ac	; $51 Q
	fcb	$80,$9e,$a2,$a2,$9e,$8a,$92,$a2	; $52 R
	fcb	$80,$9c,$a2,$82,$9c,$a0,$a2,$9c	; $53 S
	fcb	$80,$be,$88,$88,$88,$88,$88,$88	; $54 T
	fcb	$80,$a2,$a2,$a2,$a2,$a2,$a2,$9c	; $55 U
	fcb	$80,$a2,$a2,$a2,$a2,$a2,$94,$88	; $56 V
	fcb	$80,$a2,$a2,$a2,$aa,$aa,$b6,$a2	; $57 W
	fcb	$80,$a2,$a2,$94,$88,$94,$a2,$a2	; $58 X
	fcb	$80,$a2,$a2,$94,$88,$88,$88,$88	; $59 Y
	fcb	$80,$be,$a0,$90,$88,$84,$82,$be	; $5a Z
	fcb	$80,$be,$86,$86,$86,$86,$86,$be	; $5b
	fcb	$80,$80,$82,$84,$88,$90,$a0,$80	; $5c
	fcb	$80,$be,$b0,$b0,$b0,$b0,$b0,$be	; $5d
	fcb	$80,$80,$80,$88,$94,$a2,$80,$80	; $5e
	fcb	$80,$80,$80,$80,$80,$80,$80,$ff	; $5f
	fcb	$80,$80,$80,$80,$80,$80,$80,$80	; $60
	fcb	$80,$88,$88,$88,$88,$88,$80,$88	; $61
	fcb	$80,$94,$94,$94,$80,$80,$80,$80	; $62
	fcb	$80,$94,$94,$be,$94,$be,$94,$94	; $63
	fcb	$80,$88,$bc,$8a,$9c,$a8,$9e,$88	; $64
	fcb	$80,$86,$a6,$90,$88,$84,$b2,$b0	; $65
	fcb	$80,$84,$8a,$8a,$84,$aa,$92,$ac	; $66
	fcb	$80,$88,$88,$88,$80,$80,$80,$80	; $67
	fcb	$80,$88,$84,$82,$82,$82,$84,$88	; $68
	fcb	$80,$88,$90,$a0,$a0,$a0,$90,$88	; $69
	fcb	$80,$88,$aa,$9c,$88,$9c,$aa,$88	; $6a
	fcb	$80,$80,$88,$88,$be,$88,$88,$80	; $6b
	fcb	$80,$80,$80,$80,$80,$88,$88,$84	; $6c
	fcb	$80,$80,$80,$80,$be,$80,$80,$80	; $6d
	fcb	$80,$80,$80,$80,$80,$80,$80,$88	; $6e
	fcb	$80,$80,$a0,$90,$88,$84,$82,$80	; $6f
	fcb	$80,$9c,$a2,$b2,$aa,$a6,$a2,$9c	; $70
	fcb	$80,$88,$8c,$88,$88,$88,$88,$9c	; $71
	fcb	$80,$9c,$a2,$a0,$98,$84,$82,$be	; $72
	fcb	$80,$be,$a0,$90,$98,$a0,$a2,$9c	; $73
	fcb	$80,$90,$98,$94,$92,$be,$90,$90	; $74
	fcb	$80,$be,$82,$9e,$a0,$a0,$a2,$9c	; $75
	fcb	$80,$b8,$84,$82,$9e,$a2,$a2,$9c	; $76
	fcb	$80,$be,$a0,$90,$88,$84,$84,$84	; $77
	fcb	$80,$9c,$a2,$a2,$9c,$a2,$a2,$9c	; $78
	fcb	$80,$9c,$a2,$a2,$bc,$a0,$90,$8e	; $79
	fcb	$80,$80,$80,$88,$80,$88,$80,$80	; $7a
	fcb	$80,$80,$80,$88,$80,$88,$88,$84	; $7b
	fcb	$80,$90,$88,$84,$82,$84,$88,$90	; $7c
	fcb	$80,$80,$80,$be,$80,$be,$80,$80	; $7d
	fcb	$80,$84,$88,$90,$a0,$90,$88,$84	; $7e
	fcb	$80,$9c,$a2,$90,$88,$88,$80,$88	; $7f


config_menu:
text_origin	set	*
	text_line 0
	fcch	"        abbcde  EMULATION MODE          "
	text_line 1
	fcch	"$$$$$$$$$ff$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
	text_line 2
	fcch	"                                        "
	text_line 3
	fcch	" # LANGUAGE:   APPLESOFT  INTEGER&BASIC "
	text_line 4
	fcch	"                                        "
	text_line 5
	fcch	"   CARD:       SERIAL  COMMUNICATIONS   "
	text_line 6
	fcch	"                                        "
	text_line 7
	fcch	"   BAUD RATE:   110  300  600  1200     "
	text_line 8
	fcch	"               2400 4800 9600 19200     "
	text_line 9
	fcch	"                                        "
	text_line 10
	fcch	"   LINE FEED:  ENABLED  DISABLED        "
	text_line 11
	fcch	"                                        "
	text_line 12
	fcch	"   LINE WIDTH: 40 72 80 132 "
	fcb	$a7
	fcch	" CHARACTERS"
	text_line 13
	fcch	"                                        "
	text_line 14
	fcch	"   CARRIAGE RETURN DELAY:  ON  OFF      "
	text_line 15
	fcch	"                                        "
	text_line 16
	fcch	"     hhhi                               "
	text_line 17
	fcch	"    gnopq      - BOOT abbcde DISK       "
	text_line 18
	fcch	"     hhhi              %%               "
	text_line 19
	fcch	"    gjklm      - RESTORE DEFAULTS       "
	text_line 20
	fcch	"     h  hhhi                            "
	text_line 21
	fcch	"    rstunopq   - SAVE CONFIGURATION     "
	text_line 22
	fcch	"     h h h h      TO EMULATION DISK     "
	text_line 23
	fcch	"    gvwxwywz!  - SELECTION KEYS         "

	fcb	$00	; end


main_menu:
text_origin	set	*
	text_line 0
	fcch	"                                        "
	text_line 1
	fcch	"                                        "
	text_line 2
	fcch	"        abbcde  EMULATION MODE          "
	text_line 3
	fcch	"         %%                             "
	text_line 4
	fcch	"$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
	text_line 5
	fcch	"                                        "
	text_line 6
	fcch	"                                        "
	text_line 7
	fcch	"                                        "
	text_line 8
	fcch	"                                        "
	text_line 9
	fcch	"        hhhi                            "
	text_line 10
	fcch	"       gnopq  -  BOOT abbcde DISK       "
	text_line 11
	fcch	"                       %%               "
	text_line 12
	fcch	"                                        "
	text_line 13
	fcch	"        hhhi                            "
	text_line 14
	fcch	"       gjklm  -  CONFIGURATION MENU     "
	text_line 15
	fcch	"                                        "
	text_line 16
	fcch	"                                        "
	text_line 17
	fcch	"                                        "
	text_line 18
	fcch	"                                        "
	text_line 19
	fcch	"                                        "
	text_line 20
	fcch	"                                        "
	text_line 21
	fcch	"                                        "
	text_line 22
	fcch	"                                        "
	text_line 23
	fcch	"                                        "

	fcb	$00	; end

	fillto	$b800,$00
