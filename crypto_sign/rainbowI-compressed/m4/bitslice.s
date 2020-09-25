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

//extern void gf16v_bitslice_asm(uint32_t *out, size_t len);
.global gf16v_bitslice_asm
.type gf16v_bitslice_asm, %function
.align 2
gf16v_bitslice_asm:
    push.w {r4-r7, r14}
    1:
        ldr.w r2, [r0, #0]
        ldr.w r3, [r0, #4]
        ldr.w r4, [r0, #8]
        ldr.w r5, [r0, #12]

        bitslice r6, r7, r12, r14, r2, r3, r4, r5

        str.w r7,  [r0, #4]
        str.w r12, [r0, #8]
        str.w r14, [r0, #12]
        str.w r6, [r0], #16
    subs r1, r1, #1
    bne 1b
    pop.w {r4-r7, pc}

