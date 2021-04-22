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
  path = f"crypto_sign/{scheme}/ref"
  binary = f"crypto_sign_{scheme}_ref_speed.bin"

  assert not precomp_bitslicing
  assert not use_hardware_crypto

  subprocess.check_call(f"make IMPLEMENTATION_PATH={path} CRYPTO_ITERATIONS={iterations} bin/{binary}", shell=True)
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
  if isinstance(value, int):
    value = f"{round(value/1000):,}k"
    value = value.replace(",", "\\,")
  else:
    value = f"{value*100:.2f}\%"
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

    print(printMacro(f"{texname}cycles", int(avgs)), file=f)
    f.flush()


def do_it(scheme, texname, precomp_bitslicing, use_hardware_crypto, f):
  print(f"% {scheme}", file=f)
  logs = run(scheme, precomp_bitslicing, use_hardware_crypto)
  e([logs[0]], f, f"{texname}Keygen",  "keypair cycles:")
  e(logs, f, f"{texname}Sign", "sign cycles:")
  e(logs, f, f"{texname}Verify", "verify cycles:")


with open("speedbenchmarks_ref.tex", "a") as f:
  now = datetime.datetime.now()
  print(f"% Benchmarks started at {now} (iterations={iterations})", file=f)

  schemes = {
    "rainbowI-classic" : "rainbowIclassicRef",
    "rainbowI-circumzenithal" : "rainbowIcircumzenithalRef",
    "rainbowI-compressed" : "rainbowIcompressedRef"
  }

  for scheme, texName in schemes.items():
        name = texName
        do_it(scheme, name, False, False, f)

  now = datetime.datetime.now()
  print(f"% Benchmarks finished at {now} (iterations={iterations})", file=f)
