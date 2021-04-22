#!/usr/bin/env python3
import os
import subprocess
import sys
import serial
import numpy as np
import datetime

iterations = 1

def run(scheme, precomp_bitslicing, use_hardware_crypto, keygen, sign, verify, aes, sha2):
  os.system("make clean")
  path = f"crypto_sign/{scheme}/m4"
  binary = f"crypto_sign_{scheme}_m4_codesize.elf"
  if precomp_bitslicing:
    precomp_bitslicing = 1
  else:
    precomp_bitslicing = 0

  if use_hardware_crypto:
    use_hardware_crypto = 1
  else:
    use_hardware_crypto = 0

  flags = f"INCLUDE_KEYGEN={keygen} INCLUDE_SIGN={sign} INCLUDE_VERIFY={verify} INCLUDE_AES={aes} INCLUDE_SHA2={sha2}"
  subprocess.check_call(f"make PRECOMPUTE_BITSLICING={precomp_bitslicing} USE_HARDWARE_CRYPTO={use_hardware_crypto} IMPLEMENTATION_PATH={path} CRYPTO_ITERATIONS={iterations} {flags} elf/{binary}", shell=True)


  output = subprocess.check_output(f"arm-none-eabi-size -t elf/{binary}", shell=True, universal_newlines=True)
  sizes = output.splitlines()[-1].split('\t')
  text = sizes[0].strip()
  return int(text)


def parseLog(log, v):
    log = log.decode(errors="ignore")
    lines = str(log).splitlines()
    v = int(lines[1+lines.index(v)])
    return v

def printMacro(name, value):
  value = f"{round(value/1024):,}"
  value = value.replace(",", "\\,")
  return f"\\newcommand{{\\{name}}}{{{value}}}"

def do_it(scheme, texname, precomp_bitslicing, use_hardware_crypto, f):
  print(f"% {scheme}", file=f)
  baseline  = run(scheme, precomp_bitslicing, use_hardware_crypto, keygen=0, sign=0, verify=0, aes=0, sha2=0)
  keygen    = run(scheme, precomp_bitslicing, use_hardware_crypto, keygen=1, sign=0, verify=0, aes=0, sha2=0)
  sign      = run(scheme, precomp_bitslicing, use_hardware_crypto, keygen=0, sign=1, verify=0, aes=0, sha2=0)
  verify    = run(scheme, precomp_bitslicing, use_hardware_crypto, keygen=0, sign=0, verify=1, aes=0, sha2=0)
  all       = run(scheme, precomp_bitslicing, use_hardware_crypto, keygen=1, sign=1, verify=1, aes=0, sha2=0)


  aes      = run(scheme, precomp_bitslicing, use_hardware_crypto, keygen=0, sign=0, verify=0, aes=1, sha2=0)
  sha2      = run(scheme, precomp_bitslicing, use_hardware_crypto, keygen=0, sign=0, verify=0, aes=0, sha2=1)

  print(printMacro(f"{texname}sizebaseline", baseline), file=f)
  print(printMacro(f"{texname}sizekeygen", keygen-baseline), file=f)
  print(printMacro(f"{texname}sizesign", sign-baseline), file=f)
  print(printMacro(f"{texname}sizeverify", verify-baseline), file=f)
  print(printMacro(f"{texname}sizeall", all-baseline), file=f)
  print(printMacro(f"{texname}sizeaes", aes-baseline), file=f)
  print(printMacro(f"{texname}sizesha", sha2-baseline), file=f)
  f.flush()

with open("sizebenchmarks.tex", "a") as f:
  now = datetime.datetime.now()
  print(f"% Benchmarks started at {now} (iterations={iterations})", file=f)

  schemes = {
    "rainbowI-classic" : "rainbowIclassic",
    "rainbowI-classic-tweaked" : "rainbowIclassictweaked",
    "rainbowI-circumzenithal" : "rainbowIcircumzenithal",
    "rainbowI-circumzenithal-tweaked" : "rainbowIcircumzenithaltweaked",
    "rainbowI-compressed" : "rainbowIcompressed",
    "rainbowI-compressed-tweaked" : "rainbowIcompressedtweaked"
  }

  for scheme, texName in schemes.items():
        name = texName
        do_it(scheme, name, True, False, f)

  now = datetime.datetime.now()
  print(f"% Benchmarks finished at {now} (iterations={iterations})", file=f)
