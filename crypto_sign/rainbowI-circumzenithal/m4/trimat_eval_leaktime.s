.syntax unified
.cpu cortex-m4
.thumb

.macro bitslice out0, out1, out2, out3, in0, in1, in2, in3
    // use out3 as tmp
    and.w \out0, \in0, #0x11111111
    and.w \out3, \in1, #0x11111111
    orr.w \out0, \out0, \out3, lsl#1
    and.w \out3, \in2,  #0x11111111
    orr.w \out0, \out0, \out3, lsl#2
    and.w \out3, \in3, #0x11111111
    orr.w \out0, \out0, \out3, lsl#3

    and.w \out1, \in1, #0x22222222
    and.w \out3, \in0, #0x22222222
    orr.w \out1, \out1, \out3, lsr#1
    and.w \out3, \in2, #0x22222222
    orr.w \out1, \out1, \out3, lsl#1
    and.w \out3, \in3, #0x22222222
    orr.w \out1, \out1, \out3, lsl#2

    and.w \out2, \in2, #0x44444444
    and.w \out3, \in0, #0x44444444
    orr.w \out2, \out2, \out3, lsr#2
    and.w \out3, \in1, #0x44444444
    orr.w \out2, \out2, \out3, lsr#1
    and.w \out3, \in3, #0x44444444
    orr.w \out2, \out2, \out3, lsl#1

    and.w \out3, \in3, #0x88888888
    // in3 no longer needed; use as tmp
    and.w \in3, \in0, #0x88888888
    orr.w \out3, \out3, \in3, lsr#3
    and.w \in3, \in1, #0x88888888
    orr.w \out3, \out3, \in3, lsr#2
    and.w \in3, \in2, #0x88888888
    orr.w \out3, \out3, \in3, lsr#1
.endm

.macro madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
    tst.w \b_32, #1
    itttt ne
    eorne.w \accu0, \accu0, \mat0      // out[0] ^= (b[0] & a[0])
    eorne.w \accu1, \accu1, \mat1      // out[1] ^= (b[0] & a[1])
    eorne.w \accu2, \accu2, \mat2      // out[2] ^= (b[0] & a[2])
    eorne.w \accu3, \accu3, \mat3      // out[3] ^= (b[0] & a[3])

    eor.w \tmp0, \mat0, \mat1          // tmp0 = a[0] ^ a[1]
    eor.w \tmp1, \mat2, \mat3          // tmp1 = a[2] ^ a[3]
    tst.w \b_32, #2
    itttt ne
    eorne.w \accu0, \accu0, \mat1      // out[0] ^= (b[1] & a[1])
    eorne.w \accu1, \accu1, \tmp0      // out[1] ^= (b[1] & (a[0] ^ a[1]))
    eorne.w \accu2, \accu2, \mat3      // out[2] ^= (b[1] & a[3])
    eorne.w \accu3, \accu3, \tmp1      // out[3] ^= (b[1] & (a[2] ^ a[3]))


    mov.w \tmp2, #0
    ands \tmp3, \tmp2, \b_32, LSR #3

    itttt cs
    eorcs.w \tmp2, \mat2               // tmp2 = (b[2] & a[2])
    eorcs.w \tmp3, \mat3               // tmp3 = (b[2] & a[3])
    eorcs.w \accu2, \accu2, \mat0      // out[2] ^= (b[2] & a[0])
    eorcs.w \accu3, \accu3, \mat1      // out[3] ^= (b[2] & a[1])

    tst.w \b_32, #8
    itttt ne
    eorne.w \accu2, \accu2, \mat1      // out[2] ^= (b[3] & a[1])
    eorne.w \accu3, \accu3, \tmp0      // out[3] ^= (b[3] & (a[0] ^ a[1]))
    eorne.w \tmp2, \tmp2, \mat3        // tmp2 = (b[2] & a[2]) ^ (b[3] & a[3]))
    eorne.w \tmp3, \tmp3, \tmp1        // tmp3 = (b[2] & a[3]) ^ (b[3] & (a[2] ^ a[3]))

    eor.w \accu0, \accu0, \tmp3        // out[0] ^= (b[2] & a[3]) ^ (b[3] & (a[2] ^ a[3]))
    eor.w \accu1, \accu1, \tmp2        // out[1] ^= (b[2] & a[2]) ^ (b[3] & a[3]))
    eor.w \accu1, \accu1, \tmp3        // out[1] ^= (b[2] & a[3]) ^ (b[3] & (a[2] ^ a[3]))
    eor.w \accu2, \accu2, \tmp2        // out[2] ^= (b[2] & a[2]) ^ (b[3] & a[3]))
    eor.w \accu3, \accu3, \tmp3        // out[3] ^= (b[2] & a[3]) ^ (b[3] & (a[2] ^ a[3]))
.endm

.global batch_quad_trimat_eval_gf16_100_32_leaktime_asm
.type batch_quad_trimat_eval_gf16_100_32_leaktime_asm, %function
.align 2
batch_quad_trimat_eval_gf16_100_32_leaktime_asm:
	push.w {r4-r11, r14}
	ctr1   .req r0
	trimat .req r1
	ctr2   .req r2
	xi	   .req r3

	xj     .req r5
	lutgf    .req r0
	mat0     .req r6
	mat1     .req r7
	mat2     .req r8
	mat3     .req r9
	buf0     .req r10
	buf1     .req r11
	buf2     .req r12
	buf3     .req r14
	tmp    	 .req sp
	xptr     .req r4
	sub.w sp, sp, #480+32+100
	add.w xptr, sp, #480+32
	vmov.w s0, r0
	vmov.w s2, r3

	// init tmp to zero
	mov.w r0, #0
	.set i, 0
	.rept 60
		strd.w r0, r0, [sp, #32+i*8]
		.set i, i+1
	.endr

	// set _x
	.set i, 0
	.rept 12
	ldr.w r0, [r2, #i*4]
	and.w r3, r0, #0xF
	and.w r5, r0, #0xF0
	add.w r3, r3, r5, lsl#4
	and.w r5, r0, #0xF00
	add.w r3, r3, r5, lsl#8
	and.w r5, r0, #0xF000
	add.w r3, r3, r5, lsl#12
	str.w r3, [xptr, #i*8]
	ubfx.w r3, r0, #16, #4
	and.w r5, r0, #0xF00000
	add.w r3, r3, r5, lsr#12
	and.w r5, r0, #0xF000000
	add.w r3, r3, r5, lsr#8
	and.w r5, r0, #0xF0000000
	add.w r3, r3, r5, lsr#4
	str.w r3, [xptr, #i*8+4]
	.set i, i+1
	.endr
	ldrh.w r0, [r2, #48]
	and.w r3, r0, #0xF
	and.w r5, r0, #0xF0
	add.w r3, r3, r5, lsl#4
	and.w r5, r0, #0xF00
	add.w r3, r3, r5, lsl#8
	and.w r5, r0, #0xF000
	add.w r3, r3, r5, lsl#12
	str.w r3, [xptr, #96]
	// setting _x done;

	mov.w ctr1, #100
	vmov.w s1, xptr
	outer: // for(int i=0;i<dim;i++)
		vmov.w xptr, s1
		ldrb.w xi, [xptr], #1
		vmov.w s1, xptr

		// if 0, do nothing
		cmp.w xi, #0
		beq.w skip_outer

		mov.w ctr2, ctr1
		vmov.w s3, ctr1
		vmov.w lutgf, s2
		sub.w xptr, xptr, #1
		inner: // for(int j=i; j<dim; j++)
			ldrb.w xj, [xptr], #1
			// if 0, do nothing
			cmp.w xj, #0
			beq.w skip_inner
			orr.w xj, xi, xj, lsl#4
			ldrb.w xj, [lutgf, xj]

			// compute address of buffer
			add.w xj, sp, xj, lsl#5

			ldr.w buf0, [xj, #0]
			ldr.w buf1, [xj, #4]
			ldr.w buf2, [xj, #8]
			ldr.w buf3, [xj, #12]
			ldr.w mat1, [trimat, #4]
			ldr.w mat2, [trimat, #8]
			ldr.w mat3, [trimat, #12]
			ldr.w mat0, [trimat], #16
			eor.w buf0, buf0, mat0
			str.w buf0, [xj, #0]
			eor.w buf1, buf1, mat1
			str.w buf1, [xj, #4]
			eor.w buf2, buf2, mat2
			str.w buf2, [xj, #8]
			eor.w buf3, buf3, mat3
			str.w buf3, [xj, #12]

			ldr.w buf0, [xj, #16]
			ldr.w buf1, [xj, #20]
			ldr.w buf2, [xj, #24]
			ldr.w buf3, [xj, #28]
			ldr.w mat1, [trimat, #4]
			ldr.w mat2, [trimat, #8]
			ldr.w mat3, [trimat, #12]
			ldr.w mat0, [trimat], #16
			eor.w buf0, buf0, mat0
			str.w buf0, [xj, #16]
			eor.w buf1, buf1, mat1
			str.w buf1, [xj, #20]
			eor.w buf2, buf2, mat2
			str.w buf2, [xj, #24]
			eor.w buf3, buf3, mat3
			str.w buf3, [xj, #28]
			subs.w ctr2, ctr2, #1
			bne.w inner
			cont_inner:

		vmov.w ctr1, s3
		subs.w ctr1, ctr1, #1
		bne.w outer
	cont_outer:
	// do the actual multiplication
	add.w r1, sp, #32
    ldr.w r7, [r1, #4]
    ldr.w r8, [r1, #8]
    ldr.w r9, [r1, #12]
    ldr.w r6, [r1], #32
    bitslice r2, r3, r4, r5, r6, r7, r8, r9
    mov.w r0, #2
    1:
        ldr.w r7, [r1, #4]
        ldr.w r8, [r1, #8]
        ldr.w r9, [r1, #12]
        ldr.w r6, [r1], #32

        bitslice r10, r11, r12, r14, r6, r7, r8, r9
        madd_bitsliced r2, r3, r4, r5, r10, r11, r12, r14, r0, r6, r7, r8, r9

        add.w r0, r0, #1
        cmp.w r0, #16
        bne.w 1b

    bitslice r6, r7, r8, r9, r2, r3, r4, r5
	vmov.w r0, s0
    str.w r6, [r0]
    str.w r7, [r0, #4]
    str.w r8, [r0, #8]
    str.w r9, [r0, #12]

    sub.w r1, r1, #32*15-16
    ldr.w r7, [r1, #4]
    ldr.w r8, [r1, #8]
    ldr.w r9, [r1, #12]
    ldr.w r6, [r1], #32
    bitslice r2, r3, r4, r5, r6, r7, r8, r9
    mov.w r0, #2
    1:
        ldr.w r7, [r1, #4]
        ldr.w r8, [r1, #8]
        ldr.w r9, [r1, #12]
        ldr.w r6, [r1], #32
        bitslice r10, r11, r12, r14, r6, r7, r8, r9
        madd_bitsliced r2, r3, r4, r5, r10, r11, r12, r14, r0, r6, r7, r8, r9

        add.w r0, r0, #1
        cmp.w r0, #16
        bne.w 1b

    bitslice r6, r7, r8, r9, r2, r3, r4, r5
    vmov.w r0, s0
    str.w r6, [r0, #16]
    str.w r7, [r0, #20]
    str.w r8, [r0, #24]
    str.w r9, [r0, #28]

	add.w sp, sp, #480+32+100
	pop.w {r4-r11, pc}

	skip_inner:
		add.w trimat, trimat, #32
		subs.w ctr2, ctr2, #1
		bne.w inner
		b cont_inner
	skip_outer:
		add.w trimat, trimat,  ctr1, lsl#5
		subs.w ctr1, ctr1, #1
		bne.w outer
		b cont_outer

.global batch_quad_trimat_eval_gf16_96_32_leaktime_asm
.type batch_quad_trimat_eval_gf16_96_32_leaktime_asm, %function
.align 2
batch_quad_trimat_eval_gf16_96_32_leaktime_asm:
	push.w {r4-r11, r14}
	ctr1   .req r0
	trimat .req r1
	ctr2   .req r2
	xi	   .req r3

	xj       .req r5
	lutgf    .req r0
	mat0     .req r6
	mat1     .req r7
	mat2     .req r8
	mat3     .req r9
	buf0     .req r10
	buf1     .req r11
	buf2     .req r12
	buf3     .req r14
	tmp    	 .req sp
	xptr     .req r4
	sub.w sp, sp, #480+32+96
	add.w xptr, sp, #480+32
	vmov.w s0, r0
	vmov.w s2, r3

	// init tmp to zero
	mov.w r0, #0
	.set i, 0
	.rept 60
		strd.w r0, r0, [sp, #32+i*8]
		.set i, i+1
	.endr

	// set _x
	.set i, 0
	.rept 12
	ldr.w r0, [r2, #i*4]
	and.w r3, r0, #0xF
	and.w r5, r0, #0xF0
	add.w r3, r3, r5, lsl#4
	and.w r5, r0, #0xF00
	add.w r3, r3, r5, lsl#8
	and.w r5, r0, #0xF000
	add.w r3, r3, r5, lsl#12
	str.w r3, [xptr, #i*8]
	ubfx.w r3, r0, #16, #4
	and.w r5, r0, #0xF00000
	add.w r3, r3, r5, lsr#12
	and.w r5, r0, #0xF000000
	add.w r3, r3, r5, lsr#8
	and.w r5, r0, #0xF0000000
	add.w r3, r3, r5, lsr#4
	str.w r3, [xptr, #i*8+4]
	.set i, i+1
	.endr
	// setting _x done;

	mov.w ctr1, #96
	vmov.w s1, xptr
	outer2: // for(int i=0;i<dim;i++)
		vmov.w xptr, s1
		ldrb.w xi, [xptr], #1
		vmov.w s1, xptr

		// if 0, do nothing
		cmp.w xi, #0
		beq.w skip_outer2

		mov.w ctr2, ctr1
		vmov.w s3, ctr1
		vmov.w lutgf, s2
		sub.w xptr, xptr, #1
		inner2: // for(int j=i; j<dim; j++)
			ldrb.w xj, [xptr], #1
			// if 0, do nothing
			cmp.w xj, #0
			beq.w skip_inner2
			orr.w xj, xi, xj, lsl#4
			ldrb.w xj, [lutgf, xj]

			// compute address of buffer
			add.w xj, sp, xj, lsl#5

			ldr.w buf0, [xj, #0]
			ldr.w buf1, [xj, #4]
			ldr.w buf2, [xj, #8]
			ldr.w buf3, [xj, #12]
			ldr.w mat1, [trimat, #4]
			ldr.w mat2, [trimat, #8]
			ldr.w mat3, [trimat, #12]
			ldr.w mat0, [trimat], #16
			eor.w buf0, buf0, mat0
			str.w buf0, [xj, #0]
			eor.w buf1, buf1, mat1
			str.w buf1, [xj, #4]
			eor.w buf2, buf2, mat2
			str.w buf2, [xj, #8]
			eor.w buf3, buf3, mat3
			str.w buf3, [xj, #12]

			ldr.w buf0, [xj, #16]
			ldr.w buf1, [xj, #20]
			ldr.w buf2, [xj, #24]
			ldr.w buf3, [xj, #28]
			ldr.w mat1, [trimat, #4]
			ldr.w mat2, [trimat, #8]
			ldr.w mat3, [trimat, #12]
			ldr.w mat0, [trimat], #16
			eor.w buf0, buf0, mat0
			str.w buf0, [xj, #16]
			eor.w buf1, buf1, mat1
			str.w buf1, [xj, #20]
			eor.w buf2, buf2, mat2
			str.w buf2, [xj, #24]
			eor.w buf3, buf3, mat3
			str.w buf3, [xj, #28]
			subs.w ctr2, ctr2, #1
			bne.w inner2
			cont_inner2:

		vmov.w ctr1, s3
		subs.w ctr1, ctr1, #1
		bne.w outer2
	cont_outer2:
	// do the actual multiplication
	add.w r1, sp, #32
    ldr.w r7, [r1, #4]
    ldr.w r8, [r1, #8]
    ldr.w r9, [r1, #12]
    ldr.w r6, [r1], #32
    bitslice r2, r3, r4, r5, r6, r7, r8, r9
    mov.w r0, #2
    1:
        ldr.w r7, [r1, #4]
        ldr.w r8, [r1, #8]
        ldr.w r9, [r1, #12]
        ldr.w r6, [r1], #32

        bitslice r10, r11, r12, r14, r6, r7, r8, r9
        madd_bitsliced r2, r3, r4, r5, r10, r11, r12, r14, r0, r6, r7, r8, r9

        add.w r0, r0, #1
        cmp.w r0, #16
        bne.w 1b

    bitslice r6, r7, r8, r9, r2, r3, r4, r5
	vmov.w r0, s0
    str.w r6, [r0]
    str.w r7, [r0, #4]
    str.w r8, [r0, #8]
    str.w r9, [r0, #12]

    sub.w r1, r1, #32*15-16
    ldr.w r7, [r1, #4]
    ldr.w r8, [r1, #8]
    ldr.w r9, [r1, #12]
    ldr.w r6, [r1], #32
    bitslice r2, r3, r4, r5, r6, r7, r8, r9
    mov.w r0, #2
    1:
        ldr.w r7, [r1, #4]
        ldr.w r8, [r1, #8]
        ldr.w r9, [r1, #12]
        ldr.w r6, [r1], #32
        bitslice r10, r11, r12, r14, r6, r7, r8, r9
        madd_bitsliced r2, r3, r4, r5, r10, r11, r12, r14, r0, r6, r7, r8, r9

        add.w r0, r0, #1
        cmp.w r0, #16
        bne.w 1b

    bitslice r6, r7, r8, r9, r2, r3, r4, r5
    vmov.w r0, s0
    str.w r6, [r0, #16]
    str.w r7, [r0, #20]
    str.w r8, [r0, #24]
    str.w r9, [r0, #28]

	add.w sp, sp, #480+32+96
	pop.w {r4-r11, pc}

	skip_inner2:
		add.w trimat, trimat, #32
		subs.w ctr2, ctr2, #1
		bne.w inner2
		b cont_inner2
	skip_outer2:
		add.w trimat, trimat,  ctr1, lsl#5
		subs.w ctr1, ctr1, #1
		bne.w outer2
		b cont_outer2


.global batch_quad_trimat_eval_gf16_32_16_leaktime_asm
.type batch_quad_trimat_eval_gf16_32_16_leaktime_asm, %function
.align 2
batch_quad_trimat_eval_gf16_32_16_leaktime_asm:
	push.w {r4-r11, r14}
	ctr1   .req r0
	trimat .req r1
	ctr2   .req r2
	xi	   .req r3

	xj       .req r5
	lutgf    .req r0
	mat0     .req r6
	mat1     .req r7
	mat2     .req r8
	mat3     .req r9
	buf0     .req r10
	buf1     .req r11
	buf2     .req r12
	buf3     .req r14
	tmp    	 .req sp
	xptr     .req r4
    // N=32, M=16
	sub.w sp, sp, #16*16+32 //16*M + N
	add.w xptr, sp, #16*16  //16*M
	vmov.w s0, r0
	vmov.w s2, r3

	// init tmp to zero
	mov.w r0, #0
	.set i, 0
	.rept 30 // 16*M / 8
		strd.w r0, r0, [sp, #16+i*8] // skip the first M bytes
		.set i, i+1
	.endr

	// set _x
	.set i, 0
	.rept 4 // N / 8
	ldr.w r0, [r2, #i*4]
	and.w r3, r0, #0xF
	and.w r5, r0, #0xF0
	add.w r3, r3, r5, lsl#4
	and.w r5, r0, #0xF00
	add.w r3, r3, r5, lsl#8
	and.w r5, r0, #0xF000
	add.w r3, r3, r5, lsl#12
	str.w r3, [xptr, #i*8]
	ubfx.w r3, r0, #16, #4
	and.w r5, r0, #0xF00000
	add.w r3, r3, r5, lsr#12
	and.w r5, r0, #0xF000000
	add.w r3, r3, r5, lsr#8
	and.w r5, r0, #0xF0000000
	add.w r3, r3, r5, lsr#4
	str.w r3, [xptr, #i*8+4]
	.set i, i+1
	.endr
	// setting _x done;

	mov.w ctr1, #32 // N
	vmov.w s1, xptr
	outer3: // for(int i=0;i<dim;i++)
		vmov.w xptr, s1
		ldrb.w xi, [xptr], #1
		vmov.w s1, xptr

		// if 0, do nothing
		cmp.w xi, #0
		beq.w skip_outer3

		mov.w ctr2, ctr1
		vmov.w s3, ctr1
		vmov.w lutgf, s2
		sub.w xptr, xptr, #1
		inner3: // for(int j=i; j<dim; j++)
			ldrb.w xj, [xptr], #1
			// if 0, do nothing
			cmp.w xj, #0
			beq.w skip_inner3
			orr.w xj, xi, xj, lsl#4
			ldrb.w xj, [lutgf, xj]

			// compute address of buffer
			add.w xj, sp, xj, lsl#4 // log_2(M)

			ldr.w buf0, [xj, #0]
			ldr.w buf1, [xj, #4]
			ldr.w buf2, [xj, #8]
			ldr.w buf3, [xj, #12]
			ldr.w mat1, [trimat, #4]
			ldr.w mat2, [trimat, #8]
			ldr.w mat3, [trimat, #12]
			ldr.w mat0, [trimat], #16
			eor.w buf0, buf0, mat0
			str.w buf0, [xj, #0]
			eor.w buf1, buf1, mat1
			str.w buf1, [xj, #4]
			eor.w buf2, buf2, mat2
			str.w buf2, [xj, #8]
			eor.w buf3, buf3, mat3
			str.w buf3, [xj, #12]

			subs.w ctr2, ctr2, #1
			bne.w inner3
			cont_inner3:

		vmov.w ctr1, s3
		subs.w ctr1, ctr1, #1
		bne.w outer3
	cont_outer3:
	// do the actual multiplication
	add.w r1, sp, #16 // M
    ldr.w r7, [r1, #4]
    ldr.w r8, [r1, #8]
    ldr.w r9, [r1, #12]
    ldr.w r6, [r1], #16 // M
    bitslice r2, r3, r4, r5, r6, r7, r8, r9
    mov.w r0, #2
    1:
        ldr.w r7, [r1, #4]
        ldr.w r8, [r1, #8]
        ldr.w r9, [r1, #12]
        ldr.w r6, [r1], #16 // M

        bitslice r10, r11, r12, r14, r6, r7, r8, r9
        madd_bitsliced r2, r3, r4, r5, r10, r11, r12, r14, r0, r6, r7, r8, r9

        add.w r0, r0, #1
        cmp.w r0, #16
        bne.w 1b

    bitslice r6, r7, r8, r9, r2, r3, r4, r5
	vmov.w r0, s0
    str.w r6, [r0]
    str.w r7, [r0, #4]
    str.w r8, [r0, #8]
    str.w r9, [r0, #12]
	add.w sp, sp, #16*16+32 //16*M + N
	pop.w {r4-r11, pc}

	skip_inner3:
		add.w trimat, trimat, #16 // M
		subs.w ctr2, ctr2, #1
		bne.w inner3
		b cont_inner3
	skip_outer3:
		add.w trimat, trimat,  ctr1, lsl#4 // log_2(M)
		subs.w ctr1, ctr1, #1
		bne.w outer3
		b cont_outer3

.global batch_quad_trimat_eval_gf16_36_16_leaktime_asm
.type batch_quad_trimat_eval_gf16_36_16_leaktime_asm, %function
.align 2
batch_quad_trimat_eval_gf16_36_16_leaktime_asm:
	push.w {r4-r11, r14}
	ctr1   .req r0
	trimat .req r1
	ctr2   .req r2
	xi	   .req r3

	xj       .req r5
	lutgf    .req r0
	mat0     .req r6
	mat1     .req r7
	mat2     .req r8
	mat3     .req r9
	buf0     .req r10
	buf1     .req r11
	buf2     .req r12
	buf3     .req r14
	tmp    	 .req sp
	xptr     .req r4
    // N=36, M=16
	sub.w sp, sp, #16*16+36 //16*M + N
	add.w xptr, sp, #16*16  //16*M
	vmov.w s0, r0
	vmov.w s2, r3

	// init tmp to zero
	mov.w r0, #0
	.set i, 0
	.rept 30 // 16*M / 8
		strd.w r0, r0, [sp, #16+i*8] // skip the first M bytes
		.set i, i+1
	.endr

	// set _x
	.set i, 0
	.rept 4 // N / 8
	ldr.w r0, [r2, #i*4]
	and.w r3, r0, #0xF
	and.w r5, r0, #0xF0
	add.w r3, r3, r5, lsl#4
	and.w r5, r0, #0xF00
	add.w r3, r3, r5, lsl#8
	and.w r5, r0, #0xF000
	add.w r3, r3, r5, lsl#12
	str.w r3, [xptr, #i*8]
	ubfx.w r3, r0, #16, #4
	and.w r5, r0, #0xF00000
	add.w r3, r3, r5, lsr#12
	and.w r5, r0, #0xF000000
	add.w r3, r3, r5, lsr#8
	and.w r5, r0, #0xF0000000
	add.w r3, r3, r5, lsr#4
	str.w r3, [xptr, #i*8+4]
	.set i, i+1
	.endr
    ldrh.w r0, [r2, #16]
	and.w r3, r0, #0xF
	and.w r5, r0, #0xF0
	add.w r3, r3, r5, lsl#4
	and.w r5, r0, #0xF00
	add.w r3, r3, r5, lsl#8
	and.w r5, r0, #0xF000
	add.w r3, r3, r5, lsl#12
	str.w r3, [xptr, #32]
	// setting _x done;

	mov.w ctr1, #36 // N
	vmov.w s1, xptr
	outer4: // for(int i=0;i<dim;i++)
		vmov.w xptr, s1
		ldrb.w xi, [xptr], #1
		vmov.w s1, xptr

		// if 0, do nothing
		cmp.w xi, #0
		beq.w skip_outer4

		mov.w ctr2, ctr1
		vmov.w s3, ctr1
		vmov.w lutgf, s2
		sub.w xptr, xptr, #1
		inner4: // for(int j=i; j<dim; j++)
			ldrb.w xj, [xptr], #1
			// if 0, do nothing
			cmp.w xj, #0
			beq.w skip_inner4
			orr.w xj, xi, xj, lsl#4
			ldrb.w xj, [lutgf, xj]

			// compute address of buffer
			add.w xj, sp, xj, lsl#4 // log_2(M)

			ldr.w buf0, [xj, #0]
			ldr.w buf1, [xj, #4]
			ldr.w buf2, [xj, #8]
			ldr.w buf3, [xj, #12]
			ldr.w mat1, [trimat, #4]
			ldr.w mat2, [trimat, #8]
			ldr.w mat3, [trimat, #12]
			ldr.w mat0, [trimat], #16
			eor.w buf0, buf0, mat0
			str.w buf0, [xj, #0]
			eor.w buf1, buf1, mat1
			str.w buf1, [xj, #4]
			eor.w buf2, buf2, mat2
			str.w buf2, [xj, #8]
			eor.w buf3, buf3, mat3
			str.w buf3, [xj, #12]

			subs.w ctr2, ctr2, #1
			bne.w inner4
			cont_inner4:

		vmov.w ctr1, s3
		subs.w ctr1, ctr1, #1
		bne.w outer4
	cont_outer4:
	// do the actual multiplication
	add.w r1, sp, #16 // M
    ldr.w r7, [r1, #4]
    ldr.w r8, [r1, #8]
    ldr.w r9, [r1, #12]
    ldr.w r6, [r1], #16 // M
    bitslice r2, r3, r4, r5, r6, r7, r8, r9
    mov.w r0, #2
    1:
        ldr.w r7, [r1, #4]
        ldr.w r8, [r1, #8]
        ldr.w r9, [r1, #12]
        ldr.w r6, [r1], #16 // M

        bitslice r10, r11, r12, r14, r6, r7, r8, r9
        madd_bitsliced r2, r3, r4, r5, r10, r11, r12, r14, r0, r6, r7, r8, r9

        add.w r0, r0, #1
        cmp.w r0, #16
        bne.w 1b

    bitslice r6, r7, r8, r9, r2, r3, r4, r5
	vmov.w r0, s0
    str.w r6, [r0]
    str.w r7, [r0, #4]
    str.w r8, [r0, #8]
    str.w r9, [r0, #12]
	add.w sp, sp, #16*16+36 //16*M + N
	pop.w {r4-r11, pc}

	skip_inner4:
		add.w trimat, trimat, #16 // M
		subs.w ctr2, ctr2, #1
		bne.w inner4
		b cont_inner4
	skip_outer4:
		add.w trimat, trimat,  ctr1, lsl#4 // log_2(M)
		subs.w ctr1, ctr1, #1
		bne.w outer4
		b cont_outer4
