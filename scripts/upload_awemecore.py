#!/usr/bin/env python3
"""把 AwemeCore（1 GB）上传到 GitHub Release —— 不占仓库配额，CI 用 curl 下载。

GitHub Release 附件限制：
  - 单个附件 ≤ 2 GB        （AwemeCore 1.03 GB ✔）
  - 每个 Release 总大小无硬上限
  - 不计入仓库 LFS 配额

用法：
  python3 upload_awemecore.py --token ghp_xxx --repo linnimab/GoodColorCam \
      --file BIN/AwemeCore --tag deps-v1

CI 侧对应：
  https://github.com/linnimab/GoodColorCam/releases/download/deps-v1/AwemeCore
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error
import urllib.parse


API = 'https://api.github.com'


def req(method, url, token, data=None, content_type='application/json'):
    r = urllib.request.Request(url, method=method, data=data)
    r.add_header('Authorization', 'token ' + token)
    r.add_header('User-Agent', 'gcc-upload')
    r.add_header('Accept', 'application/vnd.github+json')
    if content_type:
        r.add_header('Content-Type', content_type)
    try:
        with urllib.request.urlopen(r) as resp:
            body = resp.read()
            return resp.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', 'replace')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--token', required=True)
    ap.add_argument('--repo', default='linnimab/GoodColorCam')
    ap.add_argument('--file', required=True)
    ap.add_argument('--tag', default='deps-v1')
    ap.add_argument('--name', default=None)
    args = ap.parse_args()

    path = args.file
    if not os.path.isfile(path):
        sys.exit('upload: file not found: ' + path)
    size = os.path.getsize(path)
    name = args.name or os.path.basename(path)
    print('file: %s  %.2f GB' % (name, size / 1024.0 / 1024 / 1024))

    # 1. 找/建 release
    st, rel = req('GET', '%s/repos/%s/releases/tags/%s' % (API, args.repo, args.tag), args.token)
    if st == 404:
        print('creating release %s' % args.tag)
        body = json.dumps({
            'tag_name': args.tag,
            'name': 'iOS build dependencies',
            'body': ('Large binaries that cannot live in the repo.\n\n'
                     '`AwemeCore` (1.03 GB) is Douyin\'s main binary; EffectSDKFramework\n'
                     'needs 103 NAPI bridge symbols from it. Nothing else is used.\n'),
            'draft': False,
            'prerelease': False,
        }).encode('utf-8')
        st, rel = req('POST', '%s/repos/%s/releases' % (API, args.repo), args.token, body)
        if st not in (200, 201):
            sys.exit('create release failed: %s %s' % (st, rel))
    elif st != 200:
        sys.exit('get release failed: %s %s' % (st, rel))
    else:
        print('release %s exists (id=%s)' % (args.tag, rel['id']))

    upload_url = rel['upload_url'].split('{')[0]

    # 2. 已存在同名 asset 就先删（重跑友好）
    for a in rel.get('assets', []):
        if a['name'] == name:
            print('deleting existing asset %s (id=%s)' % (name, a['id']))
            req('DELETE', '%s/repos/%s/releases/assets/%s' % (API, args.repo, a['id']), args.token)

    # 3. 上传（流式，避免 1 GB 全读进内存）
    print('uploading %s (this takes a while on 1 GB)...' % name)
    url = '%s?name=%s' % (upload_url, urllib.parse.quote(name))
    with open(path, 'rb') as fh:
        r = urllib.request.Request(url, method='POST', data=fh)
        r.add_header('Authorization', 'token ' + args.token)
        r.add_header('User-Agent', 'gcc-upload')
        r.add_header('Content-Type', 'application/octet-stream')
        r.add_header('Content-Length', str(size))
        try:
            with urllib.request.urlopen(r) as resp:
                asset = json.loads(resp.read())
                print('OK  uploaded: %s' % asset['browser_download_url'])
                print('size: %d' % asset['size'])
        except urllib.error.HTTPError as e:
            sys.exit('upload failed: %s %s' % (e.code, e.read().decode('utf-8', 'replace')))


if __name__ == '__main__':
    main()
