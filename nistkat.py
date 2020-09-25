#!/usr/bin/env python3

import os
import subprocess
import serial
import sys
import hashlib



def run(scheme, precomp_bitslicing):
  os.system("make clean")
  path = f"crypto_sign/{scheme}/m4"
  binary = f"crypto_sign_{scheme}_m4_nistkat.bin"
  if precomp_bitslicing:
    precomp_bitslicing = 1
  else:
    precomp_bitslicing = 0

  subprocess.check_call(f"make PRECOMPUTE_BITSLICING={precomp_bitslicing} IMPLEMENTATION_PATH={path} bin/{binary}", shell=True)
  os.system(f"./flash.sh bin/{binary}")

  # get serial output and wait for '#'
  with serial.Serial("/dev/ttyUSB0", 115200, timeout=20) as dev:
      iteration = 0
      log = b""
      while True:
        device_output = dev.read()
        sys.stdout.buffer.write(device_output)
        sys.stdout.flush()
        log += device_output
        if device_output == b'#':
          return log


def check(scheme, precomp, refHash):
    print(f"checking {scheme} (precomp={precomp})...")
    output = run(scheme, precomp)
    output = output.decode(errors="ignore") 
    output = output.split("+")[-1].split("#")[0][1:]
    hash = hashlib.sha3_256(output.encode("utf-8")).hexdigest()
    if hash == refHash.lower():
        result = "OK"
        print(f"testvectors {scheme} (precomp={precomp})... OK")
    else:
        result = "ERROR"
        print(f"testvectors {scheme} (precomp={precomp})... ERROR")
    return (f"{scheme} (precomp={precomp})" , result)

results = []

# w/o precomp
results += check("rainbowI-classic", False, "FF67670FFF15986BE86C54A34B1165A13F56D58E466130E32AB506CC4CEC74F5")
results += check("rainbowI-circumzenithal", False,  "49A37441B239466E8032FFF7688C8FE5D7FDABEF80007F7E043E18DE8C6AD4D6")
results += check("rainbowI-compressed", False, "FFF9A0286EBA8433A8240B86BBD255856FD50927AA35F8E15EF5003134CC231F")

# w/ precomp
results += check("rainbowI-classic", True, "FF67670FFF15986BE86C54A34B1165A13F56D58E466130E32AB506CC4CEC74F5")
results += check("rainbowI-circumzenithal", True,  "49A37441B239466E8032FFF7688C8FE5D7FDABEF80007F7E043E18DE8C6AD4D6")

for r in results:
    print(r)
