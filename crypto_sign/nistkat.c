#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "hal.h"
#include "api.h"
#include "randombytes.h"
#include "aes.h"

// https://stackoverflow.com/a/1489985/1711232
#define PASTER(x, y) x####y
#define EVALUATOR(x, y) PASTER(x, y)
#define NAMESPACE(fun) EVALUATOR(MUPQ_NAMESPACE, fun)

// use different names so we can have empty namespaces
#define MUPQ_CRYPTO_PUBLICKEYBYTES NAMESPACE(CRYPTO_PUBLICKEYBYTES)
#define MUPQ_CRYPTO_SECRETKEYBYTES NAMESPACE(CRYPTO_SECRETKEYBYTES)
#define MUPQ_CRYPTO_BYTES          NAMESPACE(CRYPTO_BYTES)
#define MUPQ_CRYPTO_ALGNAME        NAMESPACE(CRYPTO_ALGNAME)

#define MUPQ_crypto_sign_keypair NAMESPACE(crypto_sign_keypair)
#define MUPQ_crypto_sign NAMESPACE(crypto_sign)
#define MUPQ_crypto_sign_open NAMESPACE(crypto_sign_open)
#define MUPQ_crypto_sign_signature NAMESPACE(crypto_sign_signature)
#define MUPQ_crypto_sign_verify NAMESPACE(crypto_sign_verify)


typedef struct {
    uint8_t Key[32];
    uint8_t V[16];
    int reseed_counter;
} AES256_CTR_DRBG_struct;

static AES256_CTR_DRBG_struct DRBG_ctx;
static void AES256_CTR_DRBG_Update(const uint8_t *provided_data, uint8_t *Key, uint8_t *V);

// Use whatever AES implementation you have. This uses AES from openSSL library
//    key - 256-bit AES key
//    ctr - a 128-bit plaintext value
//    buffer - a 128-bit ciphertext value
static void AES256_ECB(uint8_t *key, uint8_t *ctr, uint8_t *buffer) {
    aes256ctx ctx;
    aes256_ecb_keyexp(&ctx, key);
    aes256_ecb(buffer, ctr, 1, &ctx);
    aes256_ctx_release(&ctx);
}

static void nist_kat_init(uint8_t *entropy_input, const uint8_t *personalization_string, int security_strength) {
    uint8_t seed_material[48];

    assert(security_strength == 256);
    memcpy(seed_material, entropy_input, 48);
    if (personalization_string) {
        for (int i = 0; i < 48; i++) {
            seed_material[i] ^= personalization_string[i];
        }
    }
    memset(DRBG_ctx.Key, 0x00, 32);
    memset(DRBG_ctx.V, 0x00, 16);
    AES256_CTR_DRBG_Update(seed_material, DRBG_ctx.Key, DRBG_ctx.V);
    DRBG_ctx.reseed_counter = 1;
}

int randombytes(uint8_t *buf, size_t n) {
    uint8_t block[16];
    int i = 0;

    while (n > 0) {
        //increment V
        for (int j = 15; j >= 0; j--) {
            if (DRBG_ctx.V[j] == 0xff) {
                DRBG_ctx.V[j] = 0x00;
            } else {
                DRBG_ctx.V[j]++;
                break;
            }
        }
        AES256_ECB(DRBG_ctx.Key, DRBG_ctx.V, block);
        if (n > 15) {
            memcpy(buf + i, block, 16);
            i += 16;
            n -= 16;
        } else {
            memcpy(buf + i, block, n);
            n = 0;
        }
    }
    AES256_CTR_DRBG_Update(NULL, DRBG_ctx.Key, DRBG_ctx.V);
    DRBG_ctx.reseed_counter++;
    return 0;
}

static void AES256_CTR_DRBG_Update(const uint8_t *provided_data, uint8_t *Key, uint8_t *V) {
    uint8_t temp[48];

    for (int i = 0; i < 3; i++) {
        //increment V
        for (int j = 15; j >= 0; j--) {
            if (V[j] == 0xff) {
                V[j] = 0x00;
            } else {
                V[j]++;
                break;
            }
        }

        AES256_ECB(Key, V, temp + 16 * i);
    }
    if (provided_data != NULL) {
        for (int i = 0; i < 48; i++) {
            temp[i] ^= provided_data[i];
        }
    }
    memcpy(Key, temp, 32);
    memcpy(V, temp + 32, 16);
}



static void printBstr(const char *S, const uint8_t *A, size_t L) {
    hal_send_str_nonewline(S);
    if (L == 0) {
        hal_send_str("00");
    } else {
        hal_send_bytes(A, L);
    }
}

int main(void) {
    hal_setup(CLOCK_FAST);
    hal_send_str("+++++++++++++++++++++++++");
    char str[100];
    uint8_t entropy_input[48];
    uint8_t seed[48];
    uint8_t public_key[MUPQ_CRYPTO_PUBLICKEYBYTES];
    uint8_t secret_key[MUPQ_CRYPTO_SECRETKEYBYTES];
    size_t mlen = 33;
    size_t smlen, mlen1;
    uint8_t m[33];
    uint8_t sm[33 + MUPQ_CRYPTO_BYTES];
    int rc;

    for (uint8_t i = 0; i < 48; i++) {
        entropy_input[i] = i;
    }

    nist_kat_init(entropy_input, NULL, 256);

    hal_send_str("count = 0");
    randombytes(seed, 48);
    printBstr("seed = ", seed, 48);

    hal_send_str("mlen = 33");

    randombytes(m, mlen);
    printBstr("msg = ", m, mlen);

    nist_kat_init(seed, NULL, 256);

    rc = MUPQ_crypto_sign_keypair(public_key, secret_key);
    if (rc != 0) {
        sprintf(str, "[kat_kem] %s ERROR: crypto_kem_keypair failed!\n", CRYPTO_ALGNAME);
        hal_send_str(str);
    }
    printBstr("pk = ", public_key, CRYPTO_PUBLICKEYBYTES);
    printBstr("sk = ", secret_key, CRYPTO_SECRETKEYBYTES);


    #if PRECOMPUTE_BITSLICING == 1
    bitslice_sk(secret_key);
    #endif

    rc = MUPQ_crypto_sign(sm, &smlen, m, mlen, secret_key);
    if (rc != 0) {
        sprintf(str, "[kat_kem] %s ERROR: crypto_sign failed!\n", CRYPTO_ALGNAME);
        hal_send_str(str);
    }
    sprintf(str, "smlen = %zu", smlen);
    hal_send_str(str);
    printBstr("sm = ", sm, smlen);

    rc = MUPQ_crypto_sign_open(sm, &mlen1, sm, smlen, public_key);
    if (rc != 0) {
        sprintf(str, "[kat_kem] %s ERROR: crypto_sign_open failed!\n", CRYPTO_ALGNAME);
        hal_send_str(str);
    }

    if ( mlen != mlen1 ) {
        sprintf(str, "crypto_sign_open returned bad 'mlen': got <%zu>, expected <%zu>\n", mlen1, mlen);
        hal_send_str(str);
    }
    if (memcmp(m, sm, mlen)) {
        sprintf(str, "crypto_sign_open returned bad 'm' value\n");
        hal_send_str(str);
    }
    hal_send_str("#");
    while(1);
    return 0;
}
