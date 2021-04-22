#ifndef API_H
#define API_H

#include <stddef.h>
#include <stdint.h>
#include "rainbow_config.h"
#include "rainbow_keypair.h"


#if defined _RAINBOW_CLASSIC

#define CRYPTO_SECRETKEYBYTES sizeof(sk_t)
#define CRYPTO_PUBLICKEYBYTES sizeof(pk_t)

#elif defined _RAINBOW_CYCLIC

#define CRYPTO_SECRETKEYBYTES sizeof(sk_t)
#define CRYPTO_PUBLICKEYBYTES sizeof(cpk_t)

#elif defined _RAINBOW_CYCLIC_COMPRESSED

#define CRYPTO_SECRETKEYBYTES sizeof(csk_t)
#define CRYPTO_PUBLICKEYBYTES sizeof(cpk_t)

#else
error here
#endif

#define CRYPTO_BYTES _SIGNATURE_BYTE
#define CRYPTO_ALGNAME "RAINBOW(16,36,32,32) - cyclic"

int crypto_sign_keypair(uint8_t *pk, uint8_t *sk);


int crypto_sign_signature(
    uint8_t *sig, size_t *siglen,
    const uint8_t *m, size_t mlen, const uint8_t *sk);

int crypto_sign_verify(
    const uint8_t *sig, size_t siglen,
    const uint8_t *m, size_t mlen, const uint8_t *pk);

int crypto_sign(uint8_t *sm, size_t *smlen,
        const uint8_t *m, size_t mlen,
        const uint8_t *sk);

int crypto_sign_open(uint8_t *m, size_t *mlen,
        const uint8_t *sm, size_t smlen,
        const uint8_t *pk);


#endif
