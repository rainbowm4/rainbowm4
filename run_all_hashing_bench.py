#!/usr/bin/env python3
import os
import subprocess
import sys
import serial
import numpy as np
import datetime

iterations = 10000

def run(scheme, precomp_bitslicing, use_hardware_crypto):
  os.system("make clean")
  path = f"crypto_sign/{scheme}/m4"
  binary = f"crypto_sign_{scheme}_m4_hashing.bin"

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

def parseLog(log, v1, v2):
    log = log.decode(errors="ignore")
    lines = str(log).splitlines()
    v1 = int(lines[1+lines.index(v1)])
    v2 = int(lines[1+lines.index(v2)])
    return (v1, v2, v2/v1)

def printMacro(name, value):
  if isinstance(value, int):
    value = f"{round(value/1000):,}k"
    value = value.replace(",", "\\,")
  else:
    value = f"{value*100:.0f}\%"
  return f"\\newcommand{{\\{name}}}{{{value}}}"


def e(logs, f, texname,  v1, v2):
    print("##########")
    print(v1, v2)
    logs  = np.array([parseLog(log, v1, v2) for log in logs])
    print(logs)
    avgs = logs.mean(axis=0)
    print("avg=", avgs)
    print("median=", np.median(logs, axis=0))
    print("max=", logs.max(axis=0))
    print("min=", logs.min(axis=0))
    print("var=", np.var(logs,axis=0))
    print("std=", np.std(logs,axis=0))

    #print(printMacro(f"{texname}cycles", int(avgs[0])), file=f)
    print(printMacro(f"{texname}hashcycles", int(avgs[1])), file=f)
    print(printMacro(f"{texname}hashpercent", avgs[2]), file=f)
    f.flush()

def do_it(scheme, texname, precomp_bitslicing, use_hardware_crypto, f):
  print(f"% {scheme}", file=f)
  logs = run(scheme, precomp_bitslicing, use_hardware_crypto)
  e([logs[0]], f, f"{texname}Keygen",  "keypair cycles:", "keypair hash cycles:")
  e(logs, f, f"{texname}Sign", "sign cycles:", "sign hash cycles:")
  e(logs, f, f"{texname}Verify", "verify cycles:", "verify hash cycles:")


with open("hashbenchmarks.tex", "a") as f:
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
