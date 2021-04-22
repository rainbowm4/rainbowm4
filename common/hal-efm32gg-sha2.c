#include "hal-sha2.h"
#include "em_crypto.h"

#ifdef PROFILE_HASHING
#include "hal.h"
extern unsigned long long hash_cycles;
#endif

void hal_sha256(uint8_t *out, const uint8_t *in, size_t inlen)
{
    #ifdef PROFILE_HASHING
    uint64_t t0 = hal_get_time();
    #endif
    CRYPTO_SHA_256(CRYPTO0, in, inlen, out);
    #ifdef PROFILE_HASHING
    uint64_t t1 = hal_get_time();
    hash_cycles += (t1-t0);
    #endif
}