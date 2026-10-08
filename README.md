# GNU Emacs 31.1 for Windows on ARM64

[![build](https://github.com/azumafuji/emacs-windows-arm64/actions/workflows/build.yml/badge.svg)](https://github.com/azumafuji/emacs-windows-arm64/actions/workflows/build.yml)

Prebuilt, self-contained Emacs for 64-bit ARM Windows, plus the scripts that
produce it.

Emacs upstream does not support `aarch64-w64-mingw32` out of the box: the
31.1 tree has operating-system branches only for 32- and 64-bit x86, so
`./configure` stops with

```
configure: error: Emacs does not support 'aarch64-w64-mingw32' systems.
```

The MSYS2 project carries the missing support as four small patches. This
repository applies them, builds with the MSYS2 **CLANGARM64** toolchain, bundles
every runtime library Emacs needs, and packages the result as a portable zip and
a per-user/per-machine installer.

## Download

Grab the latest [releases](https://github.com/azumafuji/emacs-windows-arm64/releases):

| File | What it is |
| --- | --- |
| `emacs-31.1-aarch64-portable.zip` | Extract anywhere and run `bin\\runemacs.exe`. Nothing to install |
| `emacs-31.1-aarch64-setup.exe` | Installer for the portable build: Start Menu entries, optional PATH entry, uninstaller |
| `emacs-31.1-aarch64-native-portable.zip` | Same, built with `-mcpu=native` (see below) |
| `emacs-31.1-aarch64-native-setup.exe` | Installer for the native build |

Requires 64-bit ARM Windows (Windows 11 on ARM). It will not run on x86-64.

### Which build?

* **portable** (recommended, use this one to share) -- ARMv8-A instruction set,
  so it runs on every Windows on ARM64 machine. Scheduling is tuned for a modern
  core, which costs nothing in compatibility.
* **native** -- built with `-mcpu=native`. On the machine that built it this
  enables extra instructions (SVE2, SME, i8mm, bf16 and so on). It is **not**
  portable: it will crash or fail to start on other ARM64 machines. The measured
  gain over the portable build on a benchmark suite is within noise, so unless you
  have measured a win for your own workload, prefer the portable build.

## Build it yourself

Requirements: Windows 11 on ARM64, [MSYS2](https://www.msys2.org/) installed, and
[Inno Setup](https://jrsoftware.org/isinfo.php) 6.3 or newer if you want the
installer (the build script can install it for you).

From an **MSYS2 CLANGARM64** shell -- the Start Menu shortcut
"MSYS2 CLANGARM64", or:

```
C:\msys2\msys2_shell.cmd -defterm -here -no-start -clangarm64
```

install the toolchain and dependencies:

```
pacman -S --needed --noconfirm \
  mingw-w64-clang-aarch64-clang mingw-w64-clang-aarch64-autotools \
  mingw-w64-clang-aarch64-make mingw-w64-clang-aarch64-pkgconf \
  mingw-w64-clang-aarch64-harfbuzz mingw-w64-clang-aarch64-gnutls \
  mingw-w64-clang-aarch64-libtree-sitter mingw-w64-clang-aarch64-libxml2 \
  mingw-w64-clang-aarch64-zlib mingw-w64-clang-aarch64-freetype \
  mingw-w64-clang-aarch64-librsvg mingw-w64-clang-aarch64-libwebp \
  mingw-w64-clang-aarch64-sqlite3 mingw-w64-clang-aarch64-lcms2 \
  mingw-w64-clang-aarch64-giflib mingw-w64-clang-aarch64-libjpeg-turbo \
  mingw-w64-clang-aarch64-libpng mingw-w64-clang-aarch64-libtiff \
  mingw-w64-clang-aarch64-git mingw-w64-clang-aarch64-tools \\
  patch autoconf automake libtool texinfo
```

then build everything:

```
git clone https://github.com/azumafuji/emacs-windows-arm64
cd emacs-windows-arm64
bash scripts/build-all.sh                 # both variants
bash scripts/build-all.sh portable        # just one, much faster
```

Artifacts appear in `dist/`; the work tree, the cloned Emacs source and the
staged installs live in `work/`. Expect roughly 15-25 minutes for both
variants on a recent machine.

Individual stages, if you want to run them one at a time:

```
bash scripts/01-fetch-source.sh      # clone Emacs at the pinned tag
bash scripts/02-apply-patches.sh     # verify checksums, patch, regenerate configure
bash scripts/03-build.sh portable    # configure + make
bash scripts/05-package-portable.sh portable
powershell -File scripts/build-installer.ps1 -Variant portable
```

### Continuous integration

`.github/workflows/build.yml` builds both variants on a GitHub-hosted
`windows-11-arm` runner, runs a smoke test on both the build tree and the
packaged tree (the latter with a clean PATH, which proves the bundle is
self-contained), uploads the artifacts, and attaches them to a release when you
push a `v*` tag.

## Repository layout

```
scripts/        the build pipeline (see below)
patches/        the four MSYS2 ARM64 patches + SHA256SUMS + provenance
installer/      Inno Setup script template
bench/          benchmark workloads and driver
docs/           BUILD.md, BENCHMARKS.md
work/           (generated) source clone, build trees, staged installs
dist/           (generated) zips and installers
```

| Script | Does |
| --- | --- |
| `01-fetch-source.sh` | Shallow-clones Emacs at the pinned tag and verifies the commit |
| `02-apply-patches.sh` | Verifies patch SHA-256 sums, applies them, runs `./autogen.sh autoconf` |
| `03-build.sh` | Configures and builds one variant out of tree |
| `04-collect-dlls.sh` | Works out and copies the runtime library closure into `bin/` |
| `05-package-portable.sh` | `make install` into a staging area, bundles libraries, writes the zip |
| `build-installer.ps1` | Substitutes the .iss template and runs ISCC |
| `smoke-test.sh` | Feature check; `clean` mode proves self-containment |
| `build-all.sh` | All of the above, both variants |

## Reproducibility

* The Emacs source is pinned to the `emacs-31.1` release tag, with an
  optional `EMACS_COMMIT` pin.
* The four patches are pinned by SHA-256 and verified before use; see
  [patches/README.md](patches/README.md).
* The compiler and linker flags are fixed in [scripts/config.sh](scripts/config.sh)
  and recorded in each artifact's `SOURCE-CODE.txt`.
* `dist/PACKAGES.txt` records the exact MSYS2 package versions used, and
  `dist/BUILD-INFO.txt` the toolchain and date.

MSYS2 is a rolling release, so a rebuild months later uses newer libraries. The
*procedure* is reproducible; the bytes are not. `PACKAGES.txt` is there so a
discrepancy can be explained.

## Known limitations

* **No native Lisp compilation.** `libgccjit` does not exist for the
  clangarm64 toolchain (MSYS2 disables native compilation for all CLANG*
  environments), so Lisp is byte-compiled only. This is the single biggest
  performance feature that cannot be enabled on this platform.
* **XPM images** are unavailable (no `libXpm` in this toolchain). TIFF works
  through the Windows GDI+ backend.
* **Unsigned binaries.** Expect SmartScreen warnings; signing needs a
  code-signing certificate.
* No D-Bus, GSettings, SELinux, inotify and similar Unix-only integration --
  Emacs's configure already disables them on Windows, and the guide-style flags
  for them do nothing here (see [docs/BUILD.md](docs/BUILD.md) section 7.6).

## Licence and attribution

GNU Emacs is free software under the **GNU General Public License version 3 or
later**. The binaries here are built from the
[official Emacs 31.1 release](https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz)
with the four MSYS2 patches applied; each artifact ships a `COPYING` and a
`SOURCE-CODE.txt` that spells out exactly which sources it corresponds to.
The patches themselves come from
[msys2/MINGW-packages](https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-emacs)
and are redistributed unmodified.

**If you want ARM64 support in Emacs itself**, the right place for it is
upstream, not here: the change is small, and the Emacs maintainers would rather
review a proper submission (see `etc/CONTRIBUTE` in the Emacs tree) than
see it lived with forever as an out-of-tree patch.
