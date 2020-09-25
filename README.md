# RainbowM4
This repository contains the official ARM Cortex-M4 implementation of the [NISTPQC](https://csrc.nist.gov/Projects/post-quantum-cryptography/round-3-submissions) signature finalist Rainbow. For details of the scheme please visit the [Rainbow website](https://www.pqcrainbow.org/). 

Submitters: 
- Ming-shing Chen
- Jintai Ding
- [Matthias J. Kannwischer](https://kannwischer.eu)
- Jacques Patarin
- Albrecht Petzoldt
- [Dieter Schmidt](https://homepages.uc.edu/~schmiddr/)
- [Bo-Yin Yang](https://www.iis.sinica.edu.tw/pages/byyang/)

We target the [EFM32GG11 Giant Gecko Starter Kit](https://www.silabs.com/development-tools/mcu/32-bit/efm32gg11-starter-kit) which has a [EFM32GG11B820F2048GL192](https://www.silabs.com/mcu/32-bit/efm32-giant-gecko-gg11/device.efm32gg11b820f2048gl192) Cortex-M4 core.
It has 
- 515 KiB RAM
- 2 MiB Flash
- runs at at most 72 MHz

## Results 

Our current implementation has the following performance on the Giant Gecko @ 16 MHz (averaged over 1000 executions).
Onc can speed-up signing for Rainbow-Classic and Rainbow-Circumzenithal by precomputing the bitsliced secret key. For Rainbow-Compressed that is not possible. 

| scheme           |             | key gen  | sign    | verify |
| ---------------  | ----------- | -------- | ------- | ------ |
| I-Classic        | w/o precomp.| 151 590k | 945k    | 236k   |
| I-Classic        | w/ precomp. | 151 590k | 767k    | 237k   |
| I-Circumzenithal | w/o precomp.| 166 969k | 940k    | 6 670k |
| I-Circumzenithal | w/ precomp. | 166 969k | 764k    | 6 671k |
| I-Compressed     | w/o precomp.| 167 035k | 77 812k | 6 671k |
| I-Compressed     | w/ precomp. | --       | --      | --     |

## Setup 

## Connecting the board

## Building Binaries 

## Running Tests

## Comparing Testvectors

## Running Benchmarks 
