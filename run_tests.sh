#!/bin/sh

# test w/ precomp
make clean
PRECOMPUTE_BITSLICING=1 ./test.py rainbowI-classic rainbowI-circumzenithal

# test w/o precomp
make clean
PRECOMPUTE_BITSLICING=0 ./test.py rainbowI-classic rainbowI-circumzenithal rainbowI-compressed

