/// @file gf16.h
/// @brief Library for arithmetics in GF(16) and GF(256)
///

#ifndef _GF16_H_
#define _GF16_H_

#include <stdint.h>


static inline uint8_t gf16_is_nonzero(uint8_t a) {
    unsigned a4 = a & 0xf;
    unsigned r = ((unsigned) 0) - a4;
    r >>= 4;
    return r & 1;
}

// gf16 := gf2[x]/x^4+x+1
static inline uint8_t gf16_mul(uint8_t a, uint8_t b)
{
    uint8_t b0 = (-(b & 1)) >> 31;
    uint8_t b1 = (-(b & 2)) >> 31;
    uint8_t b2 = (-(b & 4)) >> 31;
    uint8_t b3 = (-(b & 8)) >> 31;
    uint8_t r = 0;
    r ^= a & b0;
    r ^= (a & b1) << 1;
    r ^= (a & b2) << 2;
    r ^= (a & b3) << 3;
    return (r & 0x0F) ^ ((r & 0xF0) >> 4) ^ ((r & 0x70) >> 3);
}


static inline uint8_t gf16_squ(uint8_t a)
{
    uint8_t a0 = ((a >> 0) & 1) ^ ((a >> 2) & 1);
    uint8_t a1 = ((a >> 2) & 1);
    uint8_t a2 = ((a >> 1) & 1) ^ ((a >> 3) & 1);
    uint8_t a3 = ((a >> 3) & 1);
    return a0 ^ (a1 << 1) ^ (a2 << 2) ^ (a3 << 3);
}

static inline uint8_t gf16_inv(uint8_t a) {
    uint8_t a2 = gf16_squ(a);
    uint8_t a4 = gf16_squ(a2);
    uint8_t a8 = gf16_squ(a4);
    uint8_t a6 = gf16_mul(a4, a2);
    return gf16_mul(a8, a6);
}

static inline uint32_t gf16v_mul_u32(uint32_t a, uint8_t b) {
    uint32_t b0 = (-(b & 1)) >> 31;
    uint32_t b1 = (-(b & 2)) >> 31;
    uint32_t b2 = (-(b & 4)) >> 31;
    uint32_t b3 = (-(b & 8)) >> 31;
    uint32_t r = 0;

    r ^= a & b0;

    r ^= (a & b1 & 0x77777777)<<1;
    r ^= (a & b1 & 0x88888888)>>2;
    r ^= (a & b1 & 0x88888888)>>3;

    r ^= (a & b2 & 0x33333333)<<2;
    r ^= (a & b2 & 0xCCCCCCCC)>>1;
    r ^= (a & b2 & 0xCCCCCCCC)>>2;

    r ^= (a & b3 & 0x11111111)<<3;
    r ^= (a & b3 & 0xEEEEEEEE)>>0;
    r ^= (a & b3 & 0xEEEEEEEE)>>1;
    return r;
}


#endif // _GF16_H_

