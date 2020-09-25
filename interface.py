import subprocess

import serial

from mupq import mupq


class M4Settings(mupq.PlatformSettings):
    #: Specify folders to include
    scheme_folders = [  # mupq.PlatformSettings.scheme_folders + [
        ('pqm4', 'crypto_sign', ''),
    ]
    #: List of dicts, in each dict specify (Scheme class) attributes of the
    #: scheme with values, if all attributes match the scheme is skipped.
    skip_list = (
        {'scheme': 'rainbowI-classic', 'implementation': 'ref'},
        {'scheme': 'rainbowI-classic-round2', 'implementation': 'ref'},
        {'scheme': 'rainbowI-circumzenithal', 'implementation': 'ref'},
        {'scheme': 'rainbowI-circumzenithal-round2', 'implementation': 'ref'},
        {'scheme': 'rainbowI-compressed', 'implementation': 'ref'},
        {'scheme': 'rainbowI-compressed-round2', 'implementation': 'ref'},
    )


class M4(mupq.Platform):

    def __enter__(self):
        self._dev = serial.Serial("/dev/ttyUSB0", 115200, timeout=10)
        return super().__enter__()

    def __exit__(self,*args, **kwargs):
        self._dev.close()
        return super().__exit__(*args, **kwargs)

    def device(self):
        return self._dev

    def flash(self, binary_path):
        super().flash(binary_path)
        subprocess.check_call(
            ["./flash.sh",  binary_path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
