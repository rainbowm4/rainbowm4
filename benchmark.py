#!/usr/bin/env python3
import os
import subprocess
import sys
import serial
import numpy as np
import datetime


def run(scheme, precomp_bitslicing, iterations):
  os.system("make clean")
  path = f"crypto_sign/{scheme}/m4"
  binary = f"crypto_sign_{scheme}_m4_speed.bin"
  if precomp_bitslicing:
    precomp_bitslicing = 1
  else:
    precomp_bitslicing = 0

  subprocess.check_call(f"make PRECOMPUTE_BITSLICING={precomp_bitslicing} IMPLEMENTATION_PATH={path} CRYPTO_ITERATIONS={iterations} bin/{binary}", shell=True)
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

def e(logs, v):
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


def do_it(scheme, precomp_bitslicing, iterations):
  print(f"{scheme}")
  logs = run(scheme, precomp_bitslicing, iterations)
  e([logs[0]],  "keypair cycles:")
  e(logs, "sign cycles:")
  e(logs, "verify cycles:")




if __name__== "__main__":
    if len(sys.argv) != 4:
        print("Usage:\\ python3 benchmark.py scheme bitslicing iterations")
        print("e.g. python3 benchmark.py rainbowI-classic 1 1000")
        sys.exit(-1)
    else:
        do_it(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
