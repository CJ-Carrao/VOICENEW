"""Embed a newly exported PCK into the preserved Godot runtime, without editing the source game."""
from pathlib import Path
import hashlib
import json
import struct
import argparse

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / "tools/runtime/lavoice-h6-engine.bin"
if not ENGINE.exists():
    ENGINE = ROOT / "tools/runtime/lavoice-engine.bin"
PACK = ROOT / "build/LAVOICE-Lab-H6.pck"
OUTPUT = ROOT / "build/H6-Lab/LAVOICE-Lab-H6-v44.exe"


def build(pack_path=PACK, output_path=OUTPUT, engine_path=ENGINE):
    engine = bytearray(engine_path.read_bytes())
    pack = pack_path.read_bytes()
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
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(engine + pack + struct.pack("<Q4s", len(pack), b"GDPC"))
    receipt = {
        "executable": output_path.name,
        "sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
        "size": output_path.stat().st_size,
        "pack_sha256": hashlib.sha256(pack).hexdigest(),
        "runtime_sha256": hashlib.sha256(engine).hexdigest(),
        "runtime_source": engine_path.name,
        "engine_version": "4.7.2",
        "user_data_folder": "%APPDATA%/LAVOICE-Lab",
    }
    output_path.with_suffix(".receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, default=PACK)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--engine", type=Path, default=ENGINE)
    args = parser.parse_args()
    build(args.pack, args.output, args.engine)
