#!/bin/sh

make clean
PRECOMPUTE_BITSLICING=0 ./build_everything.py rainbowI-classic rainbowI-circumzenithal rainbowI-compressed

make clean
PRECOMPUTE_BITSLICING=1 ./build_everything.py rainbowI-classic rainbowI-circumzenithal