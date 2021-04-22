// It is heavily based on Silicon Labs' em_crypto.c

/***************************************************************************//**
 * @file
 * @brief Cryptography accelerator peripheral API
 * @version 5.8.0
 *******************************************************************************
 * # License
 * <b>Copyright 2018 Silicon Laboratories Inc. www.silabs.com</b>
 *******************************************************************************
 *
 * SPDX-License-Identifier: Zlib
 *
 * The licensor of this software is Silicon Laboratories Inc.
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 ******************************************************************************/

#include "hal-aes.h"
#include "em_crypto.h"

#include <string.h>

#define AESCTR_NONCEBYTES 12
#define AES_BLOCKBYTES 16
#define CRYPTO_AES_BLOCKSIZE 16


#ifdef PROFILE_HASHING
#include "hal.h"
extern unsigned long long hash_cycles;
#endif


static inline void CRYPTO_DataReadUnaligned(volatile uint32_t * reg,
                                              uint8_t * val)
{
  /* Check data is 32bit aligned, if not, read into temporary buffer and
     then move to user buffer. */
  if ((uintptr_t)val & 0x3) {
    uint32_t temp[4];
    CRYPTO_DataRead(reg, temp);
    memcpy(val, temp, 16);
  } else {
    CRYPTO_DataRead(reg, (uint32_t *)val);
  }
}
static inline void CRYPTO_DataWriteUnaligned(volatile uint32_t * reg,
                                               const uint8_t * val)
{
  /* Check data is 32bit aligned, if not move to temporary buffer before
     writing.*/
  if ((uintptr_t)val & 0x3) {
    uint32_t temp[4];
    memcpy(temp, val, 16);
    CRYPTO_DataWrite(reg, temp);
  } else {
    CRYPTO_DataWrite(reg, (const uint32_t *)val);
  }
}

static inline void CRYPTO_KeyBufWriteUnaligned(CRYPTO_TypeDef          *crypto,
                                 const uint8_t *          val,
                                 CRYPTO_KeyWidth_TypeDef  keyWidth)
{
  /* Check if key val buffer is 32bit aligned, if not move to temporary
     aligned buffer before writing.*/
  if ((uintptr_t)val & 0x3) {
    CRYPTO_KeyBuf_TypeDef temp;
    if (keyWidth == cryptoKey128Bits) {
      memcpy(temp, val, 16);
    } else {
      memcpy(temp, val, 32);
    }
    CRYPTO_KeyBufWrite(crypto, temp, keyWidth);
  } else {
    CRYPTO_KeyBufWrite(crypto, (uint32_t*)val, keyWidth);
  }
}

static inline void CRYPTO_AES_ProcessLoop(CRYPTO_TypeDef *        crypto,
                                            unsigned int            len,
                                            CRYPTO_DataReg_TypeDef  inReg,
                                            const uint8_t  *        in,
                                            CRYPTO_DataReg_TypeDef  outReg,
                                            uint8_t *               out)
{
  len /= CRYPTO_AES_BLOCKSIZE;
  crypto->SEQCTRL = 16UL << _CRYPTO_SEQCTRL_LENGTHA_SHIFT;

  if (((uintptr_t)in & 0x3) || ((uintptr_t)out & 0x3)) {
    while (len > 0UL) {
      len--;
      /* Load data and trigger encryption. */
      CRYPTO_DataWriteUnaligned(inReg, in);
      CRYPTO_InstructionSequenceExecute(crypto);

      /* Wait for the sequence to finish. */
      CRYPTO_InstructionSequenceWait(crypto);
      /* Save encrypted/decrypted data. */
      CRYPTO_DataReadUnaligned(outReg, out);

      out += 16;
      in  += 16;
    }
  } else {
    /* Optimized version, 15% faster for -O3. */
    if (len > 0UL) {
      /* Load first data and trigger encryption. */
      CRYPTO_DataWrite(inReg, (uint32_t *)in);
      CRYPTO_InstructionSequenceExecute(crypto);

      /* Do loop administration while CRYPTO engine is working. */
      in += 16;
      len--;

      while (len > 0UL) {
        /* Wait for the sequence to finish. */
        CRYPTO_InstructionSequenceWait(crypto);
        /* Save encrypted/decrypted data. */
        CRYPTO_DataRead(outReg, (uint32_t *)out);

        /* Load next data and retrigger encryption asap. */
        CRYPTO_DataWrite(inReg, (uint32_t *)in);
        CRYPTO_InstructionSequenceExecute(crypto);

        /* Do loop administration while CRYPTO engine is working. */
        out += 16;
        in += 16;
        len--;
      }

      /* Wait for the sequence to finish. */
      CRYPTO_InstructionSequenceWait(crypto);
      /* Save last encrypted/decrypted data. */
      CRYPTO_DataRead(outReg, (uint32_t *)out);
    }
  }
}


static void aesX_ctr(uint8_t *out, size_t outlen, const uint8_t *iv)
{
    CRYPTO_SEQ_LOAD_3(CRYPTO0,
                    CRYPTO_CMD_INSTR_DATA1TODATA0,
                    CRYPTO_CMD_INSTR_AESENC,
                    CRYPTO_CMD_INSTR_DATA1INC);


    size_t len = outlen;
    len /= CRYPTO_AES_BLOCKSIZE;
    CRYPTO0->SEQCTRL = 16UL << _CRYPTO_SEQCTRL_LENGTHA_SHIFT;
    CRYPTO0->CTRL |= CRYPTO_CTRL_INCWIDTH_INCWIDTH4;


    if((uintptr_t)iv & 0x3){
        CRYPTO_DataWriteUnaligned(&CRYPTO0->DATA1, iv);
    } else {
        CRYPTO_DataWrite(&CRYPTO0->DATA1, (uint32_t *)iv);
    }

    if ( ((uintptr_t)out & 0x3) || 1) {
        while (len > 0UL) {
            len--;
            /* trigger encryption. */
            CRYPTO_InstructionSequenceExecute(CRYPTO0);

            /* Wait for the sequence to finish. */
            CRYPTO_InstructionSequenceWait(CRYPTO0);
            /* Save encrypted/decrypted data. */
            CRYPTO_DataReadUnaligned(&CRYPTO0->DATA0, out);

            out += 16;
        }
    }  else {
        if (len > 0UL) {
            /* trigger encryption. */
            CRYPTO_InstructionSequenceExecute(CRYPTO0);

            /* Do loop administration while CRYPTO engine is working. */
            len--;

            while (len > 0UL) {
                /* Wait for the sequence to finish. */
                CRYPTO_InstructionSequenceWait(CRYPTO0);
                /* Save encrypted/decrypted data. */
                CRYPTO_DataRead(&CRYPTO0->DATA0, (uint32_t *)out);

                /* trigger encryption asap. */
                CRYPTO_InstructionSequenceExecute(CRYPTO0);

                /* Do loop administration while CRYPTO engine is working. */
                out += 16;
                len--;
            }
            /* Wait for the sequence to finish. */
            CRYPTO_InstructionSequenceWait(CRYPTO0);
            /* Save last encrypted/decrypted data. */
            CRYPTO_DataRead(&CRYPTO0->DATA0, (uint32_t *)out);
            out += 16;
        }
    }

    if(outlen % 16 != 0){
        uint32_t tmp[4];
        /* trigger encryption. */
        CRYPTO_InstructionSequenceExecute(CRYPTO0);
        /* Wait for the sequence to finish. */
        CRYPTO_InstructionSequenceWait(CRYPTO0);
        /* Save last encrypted/decrypted data. */
        CRYPTO_DataRead(&CRYPTO0->DATA0, tmp);

        memcpy(out, tmp, outlen % 16);
    }


}

void hal_aes128_ecb(uint8_t *out, const uint8_t *in, size_t nblocks, const uint8_t *key)
{
    #ifdef PROFILE_HASHING
    uint64_t t0 = hal_get_time();
    #endif

    CRYPTO0->CTRL = CRYPTO_CTRL_AES_AES128;
    CRYPTO0->WAC = 0;

    CRYPTO_KeyBufWriteUnaligned(CRYPTO0, key, cryptoKey128Bits);

    CRYPTO_SEQ_LOAD_1(CRYPTO0, CRYPTO_CMD_INSTR_AESENC);

    CRYPTO_AES_ProcessLoop(CRYPTO0, AES_BLOCKBYTES*nblocks,
                         &CRYPTO0->DATA0, in,
                         &CRYPTO0->DATA0, out);
    #ifdef PROFILE_HASHING
    uint64_t t1 = hal_get_time();
    hash_cycles += (t1-t0);
    #endif
}


void hal_aes256_ecb(uint8_t *out, const uint8_t *in, size_t nblocks, const uint8_t *key)
{
    #ifdef PROFILE_HASHING
    uint64_t t0 = hal_get_time();
    #endif
    CRYPTO0->CTRL = CRYPTO_CTRL_AES_AES256;
    CRYPTO0->WAC = 0;

    CRYPTO_KeyBufWriteUnaligned(CRYPTO0, key, cryptoKey256Bits);
    CRYPTO_SEQ_LOAD_1(CRYPTO0, CRYPTO_CMD_INSTR_AESENC);

    CRYPTO_AES_ProcessLoop(CRYPTO0, AES_BLOCKBYTES*nblocks,
                         &CRYPTO0->DATA0, in,
                         &CRYPTO0->DATA0, out);

    #ifdef PROFILE_HASHING
    uint64_t t1 = hal_get_time();
    hash_cycles += (t1-t0);
    #endif
}


void hal_aes128_ctr(uint8_t *out, size_t outlen, const uint8_t *iv, const uint8_t *key)
{
    #ifdef PROFILE_HASHING
    uint64_t t0 = hal_get_time();
    #endif
    CRYPTO0->CTRL = CRYPTO_CTRL_AES_AES128;
    CRYPTO0->WAC = 0;

    CRYPTO_KeyBufWriteUnaligned(CRYPTO0, key, cryptoKey128Bits);
    aesX_ctr(out, outlen, iv);

    #ifdef PROFILE_HASHING
    uint64_t t1 = hal_get_time();
    hash_cycles += (t1-t0);
    #endif
}


void hal_aes256_ctr(uint8_t *out, size_t outlen, const uint8_t *iv, const uint8_t *key)
{
    #ifdef PROFILE_HASHING
    uint64_t t0 = hal_get_time();
    #endif
    CRYPTO0->CTRL = CRYPTO_CTRL_AES_AES256;
    CRYPTO0->WAC = 0;

    CRYPTO_KeyBufWriteUnaligned(CRYPTO0, key, cryptoKey256Bits);
    aesX_ctr(out, outlen, iv);

    #ifdef PROFILE_HASHING
    uint64_t t1 = hal_get_time();
    hash_cycles += (t1-t0);
    #endif
}
