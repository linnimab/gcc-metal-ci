#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
weaken_dylib_deps.py — 把 Mach-O 里的指定 LC_LOAD_DYLIB 就地改写成 LC_LOAD_WEAK_DYLIB。

为什么需要它
------------
dyld 在加载镜像时，对每一条**强**依赖（LC_LOAD_DYLIB / LC_REEXPORT_DYLIB /
LC_LOAD_UPWARD_DYLIB）都必须找到目标文件；找不到就直接 abort，App 起不来。
改成**弱**依赖（LC_LOAD_WEAK_DYLIB）后，找不到只是把相关符号绑成 0，
dyld 不再中止 —— 只有在真正调用到那些符号时才崩。

为什么就地改 cmd 是安全的
------------------------
`LC_LOAD_DYLIB` 与 `LC_LOAD_WEAK_DYLIB` 共用同一个结构体 `dylib_command`
（cmd / cmdsize / dylib{name,timestamp,current_version,compatibility_version}），
只有 `cmd` 这 4 个字节不同。两级命名空间（two-level namespace）下符号绑定靠
**dylib ordinal**，而 ordinal 由“所有占位 dylib 类命令的出现次序”决定 ——
就地改 cmd 既不增删命令也不改次序，**ordinal 与符号绑定关系完全不变**。

（注意：LC_ID_DYLIB(0x0D) 不占 ordinal，别把 0x0D 算进去。）

用法
----
  python weaken_dylib_deps.py IN --out OUT [--only REGEX] [--dry-run]
  python weaken_dylib_deps.py IN --weaken-all-non-system        # 除系统库外全弱化
  python weaken_dylib_deps.py IN --report                       # 只打印依赖表

支持 thin / fat（FAT_MAGIC, 大端）Mach-O，64 位与 32 位头。
"""

import argparse
import os
import re
import shutil
import struct
import sys

# Windows 控制台默认 GBK，非 GBK 字符会抛 UnicodeEncodeError
for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

# ---- Mach-O 常量 ----------------------------------------------------------
LC_REQ_DYLD           = 0x80000000
LC_LOAD_DYLIB         = 0x0C
LC_ID_DYLIB           = 0x0D
LC_LOAD_WEAK_DYLIB    = 0x18 | LC_REQ_DYLD
LC_REEXPORT_DYLIB     = 0x1F | LC_REQ_DYLD
LC_LOAD_UPWARD_DYLIB  = 0x23 | LC_REQ_DYLD
LC_RPATH              = 0x1C | LC_REQ_DYLD   # 供 pack_ipa.py 复查主程序 rpath
LC_SUB_FRAMEWORK      = 0x12
LC_SUB_UMBRELLA       = 0x13

# 会占 dylib ordinal 的命令（按此判定文件缺失时 dyld 会不会 abort）
ORDINAL_CMDS = (LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIB, LC_LOAD_UPWARD_DYLIB)
WEAKENABLE   = (LC_LOAD_DYLIB, LC_REEXPORT_DYLIB, LC_LOAD_UPWARD_DYLIB)

CMD_NAME = {
    LC_LOAD_DYLIB:        "LC_LOAD_DYLIB",
    LC_ID_DYLIB:          "LC_ID_DYLIB",
    LC_LOAD_WEAK_DYLIB:   "LC_LOAD_WEAK_DYLIB",
    LC_REEXPORT_DYLIB:    "LC_REEXPORT_DYLIB",
    LC_LOAD_UPWARD_DYLIB: "LC_LOAD_UPWARD_DYLIB",
}

MH_MAGIC    = 0xFEEDFACE
MH_CIGAM    = 0xCEFAEDFE
MH_MAGIC_64 = 0xFEEDFACF
MH_CIGAM_64 = 0xCFFAEDFE
FAT_MAGIC   = 0xCAFEBABE
FAT_CIGAM   = 0xBEBAFECA
FAT_MAGIC_64  = 0xCAFEBABF
FAT_CIGAM_64  = 0xBFBAFECA

CPU_TYPES = {
    7: "x86", 0x01000007: "x86_64", 12: "arm", 0x0100000C: "arm64",
    0x0200000C: "arm64_32",
}


def is_system_dylib(name: str) -> bool:
    return name.startswith(("/usr/lib/", "/System/", "/Library/Apple/"))


def iter_slices(data: bytes):
    """产出 (slice_file_offset, slice_size, cpu_type, is_64)。"""
    if len(data) < 8:
        raise ValueError("文件太小，不是 Mach-O")
    magic = struct.unpack_from(">I", data, 0)[0]

    if magic in (FAT_MAGIC, FAT_MAGIC_64):
        nfat = struct.unpack_from(">I", data, 4)[0]
        step = 32 if magic == FAT_MAGIC_64 else 20
        for i in range(nfat):
            base = 8 + i * step
            if magic == FAT_MAGIC_64:
                cpu, _sub, off, size, _align, _res = struct.unpack_from(">iiQQII", data, base)
            else:
                cpu, _sub, off, size, _align = struct.unpack_from(">iiIII", data, base)
            yield off, size, cpu, cpu in (0x01000007, 0x0100000C, 0x0200000C)
        return

    le = struct.unpack_from("<I", data, 0)[0]
    if le in (MH_MAGIC, MH_MAGIC_64):
        cpu = struct.unpack_from("<i", data, 4)[0]
        yield 0, len(data), cpu, le == MH_MAGIC_64
        return
    be = struct.unpack_from(">I", data, 0)[0]
    if be in (MH_MAGIC, MH_MAGIC_64):
        cpu = struct.unpack_from(">i", data, 4)[0]
        yield 0, len(data), cpu, be == MH_MAGIC_64
        return
    raise ValueError(f"不认识的 Mach-O magic: 0x{le:08x} / 0x{be:08x}")


def read_dylib_name(data: bytes, cmd_off: int, cmdsize: int, little: bool):
    """dylib_command 里 name 的偏移在 +8（跟随 cmd/cmdsize）。"""
    if cmdsize < 24:
        return None
    name_off = struct.unpack_from("<I" if little else ">I", data, cmd_off + 8)[0]
    if name_off >= cmdsize:
        return None
    start = cmd_off + name_off
    end = data.find(b"\x00", start, cmd_off + cmdsize)
    if end < 0:
        end = cmd_off + cmdsize
    return data[start:end].decode("utf-8", "replace")


def walk_slice(data: bytes, off: int, is_64: bool, little: bool):
    """产出 (cmd_off, cmd, cmdsize, name) —— name 仅对 dylib 类命令非 None。"""
    hdr = 32 if is_64 else 28
    ncmds = struct.unpack_from("<I" if little else ">I", data, off + 16)[0]
    p = off + hdr
    for _ in range(ncmds):
        if p + 8 > len(data):
            break
        cmd, cmdsize = struct.unpack_from("<II" if little else ">II", data, p)
        if cmdsize < 8 or p + cmdsize > len(data):
            break
        name = read_dylib_name(data, p, cmdsize, little) if cmd in ORDINAL_CMDS or cmd == LC_ID_DYLIB else None
        yield p, cmd, cmdsize, name
        p += cmdsize


def main() -> int:
    ap = argparse.ArgumentParser(description="Mach-O 强依赖 → 弱依赖改写器")
    ap.add_argument("input")
    ap.add_argument("--out", help="输出路径（默认原地，自动 .bak 备份）")
    ap.add_argument("--only", help="只弱化匹配该正则的 dylib 路径")
    ap.add_argument("--weaken-all-non-system", action="store_true",
                    help="除 /usr/lib、/System 以外的全部强依赖都弱化")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--report", action="store_true", help="只打印依赖表，不改文件")
    args = ap.parse_args()

    with open(args.input, "rb") as f:
        data = bytearray(f.read())

    matcher = re.compile(args.only) if args.only else None
    changes = []   # (arch, ordinal, name, old, new)

    for soff, ssize, cpu, is_64 in iter_slices(bytes(data)):
        # 判定字节序
        m = struct.unpack_from("<I", data, soff)[0]
        little = m in (MH_MAGIC, MH_MAGIC_64)
        arch = CPU_TYPES.get(cpu, f"cpu{cpu}")

        ordinal = 0
        print(f"\n=== {os.path.basename(args.input)} [{arch}] slice@{soff} ===")
        for cmd_off, cmd, cmdsize, name in walk_slice(bytes(data), soff, is_64, little):
            if cmd not in ORDINAL_CMDS and cmd != LC_ID_DYLIB:
                continue
            tag = CMD_NAME.get(cmd, f"0x{cmd:x}")
            if cmd == LC_ID_DYLIB:
                print(f"  (id)  {tag:20s} {name}")
                continue
            ordinal += 1
            weak = cmd == LC_LOAD_WEAK_DYLIB
            mark = "weak  " if weak else "STRONG"
            print(f"  #{ordinal:<3d} {mark} {tag:20s} {name}")

            if cmd not in WEAKENABLE:
                continue
            hit = args.weaken_all_non_system and not is_system_dylib(name or "")
            if matcher and name and matcher.search(name):
                hit = True
            if hit:
                changes.append((arch, ordinal, name, tag, "LC_LOAD_WEAK_DYLIB"))
                if not args.report:
                    struct.pack_into("<I" if little else ">I", data, cmd_off, LC_LOAD_WEAK_DYLIB)

    print("\n---- 汇总 ----")
    if not changes:
        print("无需改写。")
        return 0
    print(f"将改写 {len(changes)} 条：")
    for arch, ordinal, name, old, new in changes:
        print(f"  [{arch}] #{ordinal} {old} -> {new}   {name}")

    if args.report or args.dry_run:
        print("(dry-run / report：未写盘)")
        return 0

    out = args.out or args.input
    if not args.out:
        bak = args.input + ".bak"
        if not os.path.exists(bak):
            shutil.copy2(args.input, bak)
            print(f"已备份 -> {bak}")
    with open(out, "wb") as f:
        f.write(data)
    print(f"已写出 -> {out}  ({len(data):,} bytes)")

    # 回读校验
    with open(out, "rb") as f:
        verify = f.read()
    bad = 0
    for soff, ssize, cpu, is_64 in iter_slices(verify):
        m = struct.unpack_from("<I", verify, soff)[0]
        little = m in (MH_MAGIC, MH_MAGIC_64)
        for cmd_off, cmd, cmdsize, name in walk_slice(verify, soff, is_64, little):
            if cmd == LC_LOAD_DYLIB and name and any(name == c[2] for c in changes):
                print(f"  !! 回读仍是强依赖: {name}")
                bad += 1
    print("回读校验: " + ("OK，已全部生效" if bad == 0 else f"有 {bad} 条没生效"))
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
