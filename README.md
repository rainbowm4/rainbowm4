This repository contains the official ARM Cortex-M4 implementation of the [NISTPQC](https://csrc.nist.gov/Projects/post-quantum-cryptography/round-3-submissions) [signature finalist Rainbow](https://www.pqcrainbow.org/). For details of the scheme please visit the [Rainbow website](https://www.pqcrainbow.org/). 

The implementation is described in more detail in [this paper](https://kannwischer.eu/papers/2021_rainbowm4.pdf). 

Authors of this M4 implementations: 
- [Tung Chou](https://tungchou.github.io/)
- [Matthias J. Kannwischer](https://kannwischer.eu)
- [Bo-Yin Yang](https://www.iis.sinica.edu.tw/pages/byyang/)

Rainbow Submitters: 
- Ming-Shing Chen
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
    1. [Parameter Sets](#parameter-sets)
    2. [Implementations](#implementations)
    3. [Programs](#programs)
    4. [Hardware crypto](#hardware-crypto)
    5. [Precomputation](#precomputation)
    6. [Automated tests and benchmarks](#automated-tests-and-benchmarks)
    7. [List of Binaries](#list-of-binaries)

# Results 

See Table 2 of the paper. 

# Setup 
Firstly, recursively clone this repo: 
```
git clone  --recurse-submodules https://github.com/rainbowm4/rainbowm4
```

In case you got the code from the official code package submitted to NIST, you need to initialie the `efm32-base` submodule by 
```
git init                                                                        
git submodule add https://github.com/ryankurte/efm32-base                          
cd efm32-base                                                                      
git checkout ac1c323d77782fd8f39940bcf5fd857a9a8327a8                              
cd .. 
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
## Parameter Sets
We implement the three level 1 parameter sets `rainbowI-classic`, `rainbowI-circumzenithal`, `rainbowI-compressed`.

In addition, we include implementations using the alternative direct representation F_16 = F_2[X]/(X^4+X+1).
These are called `rainbowI-classic-tweaked`, `rainbowI-circumzenithal-tweaked`, `rainbowI-compressed-tweaked`.

You can select the parameter set in the binary name and implementation path, e.g., for `rainbowI-classic` run

```
make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
```

## Implementations

This code package includes our new `m4` implementation, but also the reference implementation `ref` from the Rainbow submission package. 
You can select the implementation in the binary name and the path, e.g., for the reference implementation, run

```
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_test.bin
```

## Programs
We have different programs for different purposes:
- [`test.c`](./crypto_sign/test.c): Tests if signatures verify correctly.
- [`speed.c`](./crypto_sign/speed.c): Benchmarks the scheme at a low frequency (16 MHz) and outputs cycle counts.
- [`testvectors.c`](./crypto_sign/testvectors.c): Generates deterministic testvectors which can be used to cross check different implementations.
- [`nistkat.c`](./crypto_sign/nistkat.c): Uses the same deterministic RNG that was provided by NIST which allows to compare to NISTKATs.
- [`stack.c`](./crypto_sign/stack.c): Measures the stack consumption of the implementations.
- [`hashing.c`](./crypto_sign/hashing.c): Profiles how much of the run time is spent in hashing operations.

When building, those can be selected in the binary name, e.g., for test, run
```
make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
```

## Hardware crypto

The Giant Gecko has hardware support for AES and SHA256. We have included a variant of our implementation that uses
the hardware accelerator.
You can enable/disable it by setting the `USE_HARDWARE_CRYPTO` flag, e.g.,

```
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
```

By default, it is disabled (0).

## Precomputation

Rainbow signing (for classic and circumzenithal) can be speed-up by pre-computing the bitslicing of the secret key.
The pre-computation can be enabled by using the `PRECOMPUTE_BITSLICING` flag, e.g.,
```
PRECOMPUTE_BITSLICING=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
```

By default, it is disabled (0).


## Automated tests and benchmarks 
The above options can all be combined.
To verify that all implementations produce the same testvestors as the reference implementations, you can run 
```
./nistkat.py
```

For running benchmarks, we provide scripts as well
```
# speed benchmarks
./run_all_benchmarks.py
# hashing benchmarks
./run_all_hashing_bench.py
# stack benchmarks
./run_all_stack.py
# code size benchmarks
./run_codesize.py
```



## List of binaries
Below is a exhaustive list of the commands building the useful binaries.

```
# original parameter sets
# test
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_test.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_test.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_test.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_test.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_test.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_test.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_test.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_test.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_test.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_test.bin

# speed
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_speed.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_speed.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_speed.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_speed.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_speed.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_speed.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_speed.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_speed.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_speed.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_speed.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_speed.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_speed.bin


# testvectors
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_testvectors.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_testvectors.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_testvectors.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_testvectors.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_testvectors.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_testvectors.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_testvectors.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_testvectors.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_testvectors.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_testvectors.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_testvectors.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_testvectors.bin

# nistkat
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_nistkat.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_nistkat.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_nistkat.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_nistkat.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_nistkat.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_nistkat.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_nistkat.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_nistkat.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_nistkat.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_nistkat.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_nistkat.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_nistkat.bin

# stack
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_stack.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_stack.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_stack.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_stack.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_stack.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_stack.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_stack.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_stack.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_stack.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_stack.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_stack.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_stack.bin

# hashing
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_hashing.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_hashing.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_hashing.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/ref bin/crypto_sign_rainbowI-classic_ref_hashing.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/ref bin/crypto_sign_rainbowI-circumzenithal_ref_hashing.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/ref bin/crypto_sign_rainbowI-compressed_ref_hashing.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_hashing.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed/m4 bin/crypto_sign_rainbowI-compressed_m4_hashing.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_hashing.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_hashing.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_hashing.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal/m4 bin/crypto_sign_rainbowI-circumzenithal_m4_hashing.bin

# tweaked parameter sets (direct F_16 presentation)
# test
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_test.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_test.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_test.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_test.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_test.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_test.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_test.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_test.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_test.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_test.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_test.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_test.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_test.bin

# speed
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_speed.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_speed.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_speed.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_speed.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_speed.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_speed.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_speed.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_speed.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_speed.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_speed.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_speed.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_speed.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_speed.bin


# testvectors
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_testvectors.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_testvectors.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_testvectors.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_testvectors.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_testvectors.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_testvectors.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_testvectors.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_testvectors.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_testvectors.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_testvectors.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_testvectors.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_testvectors.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_testvectors.bin

# nistkat
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_nistkat.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_nistkat.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_nistkat.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_nistkat.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_nistkat.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_nistkat.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_nistkat.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_nistkat.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_nistkat.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_nistkat.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_nistkat.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_nistkat.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_nistkat.bin

# stack
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_stack.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_stack.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_stack.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_stack.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_stack.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_stack.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_stack.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_stack.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_stack.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_stack.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_stack.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_stack.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_stack.bin

# hashing
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_hashing.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_hashing.bin
USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_hashing.bin

USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/ref bin/crypto_sign_rainbowI-classic-tweaked_ref_hashing.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/ref bin/crypto_sign_rainbowI-circumzenithal-tweaked_ref_hashing.bin
USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/ref bin/crypto_sign_rainbowI-compressed-tweaked_ref_hashing.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_hashing.bin

PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_hashing.bin
PRECOMPUTE_BITSLICING=0 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-compressed-tweaked/m4 bin/crypto_sign_rainbowI-compressed-tweaked_m4_hashing.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_hashing.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=0 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_hashing.bin

PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic-tweaked/m4 bin/crypto_sign_rainbowI-classic-tweaked_m4_hashing.bin
PRECOMPUTE_BITSLICING=1 USE_HARDWARE_CRYPTO=1 make IMPLEMENTATION_PATH=crypto_sign/rainbowI-circumzenithal-tweaked/m4 bin/crypto_sign_rainbowI-circumzenithal-tweaked_m4_hashing.bin
```
