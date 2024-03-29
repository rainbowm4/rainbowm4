#include "api.h"
#include "hal.h"
#include "sendfn.h"
#include "randombytes.h"

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define MLEN 59

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

#define printcycles(S, U) send_unsignedll((S), (U))

int main(void)
{
  unsigned char pk[MUPQ_CRYPTO_PUBLICKEYBYTES] __attribute__ ((aligned (8)));
  unsigned char sk[MUPQ_CRYPTO_SECRETKEYBYTES];
  unsigned char sm[MLEN+MUPQ_CRYPTO_BYTES];
  unsigned char m[MLEN];
  size_t smlen;
  size_t mlen;
  unsigned long long t0, t1;

  hal_setup(CLOCK_BENCHMARK);

  hal_send_str("==========================");

  // Key-pair generation
  t0 = hal_get_time();
  MUPQ_crypto_sign_keypair(pk, sk);
  #if PRECOMPUTE_BITSLICING == 1
  bitslice_sk(sk);
  #endif

  t1 = hal_get_time();
  printcycles("keypair cycles:", t1-t0);


  for(int i = 0; i < CRYPTO_ITERATIONS; i++){
    randombytes(sm, MLEN);

    // Signing
    t0 = hal_get_time();
    MUPQ_crypto_sign(sm, &smlen, sm, MLEN, sk);
    t1 = hal_get_time();
    printcycles("sign cycles:", t1-t0);

    // Verification
    t0 = hal_get_time();
    int rc = MUPQ_crypto_sign_open(m, &mlen, sm, smlen, pk);
    t1 = hal_get_time();
    printcycles("verify cycles:", t1-t0);

    if(rc){
      hal_send_str("ERROR");
    }

    hal_send_str("#");
  }




  while(1);
  return 0;
}
