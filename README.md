# ctaggart/zig — `ai` branch

This branch hosts fork-specific infrastructure for the [ctaggart/zig](https://github.com/ctaggart/zig)
libzigc effort:

- `.github/workflows/` — release builds, libc tests, agentic helpers
- `scripts/` — supporting Python and expect scripts

The actual source code lives on `libc/0.16.x` (the release-track branch).

## Verifying release assets

Releases tagged `0.16.0-libc.<N>` are signed with [minisign](https://jedisct1.github.io/minisign/).
Every `zig-<target>-<tag>.tar.xz` / `.zip` has a sibling `.minisig` file.

Public key:

```
untrusted comment: minisign public key C11B8F39A02400AE
RWSuACSgOY8bwS0fMGytTyBlrVQsUtK/6ydxuOT/OjzlnFx2go0w1DX5
```

Verify an asset:

```sh
TAG=0.16.0-libc.5
ASSET=zig-x86_64-linux-${TAG}.tar.xz
curl -LO "https://github.com/ctaggart/zig/releases/download/${TAG}/${ASSET}"
curl -LO "https://github.com/ctaggart/zig/releases/download/${TAG}/${ASSET}.minisig"
minisign -V -P 'RWSuACSgOY8bwS0fMGytTyBlrVQsUtK/6ydxuOT/OjzlnFx2go0w1DX5' \
  -m "$ASSET"
```

Or with [`ghr`](https://github.com/cataggart/ghr):

```sh
ghr install ctaggart/zig@0.16.0-libc.5 RWSuACSgOY8bwS0fMGytTyBlrVQsUtK/6ydxuOT/OjzlnFx2go0w1DX5
```
