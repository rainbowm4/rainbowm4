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

.macro bitslice_single out0, out1, out2, out3, in0
    and.w \out0, \in0, #0x11111111
    and.w \out1, \in0, #0x22222222
    lsr.w \out1, \out1, #1
    and.w \out2, \in0, #0x44444444
    lsr.w \out2, \out2, #2
    and.w \out3, \in0, #0x88888888
    lsr.w \out3, \out3, #3
.endm


.macro unbitslice_single out0, in0, in1, in2, in3
    and.w \out0, \in0, #0x11111111
    orr.w \out0, \out0, \in1, lsl#1
    orr.w \out0, \out0, \in2, lsl#2
    orr.w \out0, \out0, \in3, lsl#3
.endm


//extern void gf16mat_prod_16_32_ontheflybitsliced_asm(uint32_t *c, uint32_t *a, uint32_t *b);
.global gf16mat_prod_16_32_ontheflybitsliced_asm
.type gf16mat_prod_16_32_ontheflybitsliced_asm, %function
.align 2
gf16mat_prod_16_32_ontheflybitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14

    one      .req s0
    ctr1     .req s1

    push.w {c_ptr}
    push.w {b_ptr}
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov one, #0.5
    vmov ctr1, #2
    1:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w tmp1, [a_ptr, #4]
            ldr.w tmp2, [a_ptr, #8]
            ldr.w tmp3, [a_ptr, #12]
            ldr.w tmp0, [a_ptr], #16
            // bitslice on the fly
            bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3
    str.w tmp0, [c_ptr]
    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]


    pop.w {r4-r11, pc}

// Input: bitsliced; Output: normal
//void gf16mat_prod_16_32_bitsliced_normal_asm(uint8_t *c, const uint8_t *matA, const uint8_t *b);
.global gf16mat_prod_16_32_bitsliced_normal_asm
.type gf16mat_prod_16_32_bitsliced_normal_asm, %function
.align 2
gf16mat_prod_16_32_bitsliced_normal_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14

    one      .req s0
    ctr1     .req s1

    push.w {c_ptr}
    push.w {b_ptr}
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov one, #0.5
    vmov ctr1, #2
    1:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w mat1, [a_ptr, #4]
            ldr.w mat2, [a_ptr, #8]
            ldr.w mat3, [a_ptr, #12]
            ldr.w mat0, [a_ptr], #16
            // input is already bitsliced
            //bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3
    str.w tmp0, [c_ptr]
    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]


    pop.w {r4-r11, pc}


//extern void gf16mat_prod_16_32_ontheflybitsliced_asm(uint32_t *c, uint32_t *a, uint32_t *b);
.global gf16mat_prod_18_32_ontheflybitsliced_asm
.type gf16mat_prod_18_32_ontheflybitsliced_asm, %function
.align 2
gf16mat_prod_18_32_ontheflybitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14

    one      .req s0
    ctr1     .req s1

    push.w {c_ptr}
    push.w {b_ptr}
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov one, #0.5
    vmov ctr1, #2
    1:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w tmp1, [a_ptr, #4]
            ldr.w tmp2, [a_ptr, #8]
            ldr.w tmp3, [a_ptr, #12]
            ldr.w tmp0, [a_ptr], #18
            // bitslice on the fly
            bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3
    str.w tmp0, [c_ptr]
    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]

    sub b_ptr, #16
    sub a_ptr, #8*4*18-16
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #2
    1:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldrh.w tmp0, [a_ptr], #18
            // bitslice on the fly
            bitslice_single mat0, mat1, mat2, mat3, tmp0
            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    pop.w {b_ptr}
    pop.w {c_ptr}
    unbitslice_single tmp0, accu0, accu1, accu2, accu3
    strh.w tmp0, [c_ptr, #16]

    pop.w {r4-r11, pc}

//extern void gf16mat_prod_18_32_bitsliced_normal_asm(uint32_t *c, uint32_t *a, uint32_t *b);
.global gf16mat_prod_18_32_bitsliced_normal_asm
.type gf16mat_prod_18_32_bitsliced_normal_asm, %function
.align 2
gf16mat_prod_18_32_bitsliced_normal_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14

    one      .req s0
    ctr1     .req s1

    push.w {c_ptr}
    push.w {b_ptr}
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov one, #0.5
    vmov ctr1, #2
    1:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w mat1, [a_ptr, #4]
            ldr.w mat2, [a_ptr, #8]
            ldr.w mat3, [a_ptr, #12]
            ldr.w mat0, [a_ptr], #18
            // already bitsliced
            //bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3
    str.w tmp0, [c_ptr]
    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]

    sub b_ptr, #16
    sub a_ptr, #8*4*18-16
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #2
    1:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldrh.w tmp0, [a_ptr], #18
            // bitslice on the fly
            bitslice_single mat0, mat1, mat2, mat3, tmp0
            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    pop.w {b_ptr}
    pop.w {c_ptr}
    unbitslice_single tmp0, accu0, accu1, accu2, accu3
    strh.w tmp0, [c_ptr, #16]

    pop.w {r4-r11, pc}


//extern void gf16mat_prod_512_32_ontheflybitsliced_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_32_ontheflybitsliced_asm
.type gf16mat_prod_512_32_bitsliced_inner_asm, %function
.align 2
gf16mat_prod_512_32_ontheflybitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w tmp0, [a_ptr]
            ldr.w tmp1, [a_ptr, #4]
            ldr.w tmp2, [a_ptr, #8]
            ldr.w tmp3, [a_ptr, #12]
            add a_ptr, #512
            // bitslice on the fly
            bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b


    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]
    str.w tmp0, [c_ptr], #16
    push {c_ptr}
    mov r3, #16368 //(32*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8

    pop.w {r4-r11, pc}

//extern void gf16mat_prod_512_32_bitsliced_normal_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_32_bitsliced_normal_asm
.type gf16mat_prod_512_32_bitsliced_normal_asm, %function
.align 2
gf16mat_prod_512_32_bitsliced_normal_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w mat0, [a_ptr]
            ldr.w mat1, [a_ptr, #4]
            ldr.w mat2, [a_ptr, #8]
            ldr.w mat3, [a_ptr, #12]
            add a_ptr, #512
            // already bitsliced
            // bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b


    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]
    str.w tmp0, [c_ptr], #16
    push {c_ptr}
    mov r3, #16368 //(32*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8

    pop.w {r4-r11, pc}


//extern void gf16mat_prod_512_32_normal_bitsliced_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_32_normal_bitsliced_asm
.type gf16mat_prod_512_32_normal_bitsliced_asm, %function
.align 2
gf16mat_prod_512_32_normal_bitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w tmp0, [a_ptr]
            ldr.w tmp1, [a_ptr, #4]
            ldr.w tmp2, [a_ptr, #8]
            ldr.w tmp3, [a_ptr, #12]
            add a_ptr, #512
            // bitslice on the fly
            bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b


    pop.w {b_ptr}
    pop.w {c_ptr}
    // keep bitsliced
    // un-bitslice on the fly
    //bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w accu1, [c_ptr, #4]
    str.w accu2, [c_ptr, #8]
    str.w accu3, [c_ptr, #12]
    str.w accu0, [c_ptr], #16
    push {c_ptr}
    mov r3, #16368 //(32*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8
    pop.w {r4-r11, pc}




//extern void gf16mat_prod_512_32_bitsliced_bitsliced_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_32_bitsliced_bitsliced_asm
.type gf16mat_prod_512_32_bitsliced_bitsliced_asm, %function
.align 2
gf16mat_prod_512_32_bitsliced_bitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w mat0, [a_ptr]
            ldr.w mat1, [a_ptr, #4]
            ldr.w mat2, [a_ptr, #8]
            ldr.w mat3, [a_ptr, #12]
            add a_ptr, #512
            // already bitsliced
            //bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b


    pop.w {b_ptr}
    pop.w {c_ptr}
    // keep bitsliced
    //bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w accu1, [c_ptr, #4]
    str.w accu2, [c_ptr, #8]
    str.w accu3, [c_ptr, #12]
    str.w accu0, [c_ptr], #16
    push {c_ptr}
    mov r3, #16368 //(32*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8
    pop.w {r4-r11, pc}

//extern void gf16mat_prod_512_36_ontheflybitsliced_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_36_ontheflybitsliced_asm
.type gf16mat_prod_512_36_bitsliced_inner_asm, %function
.align 2
gf16mat_prod_512_36_ontheflybitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w tmp0, [a_ptr]
            ldr.w tmp1, [a_ptr, #4]
            ldr.w tmp2, [a_ptr, #8]
            ldr.w tmp3, [a_ptr, #12]
            add a_ptr, #512
            // bitslice on the fly
            bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    pop.w {b_ptr}
    ldrh.w b_32, [b_ptr]
    push.w {b_ptr}
    .set kk, 0
    .rept 4
        ldr.w tmp0, [a_ptr]
        ldr.w tmp1, [a_ptr, #4]
        ldr.w tmp2, [a_ptr, #8]
        ldr.w tmp3, [a_ptr, #12]

        add a_ptr, #512
        // bitslice on the fly
        bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
        madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
        .if kk != 3
            lsr.w b_32, b_32, #4
        .endif
        .set kk, kk+1
    .endr
    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]
    str.w tmp0, [c_ptr], #16
    push {c_ptr}
    mov r3, #18416 // 36*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8
    pop.w {r4-r11, pc}


//extern void gf16mat_prod_512_36_normal_bitsliced_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_36_normal_bitsliced_asm
.type gf16mat_prod_512_36_normal_bitsliced_asm, %function
.align 2
gf16mat_prod_512_36_normal_bitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w tmp0, [a_ptr]
            ldr.w tmp1, [a_ptr, #4]
            ldr.w tmp2, [a_ptr, #8]
            ldr.w tmp3, [a_ptr, #12]
            add a_ptr, #512
            // bitslice on the fly
            bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    pop.w {b_ptr}
    ldrh.w b_32, [b_ptr]
    push.w {b_ptr}
    .set kk, 0
    .rept 4
        ldr.w tmp0, [a_ptr]
        ldr.w tmp1, [a_ptr, #4]
        ldr.w tmp2, [a_ptr, #8]
        ldr.w tmp3, [a_ptr, #12]
        add a_ptr, #512
        // bitslice on the fly
        bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
        madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
        .if kk != 3
            lsr.w b_32, b_32, #4
        .endif
        .set kk, kk+1
    .endr
    pop.w {b_ptr}
    pop.w {c_ptr}
    // keep bitsliced
    //bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w accu1, [c_ptr, #4]
    str.w accu2, [c_ptr, #8]
    str.w accu3, [c_ptr, #12]
    str.w accu0, [c_ptr], #16
    push {c_ptr}
    mov r3, #18416 // 36*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8
    pop.w {r4-r11, pc}

//extern void gf16mat_prod_512_36_bitsliced_normal_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_36_bitsliced_normal_asm
.type gf16mat_prod_512_36_bitsliced_normal_asm, %function
.align 2
gf16mat_prod_512_36_bitsliced_normal_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w mat0, [a_ptr]
            ldr.w mat1, [a_ptr, #4]
            ldr.w mat2, [a_ptr, #8]
            ldr.w mat3, [a_ptr, #12]
            add a_ptr, #512
            // already bitsliced
            //bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    pop.w {b_ptr}
    ldrh.w b_32, [b_ptr]
    push.w {b_ptr}
    .set kk, 0
    .rept 4
        ldr.w mat0, [a_ptr]
        ldr.w mat1, [a_ptr, #4]
        ldr.w mat2, [a_ptr, #8]
        ldr.w mat3, [a_ptr, #12]
        add a_ptr, #512
        // already bitsliced
        //bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
        madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
        .if kk != 3
            lsr.w b_32, b_32, #4
        .endif
        .set kk, kk+1
    .endr
    pop.w {b_ptr}
    pop.w {c_ptr}
    // un-bitslice on the fly
    bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w tmp1, [c_ptr, #4]
    str.w tmp2, [c_ptr, #8]
    str.w tmp3, [c_ptr, #12]
    str.w tmp0, [c_ptr], #16
    push {c_ptr}
    mov r3, #18416 // 36*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8
    pop.w {r4-r11, pc}

//extern void gf16mat_prod_512_36_bitsliced_bitsliced_asm(uint32_t *c, uint32_t *a, uint8_t *b);
.global gf16mat_prod_512_36_bitsliced_bitsliced_asm
.type gf16mat_prod_512_36_bitsliced_bitsliced_asm, %function
.align 2
gf16mat_prod_512_36_bitsliced_bitsliced_asm:
    push {r4-r11, r14}
    c_ptr .req r0
    a_ptr .req r1
    b_ptr .req r2
    mat0    .req r0
    mat1    .req r2
    mat2    .req r10
    mat3    .req r12
    b_32     .req r5
    tmp0    .req r6
    tmp1    .req r7
    tmp2    .req r8
    tmp3    .req r9
    accu0    .req r3
    accu1    .req r11
    accu2    .req r4
    accu3    .req r14


    one      .req s0
    ctr1     .req s1
    ctr2     .req s2

    push.w {c_ptr}
    push.w {b_ptr}

    vmov one, #0.5
    vmov ctr1, #16
    1:
    mov.w accu0, #0
    mov.w accu1, #0
    mov.w accu2, #0
    mov.w accu3, #0
    vmov ctr2, #2
    2:
        pop.w {b_ptr}
        ldr.w b_32, [b_ptr], #4
        push.w {b_ptr}
        .set kk, 0
        .rept 8
            ldr.w mat0, [a_ptr]
            ldr.w mat1, [a_ptr, #4]
            ldr.w mat2, [a_ptr, #8]
            ldr.w mat3, [a_ptr, #12]
            add a_ptr, #512
            // already bitsliced
            //bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3

            madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
            .if kk != 7
            lsr.w b_32, b_32, #4
            .endif
            .set kk, kk+1
        .endr
    vsub.f32 ctr2, ctr2, one
    vcmp.f32 ctr2, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 2b

    pop.w {b_ptr}
    ldrh.w b_32, [b_ptr]
    push.w {b_ptr}
    .set kk, 0
    .rept 4
        ldr.w mat0, [a_ptr]
        ldr.w mat1, [a_ptr, #4]
        ldr.w mat2, [a_ptr, #8]
        ldr.w mat3, [a_ptr, #12]
        add a_ptr, #512
        // already bitsliced
        //bitslice mat0, mat1, mat2, mat3, tmp0, tmp1, tmp2, tmp3
        madd_bitsliced accu0, accu1, accu2, accu3, mat0, mat1, mat2, mat3, b_32, tmp0, tmp1, tmp2, tmp3
        .if kk != 3
            lsr.w b_32, b_32, #4
        .endif
        .set kk, kk+1
    .endr
    pop.w {b_ptr}
    pop.w {c_ptr}
    // keep bitsliced
    //bitslice tmp0, tmp1, tmp2, tmp3, accu0, accu1, accu2, accu3

    str.w accu1, [c_ptr, #4]
    str.w accu2, [c_ptr, #8]
    str.w accu3, [c_ptr, #12]
    str.w accu0, [c_ptr], #16
    push {c_ptr}
    mov r3, #18416 // 36*512-16)
    sub a_ptr, a_ptr, r3
    sub b_ptr, b_ptr, #16
    push.w {b_ptr}

    vsub.f32 ctr1, ctr1, one
    vcmp.f32 ctr1, #0.0
    vmrs apsr_nzcv, FPSCR
    bhi.w 1b

    add sp, #8
    pop.w {r4-r11, pc}
