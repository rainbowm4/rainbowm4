This repository contains the official ARM Cortex-M4 implementation of the [NISTPQC](https://csrc.nist.gov/Projects/post-quantum-cryptography/round-3-submissions) [signature finalist Rainbow](https://www.pqcrainbow.org/). For details of the scheme please visit the [Rainbow website](https://www.pqcrainbow.org/). 

We are working on a paper that describes the details of this implementation, and will provide a reference here once it is available. 

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

# Contents
1. [Results](#results)
2. [Setup](#setup)
    1. [Connecting the board](#connecting-the-board)
    2. [Flashing](#flashing)
3. [Running it](#running-it)
    1. [Building Binaries](#building-binaries)
    2. [Running Tests](#running-tests)
    3. [Comparing Testvectors](#comparing-testvectors)
    4. [Comparing NIST KATs](#comparing-nist-kats)
    5. [Running Benchmarks](#running-benchmarks)

# Results 

Our current implementation has the following performance on the Giant Gecko @ 16 MHz (averaged over 1000 executions).

| scheme           |             | key gen  | sign    | verify |
| ---------------  | ----------- | -------- | ------- | ------ |
| I-Classic        | w/o precomp.| 151 590k | 945k    | 236k   |
| I-Classic        | w/ precomp. | 151 590k | 767k    | 237k   |
| I-Circumzenithal | w/o precomp.| 166 969k | 940k    | 6 670k |
| I-Circumzenithal | w/ precomp. | 166 969k | 764k    | 6 671k |
| I-Compressed     | w/o precomp.| 167 035k | 77 812k | 6 671k |
| I-Compressed     | w/ precomp. | --       | --      | --     |

One can speed-up signing for Rainbow-Classic and Rainbow-Circumzenithal by precomputing the bitsliced secret key. For Rainbow-Compressed that is not possible. 


# Setup 
Firstly, recursively clone this repo: 
```
git clone  --recurse-submodules https://github.com/rainbowm4/rainbowm4
```

This code is based upon [pqm4](https://github.com/mupq/pqm4) and [EFM32-getting-started](https://github.com/mkannwischer/EFM32-getting-started). 
You may want to follow the more complete setup description of [EFM32-getting-started](https://github.com/mkannwischer/EFM32-getting-started). 

As usual you will need the [arm-none-eabi toolchain](https://launchpad.net/gcc-arm-embedded) toolchain installed.
For flashing binaries onto the board, you will need to install the [J-Link Software and Documentation Pack](https://www.segger.com/downloads/jlink/). After installing, make sure that `JLinkExe` is in your `PATH`.

For using the scripts you will need [Python](https://www.python.org/download) and [pyserial](https://pypi.org/project/pyserial/).

If you are on Arch Linux, you can simply run the following and should be done:

```
yay -S arm-none-eabi-gcc jlink-software-and-documentation python-pyserial
```

On Ubuntu, you can install [pyserial](https://pypi.org/project/pyserial/) and [arm-none-eabi toolchain](https://launchpad.net/gcc-arm-embedded) using:

```
sudo apt install gcc-arm-none-eabi python3-serial
```
You will have to have to install the [J-Link .deb](https://www.segger.com/downloads/jlink/) manually.


## Connecting the board

Connect the board to your host machine using the mini-USB port (upper left corner of the board).
This provides it with power, and allows you to flash binaries onto the board.

It should show up in `lsusb` as `SEGGER J-Link OB`. 
If you are using a UART-USB connector that has a PL2303 chip on board (which appears to be the most common),
the driver should be loaded in your kernel by default. If it is not, it is typically called `pl2303`.
On macOS, you will still need to [install it](http://www.prolific.com.tw/US/ShowProduct.aspx?p_id=229&pcid=41) (and reboot).
When you plug in the device, it should show up as `Prolific Technology, Inc. PL2303 Serial Port` when you type `lsusb`.

Using dupont / jumper cables, connect the `RX`/`RXD` pin of the USB connector to the `PE8` pin (Pin 12 on the expansion header).
Depending on your setup, you may also want to connect the `GND` pin .

For the full pin-outs of the Giant Gecko's see Section 4 in the [User Guide](https://www.silabs.com/documents/public/user-guides/ug287-stk3701.pdf).

## Flashing

The Giant Gecko comes with a [Segger J-Link debugger](https://www.segger.com/products/debug-probes/j-link/) that we use to flash binaries on the board.
You can simply run

```
./flash.sh <BINARY>
``` 
e.g., 
```
./flash.sh bin/crypto_sign_rainbowI-classic_m4_test.bin
``` 
to program the binary onto the board.
For details see [flash.sh](flash.sh) and [flash.jlink](flash.jlink).


# Running it 

We implement the three level 1 parameter sets of rainbow: `rainbowI-classic`, `rainbowI-circumzenithal`, and `rainbowI-compressed`. 
Unfortunately, the keys of the level 3 and level 5 parameter sets do not fit in the 512 KiB RAM of the Giant Gecko. 

We implement two variants: With and without precomputation of the bitsliced secret key. It can be turned on with the flag `PRECOMPUTE_BITSLICING=1`. 
It only affects the performance of signing of `rainbowI-classic` and `rainbowI-circumzenithal`. 

## Building Binaries c
As a first test if your toolchain is correctly setup run the following two commans and check that you see binaries appearing in `bin/`

```
PRECOMPUTE_BITSLICING=0 python3 build_everything.py
PRECOMPUTE_BITSLICING=1 python3 build_everything.py
```
## Running Tests
You can test the schemes by running
```
PRECOMPUTE_BITSLICING=<0/1> python3 test.py <schemes> 
```
e.g., 
```
PRECOMPUTE_BITSLICING=0 ./test.py rainbowI-classic rainbowI-circumzenithal rainbowI-compressed
```

Alternatively, you can also run `./run_tests.sh` to test all the parameter sets with and without precomputation.

## Comparing Testvectors

One can cross check the implementations, by first running the reference implementation on the host and verifying that the output is the same as the one produced by our implementation. Simply run 
```
PRECOMPUTE_BITSLICING=<0/1> python3 testvectors.py <schemes> 
```
e.g., 
```
PRECOMPUTE_BITSLICING=0 ./testvectors.py rainbowI-classic rainbowI-circumzenithal rainbowI-compressed
```

Alternatively, you can also run `./run_testvectors.sh` to test all the parameter sets with and without precomputation.

## Comparing NIST KATs

The SHA3-256 hashes of first testvector of the KATs submitted to NIST are

| scheme           | SHA3-256                                                         | 
| ---------------  | ---------------------------------------------------------------- | 
| I-Classic        | FF67670FFF15986BE86C54A34B1165A13F56D58E466130E32AB506CC4CEC74F5 |
| I-Circumzenithal | 49A37441B239466E8032FFF7688C8FE5D7FDABEF80007F7E043E18DE8C6AD4D6 |
| I-Compressed     | FFF9A0286EBA8433A8240B86BBD255856FD50927AA35F8E15EF5003134CC231F |

Run `./run_nistkat.sh` to check that the M4 implementation produces the same testvectors. 


## Running Benchmarks 
To benchmark the schemes use the scripts provided, e.g., 
```
python3 benchmark.py <scheme> <precompute> <iterations>
```
e.g., 
```
python3 benchmark.py rainbowI-classic 1 100
```
The `iterations` argument allows to specify how often signing and verification will be run. Due to the vast differences in run-time, it makes sense to average those over many iterations. 

You may also use the provided scripts 
```
./run_benchmark_classic.sh
./run_benchmark_classic_precomp.sh
./run_benchmark_circumzenithal.sh
./run_benchmark_circumzenithal_precomp.sh
./run_benchmark_compressed.sh
```
