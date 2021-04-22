#!/usr/bin/env python3

import os
import subprocess
import serial
import sys
import hashlib



def run(scheme, precomp_bitslicing, use_hardware_crypto):
  os.system("make clean")
  path = f"crypto_sign/{scheme}/m4"
  binary = f"crypto_sign_{scheme}_m4_nistkat.bin"
  if precomp_bitslicing:
    precomp_bitslicing = 1
  else:
    precomp_bitslicing = 0

  if use_hardware_crypto:
    use_hardware_crypto = 1
  else:
    use_hardware_crypto = 0

  subprocess.check_call(f"make PRECOMPUTE_BITSLICING={precomp_bitslicing} USE_HARDWARE_CRYPTO={use_hardware_crypto} IMPLEMENTATION_PATH={path} bin/{binary}", shell=True)
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


def check(scheme, precomp, use_hardware_crypto, refHash):
    print(f"checking {scheme} (precomp={precomp}, hardware_crypto={use_hardware_crypto})...")
    output = run(scheme, precomp, use_hardware_crypto)
    output = output.decode(errors="ignore")
    output = output.split("+")[-1].split("#")[0][1:]
    hash = hashlib.sha3_256(output.encode("utf-8")).hexdigest()
    if hash == refHash.lower():
        result = "OK"
        print(f"testvectors {scheme} (precomp={precomp})... OK")
    else:
        result = "ERROR"
        print(f"testvectors {scheme} (precomp={precomp})... ERROR")
    return (f"{scheme} (precomp={precomp}, hardware_crypto={use_hardware_crypto})" , result)

results = []

schemes = {
  "rainbowI-classic":                "FF67670FFF15986BE86C54A34B1165A13F56D58E466130E32AB506CC4CEC74F5",
  "rainbowI-classic-tweaked":        "FC8FC96BD292E7280E8BB1357EA257672D36135B634873A4CF022035A506E542",
  "rainbowI-circumzenithal":         "49A37441B239466E8032FFF7688C8FE5D7FDABEF80007F7E043E18DE8C6AD4D6",
  "rainbowI-circumzenithal-tweaked": "789884B6FCBC1303B04853CC93E7B916D19DAEDAF2650F6F26030191AC8C6E7A",
  "rainbowI-compressed":             "FFF9A0286EBA8433A8240B86BBD255856FD50927AA35F8E15EF5003134CC231F",
  "rainbowI-compressed-tweaked":     "D5B0D8CC63B4A1E7978C28C7087C0AB1AE1CA5B08A133B7C3DB561F402849919"
}


for scheme, hash in schemes.items():
  for precomp in [True, False]:
    if scheme == "rainbowI-compressed" and precomp:
        continue
    for hardware_crypto in [True, False]:
        results += check(scheme, precomp, hardware_crypto, hash)

for r in results:
    print(r)
