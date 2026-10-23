"""Embed a newly exported PCK into the preserved Godot runtime, without editing the source game."""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / "tools/runtime/lavoice-engine.bin"
PACK = ROOT / "build/LAVOICE-Lab.pck"
OUTPUT = ROOT / "build/LAVOICE-Lab.exe"


def build():
    engine = bytearray(ENGINE.read_bytes())
    pack = PACK.read_bytes()
    if pack[:4] != b"GDPC":
        raise ValueError("Export is not a Godot PCK")
    pe_offset = struct.unpack_from("<I", engine, 0x3C)[0]
    section_count = struct.unpack_from("<H", engine, pe_offset + 6)[0]
    optional_size = struct.unpack_from("<H", engine, pe_offset + 20)[0]
    section_table = pe_offset + 24 + optional_size
    matched = False
    for index in range(section_count):
        section = section_table + index * 40
        if engine[section:section + 8].rstrip(b"\0") == b"pck":
            struct.pack_into("<II", engine, section + 16, len(pack) + 12, len(engine))
            matched = True
            break
    if not matched:
        raise ValueError("Preserved runtime has no PCK section")
    OUTPUT.write_bytes(engine + pack + struct.pack("<Q4s", len(pack), b"GDPC"))
    receipt = {
        "executable": OUTPUT.name,
        "sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "size": OUTPUT.stat().st_size,
        "pack_sha256": hashlib.sha256(pack).hexdigest(),
        "runtime_sha256": hashlib.sha256(engine).hexdigest(),
        "engine_version": "4.7.2",
        "user_data_folder": "%APPDATA%/LAVOICE-Lab",
    }
    (ROOT / "build/build-receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    build()
