#!/bin/sh

# test with precomputation
make clean
PRECOMPUTE_BITSLICING=1 ./testvectors.py rainbowI-classic rainbowI-circumzenithal

# test without precomputation
make clean
PRECOMPUTE_BITSLICING=0 ./testvectors.py rainbowI-classic rainbowI-circumzenithal rainbowI-compressed
