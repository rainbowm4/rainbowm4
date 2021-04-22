#!/usr/bin/env python3
import os
import subprocess
import sys
import serial
import numpy as np
import datetime

iterations = 1

def run(scheme, precomp_bitslicing, use_hardware_crypto):
  os.system("make clean")
  path = f"crypto_sign/{scheme}/m4"
  binary = f"crypto_sign_{scheme}_m4_stack.bin"
  if precomp_bitslicing:
    precomp_bitslicing = 1
  else:
    precomp_bitslicing = 0

  if use_hardware_crypto:
    use_hardware_crypto = 1
  else:
    use_hardware_crypto = 0


  subprocess.check_call(f"make PRECOMPUTE_BITSLICING={precomp_bitslicing} USE_HARDWARE_CRYPTO={use_hardware_crypto} IMPLEMENTATION_PATH={path} CRYPTO_ITERATIONS={iterations} bin/{binary}", shell=True)
  os.system(f"./flash.sh bin/{binary}")

  # get serial output and wait for '#'
  with serial.Serial("/dev/ttyUSB0", 115200, timeout=20) as dev:
      logs = []
      iteration = 0
      log = b""
      while iteration < iterations:
          device_output = dev.read()
          sys.stdout.buffer.write(device_output)
          sys.stdout.flush()
          log += device_output
          if device_output == b'#':
              logs.append(log)
              log = b""
              iteration += 1
  return logs

def parseLog(log, v):
    log = log.decode(errors="ignore")
    lines = str(log).splitlines()
    v = int(lines[1+lines.index(v)])
    return v

def printMacro(name, value):
  value = f"{round(value):,}"
  value = value.replace(",", "\\,")
  return f"\\newcommand{{\\{name}}}{{{value}}}"

def e(logs, f, texname,  v):
    print("##########")
    print(v)
    logs  = np.array([parseLog(log, v) for log in logs])
    print(logs)
    avgs = logs.mean()
    print("avg=", avgs)
    print("median=", np.median(logs))
    print("max=", logs.max())
    print("min=", logs.min())
    print("var=", np.var(logs))
    print("std=", np.std(logs))

    print(printMacro(f"{texname}stack", int(avgs)), file=f)
    f.flush()


def do_it(scheme, texname, precomp_bitslicing, use_hardware_crypto, f):
  print(f"% {scheme}", file=f)
  logs = run(scheme, precomp_bitslicing, use_hardware_crypto)
  e([logs[0]], f, f"{texname}Keygen",  "keypair stack usage:")
  e(logs, f, f"{texname}Sign", "sign stack usage:")
  e(logs, f, f"{texname}Verify", "verify stack usage:")


with open("stackbenchmarks.tex", "a") as f:
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
    for precomp in [True, False]:

      if (scheme == "rainbowI-compressed" or scheme == "rainbowI-compressed-tweaked") and precomp:
        continue
      for hardware_crypto in [True, False]:
        name = texName
        if precomp:
          name += "Precomp"
        if hardware_crypto:
          name += "HWCrypto"
        do_it(scheme, name, precomp, hardware_crypto, f)

  now = datetime.datetime.now()
  print(f"% Benchmarks finished at {now} (iterations={iterations})", file=f)
