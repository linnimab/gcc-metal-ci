#!/usr/bin/env python3
# 抖音内部转发库 TTFFmpeg / boringssl 不随包。静态核对：SDK 的 undefined
# 符号表没有绑定到这两个库（CGImageSource* 属 ImageIO，VTCompressionSession*
# 属 VideoToolbox），因此只需把两条 LC_LOAD_DYLIB 改成 LC_LOAD_WEAK_DYLIB：
# dyld 找不到时跳过，不改代码段、不改符号、不动画质/算法/精度。
import struct, sys
p = sys.argv[1]
d = bytearray(open(p, "rb").read())
magic = struct.unpack_from(">I", d, 0)[0]
base = 0
if magic in (0xcafebabe, 0xcafebabf):
    n = struct.unpack_from(">I", d, 4)[0]
    for i in range(n):
        cpu, sub, off, sz, al = struct.unpack_from(">IIIII", d, 8 + 20 * i)
        if cpu == 0x100000C:
            base = off
            break
b = d[base:]
ncmds, = struct.unpack_from("<I", b, 16)
off = 32
targets = []
symoff = nsyms = 0
for _ in range(ncmds):
    cmd, s = struct.unpack_from("<II", b, off)
    if cmd == 0xC:  # LC_LOAD_DYLIB
        no, = struct.unpack_from("<I", b, off + 8)
        path = bytes(b[off + no:off + s]).split(b"\0")[0].decode(errors="replace")
        if "TTFFmpeg.framework" in path or "boringssl.framework" in path:
            targets.append((base + off, path))
    if cmd == 0x2:
        symoff, nsyms, stroff, strsize = struct.unpack_from("<IIII", b, off + 8)
    off += s
assert len(targets) == 2, "expected 2 forwarder dylibs, got %d" % len(targets)
# 诊断：统计仍绑定到这两库的 undefined 符号（正确构建应为 0）
libs = []
off = 32
for _ in range(ncmds):
    cmd, s = struct.unpack_from("<II", b, off)
    if cmd in (0xC, 0x80000018, 0x8000001F, 0x80000023, 0x20):
        no, = struct.unpack_from("<I", b, off + 8)
        libs.append(bytes(b[off + no:off + s]).split(b"\0")[0].decode(errors="replace"))
    off += s
bound = 0
for i in range(nsyms):
    e = symoff + 16 * i
    ntype = b[e + 4]
    desc, = struct.unpack_from("<H", b, e + 8)
    if (ntype & 0x0E) != 0:      # 不是 N_UNDF
        continue
    ordinal = (desc >> 8) & 0xFF
    if 1 <= ordinal <= len(libs):
        nm = libs[ordinal - 1]
        if "TTFFmpeg.framework" in nm or "boringssl.framework" in nm:
            bound += 1
print("forwarders=%s  bound_undefined_symbols=%d" % ([t[1] for t in targets], bound))
if bound:
    print("WARNING: forwarder still owns %d undefined symbols; weak-load will NULL them" % bound)
for cp, _ in targets:
    struct.pack_into("<I", d, cp, 0x80000018)  # LC_LOAD_WEAK_DYLIB
open(p, "wb").write(d)
print("patched: 2 strong LC_LOAD_DYLIB -> LC_LOAD_WEAK_DYLIB")
