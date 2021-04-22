#ifndef HAL_SHA2_H
#define HAL_SHA2_H

#include <stdint.h>
#include <stddef.h>

void hal_sha256(uint8_t *out, const uint8_t *in, size_t inlen);


#endif