.syntax unified
.cpu cortex-m4
.thumb

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


.macro recmat_inner xiyi, lutgf, recmat, tmp0, tmp1, tmp2, tmp3
    ldrb.w \xiyi, [\lutgf, \xiyi]
    add.w \xiyi, sp, \xiyi, lsl#4 // log_2(M)
    ldr.w \tmp0, [\xiyi, #0]
    ldr.w \tmp1, [\xiyi, #4]
    ldr.w \tmp3, [\recmat, #4]
    ldr.w \tmp2, [\recmat], #8
    eor.w \tmp0, \tmp0, \tmp2
	str.w \tmp0, [\xiyi, #0]
	eor.w \tmp1, \tmp1, \tmp3
	str.w \tmp1, [\xiyi, #4]

    ldr.w \tmp0, [\xiyi, #8]
    ldr.w \tmp1, [\xiyi, #12]
    ldr.w \tmp3, [\recmat, #4]
    ldr.w \tmp2, [\recmat], #8

    eor.w \tmp0, \tmp0, \tmp2
	str.w \tmp0, [\xiyi, #8]
	eor.w \tmp1, \tmp1, \tmp3
	str.w \tmp1, [\xiyi, #12]
.endm


.global batch_quad_recmat_eval_gf16_32_32_16_leaktime_asm
.type batch_quad_recmat_eval_gf16_32_32_16_leaktime_asm, %function
.align 2
batch_quad_recmat_eval_gf16_32_32_16_leaktime_asm:
	push.w {r4-r11, r14}

    recmat .req r1
    x_ptr  .req r3
    y_ptr  .req r2
    lutgf  .req r4

    ctr1 .req r5
    ctr2 .req r5
    ctr3 .req r6

    x_elements .req r7
    y_elements .req r8

    buf0       .req r9
    buf1       .req r10
    buf2       .req r11
    buf3       .req r12


    xiyi       .req r0
    yi         .req r14

    x_ptr_fpu  .req s2
    y_ptr_fpu  .req s3
    ctr1_fpu   .req s4
    ldr.w lutgf, [sp, #9*4]

    vmov.w s0, r0 // store result pointer
    vmov.w x_ptr_fpu, x_ptr // store x_ptr
    vmov.w y_ptr_fpu, y_ptr // store y_ptr

    // allocate tmp
    sub.w sp, sp, #16*16

    // init tmp to zero
	mov.w r0, #0
	.set i, 0
	.rept 30
		strd.w r0, r0, [sp, #16+i*8]
		.set i, i+1
	.endr

    mov.w ctr1, #32/8
    1:
        vmov.w ctr1_fpu, ctr1
        ldr.w y_elements, [y_ptr], #4
        mov.w ctr2, #8
        2:
            ands.w yi, y_elements, #0xF
            beq.w skip_outer32

            mov.w ctr3, #32/8
            vmov.w x_ptr, x_ptr_fpu
            3:
                ldr.w x_elements, [x_ptr], #4
                .set ii, 0
                .rept 8
                    ubfx.w xiyi, x_elements, #ii*4, #4

                    orr.w xiyi, yi, xiyi, lsl#4
                    recmat_inner xiyi, lutgf, recmat, buf0, buf1, buf2, buf3
                    .set ii, ii+1
                .endr
                subs.w ctr3, ctr3, #1
                bne 3b
            cont_outer32:
            lsr.w y_elements, y_elements, #4
            subs.w ctr2, ctr2, #1
            bne 2b

        vmov.w ctr1, ctr1_fpu
        subs.w ctr1, ctr1, #1
        bne.w 1b

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
	add.w sp, sp, #16*16 //16*M
	pop.w {r4-r11, pc}

    skip_outer32:
        add.w recmat, recmat, #32*16
        b cont_outer32


.global batch_quad_recmat_eval_gf16_36_32_16_leaktime_asm
.type batch_quad_recmat_eval_gf16_36_32_16_leaktime_asm, %function
.align 2
batch_quad_recmat_eval_gf16_36_32_16_leaktime_asm:
	push.w {r4-r11, r14}

    recmat .req r1
    x_ptr  .req r3
    y_ptr  .req r2
    lutgf  .req r4

    ctr1 .req r5
    ctr2 .req r5
    ctr3 .req r6

    x_elements .req r7
    y_elements .req r8

    buf0       .req r9
    buf1       .req r10
    buf2       .req r11
    buf3       .req r12


    xiyi       .req r0
    yi         .req r14

    x_ptr_fpu  .req s2
    y_ptr_fpu  .req s3
    ctr1_fpu   .req s4
    ldr.w lutgf, [sp, #9*4]

    vmov.w s0, r0 // store result pointer
    vmov.w x_ptr_fpu, x_ptr // store x_ptr
    vmov.w y_ptr_fpu, y_ptr // store y_ptr

    // allocate tmp
    sub.w sp, sp, #16*16

    // init tmp to zero
	mov.w r0, #0
	.set i, 0
	.rept 30
		strd.w r0, r0, [sp, #16+i*8]
		.set i, i+1
	.endr

    // first 32 elements of y
    mov.w ctr1, #32/8
    1:
        vmov.w ctr1_fpu, ctr1
        ldr.w y_elements, [y_ptr], #4
        mov.w ctr2, #8
        2:
            ands.w yi, y_elements, #0xF
            beq.w skip_outer36

            mov.w ctr3, #32/8
            vmov.w x_ptr, x_ptr_fpu
            3:
                ldr.w x_elements, [x_ptr], #4
                .set ii, 0
                .rept 8
                    ubfx.w xiyi, x_elements, #ii*4, #4

                    orr.w xiyi, yi, xiyi, lsl#4
                    recmat_inner xiyi, lutgf, recmat, buf0, buf1, buf2, buf3
                    .set ii, ii+1
                .endr
                subs.w ctr3, ctr3, #1
                bne 3b
            cont_outer36:
            lsr.w y_elements, y_elements, #4
            subs.w ctr2, ctr2, #1
            bne 2b

        vmov.w ctr1, ctr1_fpu
        subs.w ctr1, ctr1, #1
        bne.w 1b

    // last 4 elements of y

    ldrh.w y_elements, [y_ptr]
    mov.w ctr2, #4
    2:
        ands.w yi, y_elements, #0xF
        beq.w skip_outer36_2

        mov.w ctr3, #32/8
        vmov.w x_ptr, x_ptr_fpu
        3:
            ldr.w x_elements, [x_ptr], #4
            .set ii, 0
            .rept 8
                ubfx.w xiyi, x_elements, #ii*4, #4
                orr.w xiyi, yi, xiyi, lsl#4
                recmat_inner xiyi, lutgf, recmat, buf0, buf1, buf2, buf3
                .set ii, ii+1
            .endr
            subs.w ctr3, ctr3, #1
            bne 3b
        cont_outer36_2:
        lsr.w y_elements, y_elements, #4
        subs.w ctr2, ctr2, #1
        bne 2b

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
	add.w sp, sp, #16*16 //16*M
	pop.w {r4-r11, pc}

    skip_outer36:
        add.w recmat, recmat, #32*16
        b cont_outer36

    skip_outer36_2:
        add.w recmat, recmat, #32*16
        b cont_outer36_2
