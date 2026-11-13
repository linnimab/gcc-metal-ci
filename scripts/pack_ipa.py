#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pack_ipa.py — 一条命令产出「能装」的 iOS 未签名 IPA。

背景
----
抖音逆向出来的 iOS 包原本拖 20 个 framework，其中
  * 14 个（AAAWELoadManager / AudioXAAC / ByteRtsEngineKit / RTCLive /
    RTCLiveNICOExtension / RTCLiveScreenCapturer / StreamCore / TXStartSDK /
    byteaudio / bytevc0 / bytevc1enc / isecgm / libvcn / nativeserver）
    我们手上根本没有；
  * TTFFmpeg / boringssl 手上有，但只有 FairPlay 加密版（cryptid=1，
    __TEXT 熵 8.00）——嵌进去 dyld 加载的是密文，必崩。
dyld 对**强**依赖缺失是直接 abort，所以这种包装上也起不来。

本脚本的做法：只嵌**已脱壳**的那几个库，其余强依赖就地改写成弱依赖。
弱依赖缺失不会中止加载，只把符号绑成 0；哪天真的调到才崩。
（两级命名空间下符号按 dylib ordinal 绑定，就地改 cmd 不改 ordinal，
绑定关系完全不变。）

执行顺序
--------
  1. 校验 .app / 主可执行 / LC_RPATH
  2. Frameworks 目录只留 --keep 名单，其余删除
  3. 主可执行 + 每个保留 framework：指向「已删/缺失」库的强依赖 → 弱依赖
  4. 终检：非系统强依赖必须全部指向保留的库，否则非 0 退出
  5. 清掉 .bak
  6. 打包 Payload/*.app → <name>-unsigned.ipa（ZIP_STORED，快且稳）

用法
----
  python pack_ipa.py --app GoodColorCam.app --out GoodColorCam-unsigned.ipa
  python pack_ipa.py --app X.app --out X.ipa --keep EffectSDKFramework,AwemeCore
  python pack_ipa.py --app X.app --dry-run          # 只体检不打包
"""

import argparse
import importlib.util
import os
import shutil
import struct
import subprocess
import sys
import zipfile

# Windows 控制台默认 GBK，✅/❌ 这类字符会直接抛 UnicodeEncodeError
for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
WEAKEN = os.path.join(HERE, "weaken_dylib_deps.py")

# 系统库前缀：这些永远不该被删、也不该被弱化判定为“缺失”
SYS_PREFIX = ("/usr/lib/", "/System/", "/Library/Apple/")


def load_weaken():
    spec = importlib.util.spec_from_file_location("weaken_dylib_deps", WEAKEN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def strong_non_system_deps(path, W):
    """回读一个 Mach-O，返回 [(arch, ordinal, name)] 形式的非系统强依赖。"""
    with open(path, "rb") as f:
        data = f.read()
    out = []
    for soff, _ssize, cpu, is_64 in W.iter_slices(data):
        magic = struct.unpack_from("<I", data, soff)[0]
        little = magic in (W.MH_MAGIC, W.MH_MAGIC_64)
        arch = W.CPU_TYPES.get(cpu, f"cpu{cpu}")
        ordinal = 0
        for _off, cmd, _sz, name in W.walk_slice(data, soff, is_64, little):
            if cmd not in W.ORDINAL_CMDS:
                continue
            ordinal += 1
            if cmd == W.LC_LOAD_WEAK_DYLIB:
                continue
            if not name or name.startswith(SYS_PREFIX):
                continue
            out.append((arch, ordinal, name))
    return out


def framework_name(dep_path):
    """从 @rpath/X.framework/X 取出 X。"""
    base = dep_path.split("/")[-1]
    if base.endswith(".framework"):
        base = base[: -len(".framework")]
    return base


def main():
    ap = argparse.ArgumentParser(description="iOS 未签名 IPA 打包器（含弱依赖改写）")
    ap.add_argument("--app", required=True, help=".app 目录")
    ap.add_argument("--out", help="输出 .ipa 路径")
    ap.add_argument("--keep", default="EffectSDKFramework,AwemeCore",
                    help="要保留并嵌入的 framework 名单（逗号分隔）")
    ap.add_argument("--app-name", help="主可执行名，默认取 Info.plist / 目录名")
    ap.add_argument("--stubs",
                    help="桩库目录（gen_stub_frameworks.py 的 --out）。给了就把里面的 "
                         "*.framework 全部装回 Frameworks/，并自动并入保留名单")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    W = load_weaken()
    app = os.path.abspath(args.app)
    if not os.path.isdir(app):
        print(f"::error::找不到 .app 目录: {app}")
        return 1
    app_name = args.app_name or os.path.splitext(os.path.basename(app))[0]
    keep = {s.strip() for s in args.keep.split(",") if s.strip()}

    print(f"=== 1. 体检 {app} ===")
    main_bin = os.path.join(app, app_name)
    if not os.path.isfile(main_bin):
        print(f"::error::主可执行不存在: {main_bin}")
        return 1
    # LC_RPATH 必须在，否则 @rpath 解析不了
    with open(main_bin, "rb") as f:
        raw = f.read()
    has_rpath = False
    for soff, _s, _c, is_64 in W.iter_slices(raw):
        magic = struct.unpack_from("<I", raw, soff)[0]
        little = magic in (W.MH_MAGIC, W.MH_MAGIC_64)
        hdr = 32 if is_64 else 28
        ncmds = struct.unpack_from("<I" if little else ">I", raw, soff + 16)[0]
        p = soff + hdr
        for _ in range(ncmds):
            c, cs = struct.unpack_from("<II" if little else ">II", raw, p)
            if c == W.LC_RPATH:
                has_rpath = True
            p += cs
    print(f"    主可执行     : {os.path.getsize(main_bin):,} B")
    print(f"    LC_RPATH     : {'有 ✅' if has_rpath else '没有 ❌'}")
    if not has_rpath:
        print("::error::主程序没有 LC_RPATH，@rpath 无法解析，装上也起不来")
        return 1

    fw_root = os.path.join(app, "Frameworks")
    print(f"\n=== 2. 裁剪 Frameworks（保留: {sorted(keep)}）===")
    removed = []
    if os.path.isdir(fw_root):
        for entry in sorted(os.listdir(fw_root)):
            full = os.path.join(fw_root, entry)
            name = entry[: -len(".framework")] if entry.endswith(".framework") else entry
            if name in keep:
                print(f"    保留 {entry}")
                continue
            removed.append(name)
            print(f"    删除 {entry}")
            if not args.dry_run:
                shutil.rmtree(full, ignore_errors=True)
    else:
        print("    (Frameworks 目录不存在，跳过)")
    if removed:
        print(f"    共删除 {len(removed)} 个: {removed}")

    # 2.5 把桩库装回去：被删掉但**真被代码引用**的库，用空实现框架补位。
    #     只补符号、不改绑定 —— 弱依赖于是能从桩库里解析到，落到 mov w0,#0; ret，
    #     而不是落到地址 0。
    if args.stubs:
        stub_root = os.path.abspath(args.stubs)
        print(f"\n=== 2.5 装入桩库 {stub_root} ===")
        if not os.path.isdir(stub_root):
            print(f"::error::桩库目录不存在: {stub_root}")
            return 1
        os.makedirs(fw_root, exist_ok=True)
        installed = 0
        for entry in sorted(os.listdir(stub_root)):
            if not entry.endswith(".framework"):
                continue
            src = os.path.join(stub_root, entry)
            dst = os.path.join(fw_root, entry)
            name = entry[: -len(".framework")]
            if name in keep:
                print(f"    ⏭ {entry}（已在保留名单，跳过）")
                continue
            if args.dry_run:
                print(f"    会装入 {entry}")
            else:
                if os.path.isdir(dst):
                    shutil.rmtree(dst, ignore_errors=True)
                shutil.copytree(src, dst)
                print(f"    装入 {entry}")
            keep.add(name)
            installed += 1
        print(f"    共装入 {installed} 个桩库")
    else:
        print("\n=== 2.5 未指定 --stubs：只做弱化，缺失库的符号会绑 0 ===")

    print("\n=== 3. 强依赖 → 弱依赖 ===")
    keep_rx = "|".join(sorted(keep))
    targets = [("主可执行", main_bin)]
    for name in sorted(keep):
        p = os.path.join(fw_root, f"{name}.framework", name)
        if os.path.isfile(p):
            targets.append((name, p))
        else:
            print(f"::warning::保留名单里的 {name} 不在包里，跳过")

    for label, path in targets:
        deps = strong_non_system_deps(path, W)
        to_weaken = [d for d in deps if framework_name(d[2]) not in keep]
        if not to_weaken:
            print(f"    {label}: 无非系统强依赖需要处理")
            continue
        rx = "(" + "|".join(sorted({framework_name(d[2]) for d in to_weaken})) + r")\.framework"
        print(f"    {label}: 弱化 {len(to_weaken)} 条 -> {rx}")
        if args.dry_run:
            for _a, o, n in to_weaken:
                print(f"        #{o} {n}")
            continue
        r = subprocess.run([sys.executable, WEAKEN, path, "--only", rx],
                           capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        if r.returncode != 0:
            print(f"::error::weaken 失败 ({label}) rc={r.returncode}")
            print(r.stdout[-4000:])
            print(r.stderr[-2000:])
            return 1

    print("\n=== 4. 终检：非系统强依赖必须都指向保留的库 ===")
    ok = True
    for label, path in targets:
        left = [d for d in strong_non_system_deps(path, W)
                if framework_name(d[2]) not in keep]
        if left:
            ok = False
            for _a, o, n in left:
                print(f"    ❌ {label} #{o} 仍是强依赖: {n}")
        else:
            print(f"    ✅ {label}")
    if not ok:
        print("::error::仍有未解析的非系统强依赖，dyld 会 abort")
        return 1

    print("\n=== 5. 清掉 .bak ===")
    n = 0
    for root, _dirs, files in os.walk(app):
        for fn in files:
            if fn.endswith(".bak"):
                p = os.path.join(root, fn)
                print(f"    删除 {p}")
                if not args.dry_run:
                    os.remove(p)
                n += 1
    print(f"    共 {n} 个")

    if args.dry_run:
        print("\n(dry-run：未打包)")
        return 0

    if not args.out:
        print("::error::--out 未指定")
        return 1
    out = os.path.abspath(args.out)
    out_dir = os.path.dirname(out)
    if out_dir:                      # --out 只给文件名时 dirname 为 ''，makedirs 会抛
        os.makedirs(out_dir, exist_ok=True)

    print(f"\n=== 6. 打包 -> {out} ===")
    owner = os.path.basename(app)
    count = 0
    total = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED, allowZip64=True) as z:
        for root, _dirs, files in os.walk(app):
            for fn in files:
                p = os.path.join(root, fn)
                rel = os.path.relpath(p, app)
                arc = f"Payload/{owner}/{rel.replace(os.sep, '/')}"
                # 只在可执行位上置 0755，其余 0644
                mode = 0o755 if os.access(p, os.X_OK) else 0o644
                zi = zipfile.ZipInfo(arc, date_time=(2026, 10, 29, 0, 0, 0))
                zi.external_attr = (mode | 0o100000) << 16
                zi.compress_type = zipfile.ZIP_STORED
                # 流式写入：AwemeCore 单文件 1 GB，整块读进内存会爆
                with open(p, "rb") as src, z.open(zi, "w") as dst:
                    shutil.copyfileobj(src, dst, 8 * 1024 * 1024)
                count += 1
                total += os.path.getsize(p)
    print(f"    写入 {count} 个条目，{total:,} B")
    print(f"    --> {out}  ({os.path.getsize(out):,} B)")

    # 回读包内清单
    print("\n=== 7. 回读包内 Frameworks ===")
    with zipfile.ZipFile(out) as z:
        for n in z.namelist():
            if "/Frameworks/" in n and n.count("/") <= 4:
                print(f"    {n}  ({z.getinfo(n).file_size:,} B)")
    print("\n完成。这是**未签名** IPA：要装真机需自行签名"
          "（Xcode 自动签名 / Sideloadly / AltStore 均可）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
