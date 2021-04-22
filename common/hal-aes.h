#ifndef HAL_AES_H
#define HAL_AES_H

#include <stdint.h>
#include <stddef.h>

void hal_aes128_ecb(uint8_t *out, const uint8_t *in, size_t nblocks, const uint8_t *key);
void hal_aes256_ecb(uint8_t *out, const uint8_t *in, size_t nblocks, const uint8_t *key);


void hal_aes128_ctr(uint8_t *out, size_t outlen, const uint8_t *iv, const uint8_t *key);
void hal_aes256_ctr(uint8_t *out, size_t outlen, const uint8_t *iv, const uint8_t *key);

#endif