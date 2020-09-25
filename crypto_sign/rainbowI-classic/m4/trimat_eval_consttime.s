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


//batch_quad_trimat_eval_gf16_32_16_asm(uint32_t y[4], uint32_t *trimat, uint8_t *_x)
// trimat gets bitsliced on the fly
// y is bitsliced until the very end and then gets unbitsliced
.global batch_quad_trimat_eval_gf16_32_16_asm
.type batch_quad_trimat_eval_gf16_32_16_asm, %function
.align 2
batch_quad_trimat_eval_gf16_32_16_asm:
    push.w {r4-r11, r14}


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2


    sub.w sp, #48
    # initialize y with 0
    mov.w r12, #0
    str.w r12, [sp, #32]
    str.w r12, [sp, #36]
    str.w r12, [sp, #40]
    str.w r12, [sp, #44]

    # re-organize x
    .set j, 0
    .rept 4
    ldr.w r3, [r2, #4*j]
    and.w r4, r3, #0xF0F0F0F0
    lsr.w r4, r4, #4
    and.w r3, r3, #0x0F0F0F0F

    .set i, 0
    .rept 4
    strb.w r3, [sp, #2*i+8*j]
    strb.w r4, [sp, #2*i+8*j+1]
    lsr.w r3, r3, #8
    lsr.w r4, r4, #8
    .set i, i+1
    .endr
    .set j, j+1
    .endr

    mov.w r2, sp



    vmov.w one, #0.5
    vmov.w ctr1, #16

    vmov.w s3, r0
    2:
    vmov.w s4, r2
    mov.w r4, #0
    mov.w r5, #0
    mov.w r6, #0
    mov.w r7, #0
    vmov.f32 ctr2, ctr1
    1:
        ldr.w r9,  [r1, #4]
        ldr.w r10, [r1, #8]
        ldr.w r11, [r1, #12]
        ldr.w r8,  [r1], #16
        ldrb.w r0, [r2], #1

        vmov s5, r2
        bitslice r12, r14, r3, r2, r8, r9, r10, r11
        madd_bitsliced r4, r5, r6, r7, r12, r14, r3, r2, r0, r8, r9, r10, r11
        vmov r2, s5

        vsub.f32 ctr2, ctr2, one
        vcmp.f32 ctr2, #0.0
        vmrs apsr_nzcv, FPSCR
        bhi.w 1b

    vmov r2, s4
    ldr.w r8,  [sp, #32]
    ldr.w r9,  [sp, #36]
    ldr.w r10, [sp, #40]
    ldr.w r11, [sp, #44]
    ldrb.w r3, [r2], #1
    vmov s5, r2
    madd_bitsliced r8, r9, r10, r11, r4, r5, r6, r7, r3, r0, r2, r12, r14
    vmov r2, s5

    str.w r8,  [sp, #32]
    str.w r9,  [sp, #36]
    str.w r10, [sp, #40]
    str.w r11, [sp, #44]
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    vmov r0, s3
    # un-bitslice
    bitslice r1, r2, r3, r4, r8, r9, r10, r11
    str.w r1, [r0]
    str.w r2, [r0,#4]
    str.w r3, [r0,#8]
    str.w r4, [r0,#12]

    add.w sp, #48
    pop.w {r4-r11, pc}


//batch_quad_trimat_eval_gf16_32_16_bitsliced_normal_asm(uint32_t y[4], uint32_t *trimat, uint8_t *_x)
// trimat gets bitsliced on the fly
// y is bitsliced until the very end and then gets unbitsliced
.global batch_quad_trimat_eval_gf16_32_16_bitsliced_normal_asm
.type batch_quad_trimat_eval_gf16_32_16_bitsliced_normal_asm, %function
.align 2
batch_quad_trimat_eval_gf16_32_16_bitsliced_normal_asm:
    push.w {r4-r11, r14}


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2


    sub.w sp, #48
    # initialize y with 0
    mov.w r12, #0
    str.w r12, [sp, #32]
    str.w r12, [sp, #36]
    str.w r12, [sp, #40]
    str.w r12, [sp, #44]

    # re-organize x
    .set j, 0
    .rept 4
    ldr.w r3, [r2, #4*j]
    and.w r4, r3, #0xF0F0F0F0
    lsr.w r4, r4, #4
    and.w r3, r3, #0x0F0F0F0F

    .set i, 0
    .rept 4
    strb.w r3, [sp, #2*i+8*j]
    strb.w r4, [sp, #2*i+8*j+1]
    lsr.w r3, r3, #8
    lsr.w r4, r4, #8
    .set i, i+1
    .endr
    .set j, j+1
    .endr

    mov.w r2, sp



    vmov.w one, #0.5
    vmov.w ctr1, #16

    vmov.w s3, r0
    2:
    vmov.w s4, r2
    mov.w r4, #0
    mov.w r5, #0
    mov.w r6, #0
    mov.w r7, #0
    vmov.f32 ctr2, ctr1
    1:
        ldr.w r9,  [r1, #4]
        ldr.w r10, [r1, #8]
        ldr.w r11, [r1, #12]
        ldr.w r8,  [r1], #16
        ldrb.w r0, [r2], #1

        vmov s5, r2
        // already bitsliced
        //bitslice r12, r14, r3, r2, r8, r9, r10, r11
        madd_bitsliced r4, r5, r6, r7, r8, r9, r10, r11, r0,r12, r14, r3, r2
        vmov r2, s5

        vsub.f32 ctr2, ctr2, one
        vcmp.f32 ctr2, #0.0
        vmrs apsr_nzcv, FPSCR
        bhi.w 1b

    vmov r2, s4
    ldr.w r8,  [sp, #32]
    ldr.w r9,  [sp, #36]
    ldr.w r10, [sp, #40]
    ldr.w r11, [sp, #44]
    ldrb.w r3, [r2], #1
    vmov s5, r2
    madd_bitsliced r8, r9, r10, r11, r4, r5, r6, r7, r3, r0, r2, r12, r14
    vmov r2, s5

    str.w r8,  [sp, #32]
    str.w r9,  [sp, #36]
    str.w r10, [sp, #40]
    str.w r11, [sp, #44]
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    vmov r0, s3
    # un-bitslice
    bitslice r1, r2, r3, r4, r8, r9, r10, r11
    str.w r1, [r0]
    str.w r2, [r0,#4]
    str.w r3, [r0,#8]
    str.w r4, [r0,#12]

    add.w sp, #48
    pop.w {r4-r11, pc}

//batch_quad_trimat_eval_gf16_36_16_asm(uint32_t y[4], uint32_t *trimat, uint8_t *_x)
// trimat gets bitsliced on the fly
// y is bitsliced until the very end and then gets unbitsliced
.global batch_quad_trimat_eval_gf16_36_16_asm
.type batch_quad_trimat_eval_gf16_36_16_asm, %function
.align 2
batch_quad_trimat_eval_gf16_36_16_asm:
    push.w {r4-r11, r14}


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    sub.w sp, #52
    # initialize y with 0
    mov.w r12, #0
    str.w r12, [sp, #36]
    str.w r12, [sp, #40]
    str.w r12, [sp, #44]
    str.w r12, [sp, #48]

    # re-organize x
    .set j, 0
    .rept 4
    ldr.w r3, [r2, #4*j]
    and.w r4, r3, #0xF0F0F0F0
    lsr.w r4, r4, #4
    and.w r3, r3, #0x0F0F0F0F

    .set i, 0
    .rept 4
    strb.w r3, [sp, #2*i+8*j]
    strb.w r4, [sp, #2*i+8*j+1]
    lsr.w r3, r3, #8
    lsr.w r4, r4, #8
    .set i, i+1
    .endr
    .set j, j+1
    .endr

    ldrh.w r3, [r2, #16]
    and.w r4, r3, #0xF0F0F0F0
    lsr.w r4, r4, #4
    and.w r3, r3, #0x0F0F0F0F
    .set i, 0
    .rept 2
    strb.w r3, [sp, #32+i*2]
    strb.w r4, [sp, #32+i*2+1]
    lsr.w r3, r3, #8
    lsr.w r4, r4, #8
    .set i, i+1
    .endr


    mov.w r2, sp

    vmov.w one, #0.5
    vmov.w ctr1, #18

    vmov.w s3, r0
    2:
    vmov.w s4, r2
    mov.w r4, #0
    mov.w r5, #0
    mov.w r6, #0
    mov.w r7, #0
    vmov.f32 ctr2, ctr1
    1:
        ldr.w r9,  [r1, #4]
        ldr.w r10, [r1, #8]
        ldr.w r11, [r1, #12]
        ldr.w r8,  [r1], #16
        ldrb.w r0, [r2], #1

        vmov s5, r2
        bitslice r12, r14, r3, r2, r8, r9, r10, r11
        madd_bitsliced r4, r5, r6, r7, r12, r14, r3, r2, r0, r8, r9, r10, r11
        vmov r2, s5

        vsub.f32 ctr2, ctr2, one
        vcmp.f32 ctr2, #0.0
        vmrs apsr_nzcv, FPSCR
        bhi.w 1b

    vmov r2, s4
    ldr.w r8,  [sp, #36]
    ldr.w r9,  [sp, #40]
    ldr.w r10, [sp, #44]
    ldr.w r11, [sp, #48]
    ldrb.w r3, [r2], #1
    vmov s5, r2
    madd_bitsliced r8, r9, r10, r11, r4, r5, r6, r7, r3, r0, r2, r12, r14
    vmov r2, s5

    str.w r8,  [sp, #36]
    str.w r9,  [sp, #40]
    str.w r10, [sp, #44]
    str.w r11, [sp, #48]
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    vmov r0, s3
    # un-bitslice
    bitslice r1, r2, r3, r4, r8, r9, r10, r11
    str.w r1, [r0]
    str.w r2, [r0,#4]
    str.w r3, [r0,#8]
    str.w r4, [r0,#12]

    add.w sp, #52
    pop.w {r4-r11, pc}



//batch_quad_trimat_eval_gf16_36_16_bitsliced_normal_asm(uint32_t y[4], uint32_t *trimat, uint8_t *_x)
// trimat is already bitsliced
// y is bitsliced until the very end and then gets unbitsliced
.global batch_quad_trimat_eval_gf16_36_16_bitsliced_normal_asm
.type batch_quad_trimat_eval_gf16_36_16_bitsliced_normal_asm, %function
.align 2
batch_quad_trimat_eval_gf16_36_16_bitsliced_normal_asm:
    push.w {r4-r11, r14}


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    sub.w sp, #52
    # initialize y with 0
    mov.w r12, #0
    str.w r12, [sp, #36]
    str.w r12, [sp, #40]
    str.w r12, [sp, #44]
    str.w r12, [sp, #48]

    # re-organize x
    .set j, 0
    .rept 4
    ldr.w r3, [r2, #4*j]
    and.w r4, r3, #0xF0F0F0F0
    lsr.w r4, r4, #4
    and.w r3, r3, #0x0F0F0F0F

    .set i, 0
    .rept 4
    strb.w r3, [sp, #2*i+8*j]
    strb.w r4, [sp, #2*i+8*j+1]
    lsr.w r3, r3, #8
    lsr.w r4, r4, #8
    .set i, i+1
    .endr
    .set j, j+1
    .endr

    ldrh.w r3, [r2, #16]
    and.w r4, r3, #0xF0F0F0F0
    lsr.w r4, r4, #4
    and.w r3, r3, #0x0F0F0F0F
    .set i, 0
    .rept 2
    strb.w r3, [sp, #32+i*2]
    strb.w r4, [sp, #32+i*2+1]
    lsr.w r3, r3, #8
    lsr.w r4, r4, #8
    .set i, i+1
    .endr


    mov.w r2, sp

    vmov.w one, #0.5
    vmov.w ctr1, #18

    vmov.w s3, r0
    2:
    vmov.w s4, r2
    mov.w r4, #0
    mov.w r5, #0
    mov.w r6, #0
    mov.w r7, #0
    vmov.f32 ctr2, ctr1
    1:
        ldr.w r9,  [r1, #4]
        ldr.w r10, [r1, #8]
        ldr.w r11, [r1, #12]
        ldr.w r8,  [r1], #16
        ldrb.w r0, [r2], #1

        vmov s5, r2
        //bitslice r12, r14, r3, r2, r8, r9, r10, r11

        madd_bitsliced r4, r5, r6, r7, r8, r9, r10, r11, r0, r12, r14, r3, r2
        vmov r2, s5

        vsub.f32 ctr2, ctr2, one
        vcmp.f32 ctr2, #0.0
        vmrs apsr_nzcv, FPSCR
        bhi.w 1b

    vmov r2, s4
    ldr.w r8,  [sp, #36]
    ldr.w r9,  [sp, #40]
    ldr.w r10, [sp, #44]
    ldr.w r11, [sp, #48]
    ldrb.w r3, [r2], #1
    vmov s5, r2
    madd_bitsliced r8, r9, r10, r11, r4, r5, r6, r7, r3, r0, r2, r12, r14
    vmov r2, s5

    str.w r8,  [sp, #36]
    str.w r9,  [sp, #40]
    str.w r10, [sp, #44]
    str.w r11, [sp, #48]
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    vmov r0, s3
    # un-bitslice
    bitslice r1, r2, r3, r4, r8, r9, r10, r11
    str.w r1, [r0]
    str.w r2, [r0,#4]
    str.w r3, [r0,#8]
    str.w r4, [r0,#12]

    add.w sp, #52
    pop.w {r4-r11, pc}


