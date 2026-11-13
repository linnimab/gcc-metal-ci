#!/usr/bin/env python3
"""????????? Xcode pbxproj,? .c/.m ????????? dylib ????

?? pbxproj ? UUID ?????????,????????? 24 ????? ID
(???????),???????????????

??:
  python3 gen_pbxproj.py --out GoodColorCam.xcodeproj/project.pbxproj \
      --src src/main.m src/CameraViewController.m \
      --framework BIN/EffectSDKFramework \
      --extra-framework BIN/TTFFmpeg \
      --bundle-id com.gcc.goodcolorcam \
      --app-name GoodColorCam
"""

import argparse
import hashlib
import os
import sys


def uid(*parts):
    """???????? 24 ????? ID?"""
    h = hashlib.sha256('::'.join(parts).encode('utf-8')).hexdigest()
    return h[:24].upper()


def build(args):
    srcs = [s for s in args.src if os.path.isfile(s)]
    if not srcs:
        sys.exit('gen_pbxproj: no source files found')

    frameworks = []
    for f in [args.framework] + args.extra_framework:
        if f and os.path.isfile(f):
            frameworks.append(f)

    # ????(folder reference,???????)
    res_folders = []
    for d in args.resource_folder:
        if d and os.path.isdir(d):
            res_folders.append(d)

    app_name = args.app_name
    exe = app_name
    bundle_id = args.bundle_id
    plist = 'src/Info.plist'

    # ---- file refs ----
    file_refs = {}      # path -> (uid, name)
    build_files = {}    # uid -> (path, basename, uid_of_file_ref)
    for p in srcs:
        fr = uid('fileref', p)
        bf = uid('buildfile', p)
        file_refs[p] = (fr, os.path.basename(p))
        build_files[p] = (bf, os.path.basename(p), fr)

    fw_refs = {}
    for f in frameworks:
        fw_refs[f] = uid('fwref', f)

    res_refs = {}
    for d in res_folders:
        res_refs[d] = uid('resref', d)

    product_ref = uid('product', app_name)
    target_id = uid('target', app_name)
    project_id = uid('project', app_name)
    main_group = uid('group', 'main')
    products_group = uid('group', 'products')
    sources_phase = uid('phase', 'sources')
    frameworks_phase = uid('phase', 'frameworks')
    resources_phase = uid('phase', 'resources')
    config_list_proj = uid('cfglist', 'project')
    config_list_tgt = uid('cfglist', 'target')
    config_debug_p = uid('cfg', 'project', 'Debug')
    config_release_p = uid('cfg', 'project', 'Release')
    config_debug_t = uid('cfg', 'target', 'Debug')
    config_release_t = uid('cfg', 'target', 'Release')
    proj_obj = uid('object', 'project')

    L = []
    a = L.append

    a('// !$*UTF8*$!')
    a('{')
    a('\tarchiveVersion = 1;')
    a('\tclasses = {')
    a('\t};')
    a('\tobjectVersion = 50;')
    a('\tobjects = {')
    a('')

    # PBXBuildFile
    a('/* Begin PBXBuildFile section */')
    for p in srcs:
        bf, name, fr = build_files[p]
        a(f'\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};')
    for f in frameworks:
        fr = fw_refs[f]
        bf = uid('buildfile_fw', f)
        a(f'\t\t{bf} /* {os.path.basename(f)} */ = {{isa = PBXBuildFile; fileRef = {fr} /* {os.path.basename(f)} */; }};')
    for d in res_folders:
        rr = res_refs[d]
        bf = uid('buildfile_res', d)
        a(f'\t\t{bf} /* {os.path.basename(d)} */ = {{isa = PBXBuildFile; fileRef = {rr} /* {os.path.basename(d)} */; }};')
    a('/* End PBXBuildFile section */')
    a('')

    # PBXFileReference
    a('/* Begin PBXFileReference section */')
    for p in srcs:
        fr, name = file_refs[p]
        # ? .c ??? sourcecode.c.c,?? sourcecode.c.objc ?? clang ?
        #   Objective-C ???? C ??(effect_bridge.c ??? C ??,???)?
        if name.endswith('.c'):
            ftype = 'sourcecode.c.c'
        elif name.endswith('.m'):
            ftype = 'sourcecode.c.objc'
        else:
            ftype = 'sourcecode.c.h'
        # ? ??:path ?????????????(? src/main.m),
        #   ? sourceTree = SOURCE_ROOT?
        #   ??? path = "main.m" + sourceTree = "<group>",Xcode ??
        #   ???? GoodColorCam/main.m,?????? GoodColorCam/src/main.m
        #   ? "Build input file cannot be found"?
        rel = p.replace('\\', '/')
        a(f'\t\t{fr} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = "{name}"; path = "{rel}"; sourceTree = SOURCE_ROOT; }};')
    for f in frameworks:
        fr = fw_refs[f]
        name = os.path.basename(f)
        # ? ????:path ?????????????(BIN/EffectSDKFramework),
        #   ? SOURCE_ROOT???? basename + "<group>" ?? Xcode ?????
        #   GoodColorCam/EffectSDKFramework ? clang: no such file or directory?
        rel = f.replace('\\', '/')
        a(f'\t\t{fr} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = "compiled.mach-o.dylib"; name = {name}; path = "{rel}"; sourceTree = SOURCE_ROOT; }};')
    for d in res_folders:
        rr = res_refs[d]
        name = os.path.basename(d)
        # folder ??:?? fileType ? Xcode ? folder reference ??(???????)?
        # path ????????(? RESOURCES/effect),sourceTree ??????
        rel = d.replace('\\', '/')
        a(f'\t\t{rr} /* {name} */ = {{isa = PBXFileReference; name = "{name}"; path = "{rel}"; sourceTree = SOURCE_ROOT; }};')
    a(f'\t\t{product_ref} /* {app_name}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "{app_name}.app"; sourceTree = BUILT_PRODUCTS_DIR; }};')
    plist_ref = uid('fileref', plist)
    a(f'\t\t{plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
    a('/* End PBXFileReference section */')
    a('')

    # PBXFrameworksBuildPhase
    a('/* Begin PBXFrameworksBuildPhase section */')
    a(f'\t\t{frameworks_phase} /* Frameworks */ = {{')
    a('\t\t\tisa = PBXFrameworksBuildPhase;')
    a('\t\t\tbuildActionMask = 2147483647;')
    a('\t\t\tfiles = (')
    for f in frameworks:
        bf = uid('buildfile_fw', f)
        a(f'\t\t\t\t{bf} /* {os.path.basename(f)} */,')
    a('\t\t\t);')
    a('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    a('\t\t};')
    a('/* End PBXFrameworksBuildPhase section */')
    a('')

    # PBXGroup
    a('/* Begin PBXGroup section */')
    a(f'\t\t{main_group} = {{')
    a('\t\t\tisa = PBXGroup;')
    a('\t\t\tchildren = (')
    for p in srcs:
        fr, name = file_refs[p]
        a(f'\t\t\t\t{fr} /* {name} */,')
    for f in frameworks:
        a(f'\t\t\t\t{fw_refs[f]} /* {os.path.basename(f)} */,')
    for d in res_folders:
        a(f'\t\t\t\t{res_refs[d]} /* {os.path.basename(d)} */,')
    a(f'\t\t\t\t{plist_ref} /* Info.plist */,')
    a(f'\t\t\t\t{products_group} /* Products */,')
    a('\t\t\t);')
    a('\t\t\tsourceTree = "<group>";')
    a('\t\t};')
    a(f'\t\t{products_group} /* Products */ = {{')
    a('\t\t\tisa = PBXGroup;')
    a('\t\t\tchildren = (')
    a(f'\t\t\t\t{product_ref} /* {app_name}.app */,')
    a('\t\t\t);')
    a('\t\t\tname = Products;')
    a('\t\t\tsourceTree = "<group>";')
    a('\t\t};')
    a('/* End PBXGroup section */')
    a('')

    # PBXNativeTarget
    a('/* Begin PBXNativeTarget section */')
    a(f'\t\t{target_id} /* {app_name} */ = {{')
    a('\t\t\tisa = PBXNativeTarget;')
    a(f'\t\t\tbuildConfigurationList = {config_list_tgt};')
    a('\t\t\tbuildPhases = (')
    a(f'\t\t\t\t{sources_phase} /* Sources */,')
    a(f'\t\t\t\t{frameworks_phase} /* Frameworks */,')
    a(f'\t\t\t\t{resources_phase} /* Resources */,')
    a('\t\t\t);')
    a('\t\t\tbuildRules = (')
    a('\t\t\t);')
    a('\t\t\tdependencies = (')
    a('\t\t\t);')
    a(f'\t\t\tname = {app_name};')
    a(f'\t\t\tproductName = {app_name};')
    a(f'\t\t\tproductReference = {product_ref} /* {app_name}.app */;')
    a('\t\t\tproductType = "com.apple.product-type.application";')
    a('\t\t};')
    a('/* End PBXNativeTarget section */')
    a('')

    # PBXProject
    a('/* Begin PBXProject section */')
    a(f'\t\t{proj_obj} /* Project object */ = {{')
    a('\t\t\tisa = PBXProject;')
    a('\t\t\tattributes = {')
    a('\t\t\t\tLastUpgradeCheck = 1500;')
    a('\t\t\t\tTargetAttributes = {')
    a(f'\t\t\t\t\t{target_id} = {{')
    a('\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;')
    a('\t\t\t\t\t};')
    a('\t\t\t\t};')
    a('\t\t\t};')
    a(f'\t\t\tbuildConfigurationList = {config_list_proj};')
    a('\t\t\tcompatibilityVersion = "Xcode 12.0";')
    a('\t\t\tdevelopmentRegion = en;')
    a('\t\t\thasScannedForEncodings = 0;')
    a('\t\t\tknownRegions = (')
    a('\t\t\t\ten,')
    a('\t\t\t\tBase,')
    a('\t\t\t);')
    a(f'\t\t\tmainGroup = {main_group};')
    a(f'\t\t\tproductRefGroup = {products_group} /* Products */;')
    a('\t\t\tprojectDirPath = "";')
    a('\t\t\tprojectRoot = "";')
    a('\t\t\ttargets = (')
    a(f'\t\t\t\t{target_id} /* {app_name} */,')
    a('\t\t\t);')
    a('\t\t};')
    a('/* End PBXProject section */')
    a('')

    # PBXResourcesBuildPhase
    a('/* Begin PBXResourcesBuildPhase section */')
    a(f'\t\t{resources_phase} /* Resources */ = {{')
    a('\t\t\tisa = PBXResourcesBuildPhase;')
    a('\t\t\tbuildActionMask = 2147483647;')
    a('\t\t\tfiles = (')
    for d in res_folders:
        bf = uid('buildfile_res', d)
        a(f'\t\t\t\t{bf} /* {os.path.basename(d)} */,')
    a('\t\t\t);')
    a('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    a('\t\t};')
    a('/* End PBXResourcesBuildPhase section */')
    a('')

    # PBXSourcesBuildPhase
    a('/* Begin PBXSourcesBuildPhase section */')
    a(f'\t\t{sources_phase} /* Sources */ = {{')
    a('\t\t\tisa = PBXSourcesBuildPhase;')
    a('\t\t\tbuildActionMask = 2147483647;')
    a('\t\t\tfiles = (')
    for p in srcs:
        bf, name, fr = build_files[p]
        a(f'\t\t\t\t{bf} /* {name} in Sources */,')
    a('\t\t\t);')
    a('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    a('\t\t};')
    a('/* End PBXSourcesBuildPhase section */')
    a('')

    # XCBuildConfiguration
    common = [
        'ALWAYS_SEARCH_USER_PATHS = NO;',
        'CLANG_ENABLE_OBJC_ARC = YES;',
        'CLANG_ENABLE_MODULES = YES;',
        'CLANG_ENABLE_OBJC_WEAK = YES;',
        'ENABLE_STRICT_OBJC_MSGSEND = YES;',
        'GCC_C_LANGUAGE_STANDARD = gnu17;',
        'IPHONEOS_DEPLOYMENT_TARGET = 15.0;',
        'SDKROOT = iphoneos;',
        'TARGETED_DEVICE_FAMILY = 1;',
        # ?????? dylib:??????? FRAMEWORK_SEARCH_PATHS ??,
        # ??? OTHER_LDFLAGS ??????,???????? _bef_* ???
    ]

    a('/* Begin XCBuildConfiguration section */')
    for cid, name in [(config_debug_p, 'Debug'), (config_release_p, 'Release')]:
        a(f'\t\t{cid} /* {name} */ = {{')
        a('\t\t\tisa = XCBuildConfiguration;')
        a('\t\t\tbuildSettings = {')
        for s in common:
            a(f'\t\t\t\t{s}')
        a(f'\t\t\t\tPRODUCT_NAME = {app_name};')
        a(f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle_id};')
        a(f'\t\t\t\tINFOPLIST_FILE = {plist};')
        # ★ 主程序必须带 LC_RPATH = @executable_path/Frameworks，
        #   否则打包校验失败、运行时 @rpath 无法解析。
        a('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
        a('\t\t\t\t\t"$(inherited)",')
        a('\t\t\t\t\t"@executable_path/Frameworks",')
        for rp in getattr(args, 'rpath', []):
            rr = rp.replace('"', '')
            if rr: a(f'\t\t\t\t\t"{rr}",')
        a('\t\t\t\t);')
        a(f'\t\t\t\tCONFIGURATION_BUILD_DIR = "$(BUILD_DIR)/{name.lower()}";')
        a('\t\t\t};')
        a(f'\t\t\tname = {name};')
        a('\t\t};')
    for cid, name in [(config_debug_t, 'Debug'), (config_release_t, 'Release')]:
        a(f'\t\t{cid} /* {name} */ = {{')
        a('\t\t\tisa = XCBuildConfiguration;')
        a('\t\t\tbuildSettings = {')
        a(f'\t\t\t\tPRODUCT_NAME = {app_name};')
        a(f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {bundle_id};')
        a(f'\t\t\t\tINFOPLIST_FILE = {plist};')
        a('\t\t\t\tCODE_SIGNING_ALLOWED = NO;')
        a('\t\t\t\tCODE_SIGNING_REQUIRED = NO;')
        # ★ 主程序必须自带 LC_RPATH = @executable_path/Frameworks。
        #   4 个 dylib 的 LC_ID_DYLIB 都是 @rpath/<名>.framework/<名>，
        #   打包时它们被放进 <App>.app/Frameworks/；没有这条 rpath，
        #   dyld 在进 main() 前就解析不了 @rpath，ipa 装上必崩。
        a('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
        a('\t\t\t\t\t"$(inherited)",')
        a('\t\t\t\t\t"@executable_path/Frameworks",')
        a('\t\t\t\t);')
        # ?? dylib ??? -framework ????? -force_load ???????
        a('\t\t\t\tFRAMEWORK_SEARCH_PATHS = (')
        a('\t\t\t\t\t"$(SRCROOT)/BIN",')
        a('\t\t\t\t);')
        a('\t\t\t\tOTHER_LDFLAGS = (')
        a('\t\t\t\t\t"$(inherited)",')
        for f in frameworks:
            a(f'\t\t\t\t\t"$(SRCROOT)/{f}",')
        # ★ LD_RUNPATH_SEARCH_PATHS 只在存在 @rpath 依赖时才产出 LC_RPATH；
        #   4 个抖音库全部只 embed 不链接，linker 会省略它。
        #   必须用 -rpath 链接参数强制写入，且合并进同一个 OTHER_LDFLAGS
        #   （pbxproj 里同名 key 重复会互相覆盖）。
        a('\t\t\t\t\t"-Wl,-rpath,@executable_path/Frameworks",')
        a('\t\t\t\t);')
        a(f'\t\t\t\tCONFIGURATION_BUILD_DIR = "$(BUILD_DIR)/{name.lower()}";')
        a('\t\t\t};')
        a(f'\t\t\tname = {name};')
        a('\t\t};')
    a('/* End XCBuildConfiguration section */')
    a('')

    # XCConfigurationList
    a('/* Begin XCConfigurationList section */')
    for cl, label, d, r in [(config_list_proj, f'PBXProject "{app_name}"', config_debug_p, config_release_p),
                            (config_list_tgt, f'PBXNativeTarget "{app_name}"', config_debug_t, config_release_t)]:
        a(f'\t\t{cl} /* {label} */ = {{')
        a('\t\t\tisa = XCConfigurationList;')
        a('\t\t\tbuildConfigurations = (')
        a(f'\t\t\t\t{d} /* Debug */,')
        a(f'\t\t\t\t{r} /* Release */,')
        a('\t\t\t);')
        a('\t\t\tdefaultConfigurationIsVisible = 0;')
        a('\t\t\tdefaultConfigurationName = Release;')
        a('\t\t};')
    a('/* End XCConfigurationList section */')
    a('\t};')
    a(f'\trootObject = {proj_obj} /* Project object */;')
    a('}')

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(L) + '\n')
    print(f'wrote {args.out}: {len(srcs)} sources, {len(frameworks)} dylibs')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--src', nargs='+', required=True)
    ap.add_argument('--framework', default=None)
    ap.add_argument('--extra-framework', action='append', default=[])
    # ????:????????????? folder reference ?? bundle,
    # ???????(??????? effect/<hash>/AmazingFeature/... ???)?
    ap.add_argument('--resource-folder', action='append', default=[])
    ap.add_argument('--bundle-id', default='com.gcc.goodcolorcam')
    ap.add_argument('--app-name', default='GoodColorCam')
    build(ap.parse_args())


if __name__ == '__main__':
    main()