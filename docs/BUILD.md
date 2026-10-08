# Building Emacs 31.1 for Windows on ARM64

Technical reference for this repository. For the short version see the
[README](../README.md); to build it, run `bash scripts/build-all.sh`.

## 1. Why patches are needed

Emacs 31.1's `configure.ac` chooses an operating system with a `case` on
the canonical host name, and has branches only for `i[3456]86-*-*` and
`x86_64-*-*`. Everything else sets `unported=yes`:

```
configure: error: Emacs does not support 'aarch64-w64-mingw32' systems.
```

MSYS2 builds Emacs for clangarm64 and publishes the fix as four small files,
which this repository applies unmodified -- see
[patches/README.md](../patches/README.md) for what each one changes.

## 2. Environment

Use an **MSYS2 CLANGARM64** shell:

```
C:\msys2\msys2_shell.cmd -defterm -here -no-start -clangarm64
```

The toolchain must be clang targeting `aarch64-w64-windows-gnu`:

```
echo $MSYSTEM $MINGW_PREFIX $MINGW_CHOST
clang --version | head -2
```

Expected: `CLANGARM64 /clangarm64 aarch64-w64-mingw32`. The package list is
in the [README](../README.md#build-it-yourself). Two things trip people up:

* **`libtree-sitter` is a separate package from `tree-sitter`.** The
  package called `tree-sitter` installs only the command-line tool, with no
  library, headers or `.pc` file. Without `libtree-sitter`, configure
  ends with "The following required libraries were not found: tree-sitter".
* `mingw-w64-clang-aarch64-tools` provides the `objdump` that
  `04-collect-dlls.sh` needs.

## 3. Build variants and flags

| | portable | native |
| --- | --- | --- |
| CFLAGS | `-O2 -pipe -Wno-incompatible-pointer-types -fno-omit-frame-pointer -march=armv8-a -mtune=cortex-a76 -flto=thin` | same but `-mcpu=native` replacing `-march=armv8-a -mtune=cortex-a76` |
| CPPFLAGS | `-mtune=cortex-a76` | `-mcpu=native -mtune=native` |
| LDFLAGS | `-flto=thin -fuse-ld=lld -lpthread` | same |

Shared configure options: `--prefix=/opt/emacs`, `--host`/`--build`
set to `$MINGW_CHOST`, `--without-native-compilation`,
`--with-modules`, `--with-harfbuzz`, `--with-tree-sitter`,
`--with-gnutls`, `--without-dbus`, `--without-compress-install`,
`--disable-gc-mark-trace`.

Why each flag:

| Flag | Reason |
| --- | --- |
| `-O2` | Deliberately not `-O3`: it buys little for Emacs and can cost responsiveness |
| `-fno-omit-frame-pointer` | Recommended by the Emacs developers; makes crashes debuggable. Costs binary size |
| `-march=armv8-a` | The portable instruction-set baseline -- every Windows on ARM64 machine has it |
| `-mcpu=native` | Enables this CPU's extensions (SVE2/SME/i8mm on a Snapdragon X2). Native variant only, and not portable |
| `-mtune=cortex-a76` | Scheduling only, no ISA change, so it stays portable |
| `-flto=thin` and `-fuse-ld=lld` | Cross-module inlining; lld is required to link LTO bitcode |
| `-lpthread` | **Mandatory.** Without it the nanosleep probe fails, gnulib's replacement machinery engages, and the link dies with `undefined symbol: rpl_nanosleep` |
| `--disable-gc-mark-trace` | Drops the GC debug mark-trace buffer |
| `--without-native-compilation` | Forced: `libgccjit` does not exist for clangarm64 |

### The `-mtune` trap

MSYS2's patch sets `C_SWITCH_SYSTEM="-mtune=cortex-a53"`, and configure.ac
appends it to CPPFLAGS *after* whatever CPPFLAGS you supplied. Setting the same
tuning flag in both `CFLAGS` and `CPPFLAGS` is what guarantees the
intended one wins, whichever order a make rule happens to use.

## 4. Deliberately not used

| Idea | Why not |
| --- | --- |
| `-march=native` in the portable build | On a Snapdragon X2 it resolves to SVE2/SME/i8mm/bf16, which other Windows on ARM64 chips lack |
| `-fno-plt` | An ELF/PLT concept; meaningless on PE/COFF |
| `-Wl,-z,now`, `-z,relro`, `-z,pack-relative-relocs` | ELF-only; **lld rejects them** with `lld: error: unknown argument: -z` |
| `--with-cairo` | No-op on w32: `HAVE_CAIRO` is set only when `HAVE_X11` is yes |
| `--with-file-notification=inotify` | Hard error on Windows; the port uses W32NOTIFY |
| PGO | Not implemented here; see section 7 |

## 5. Windows-irrelevant exclusion flags

Linux-oriented guides suggest excluding features you do not need. Almost none of
it matters here, because configure already disables everything the w32 port
cannot use. This was verified by passing each flag to a throwaway configure run
and diffing the generated `src/config.h` against an identical run without it.

| Flag | Effect on this build |
| --- | --- |
| `--without-libsystemd`, `--without-gconf`, `--with/without-gsettings`, `--without-selinux`, `--without-libsmack`, `--without-gpm`, `--without-imagemagick`, `--without-xpm`, `--without-m17n-flt`, `--without-libotf`, `--without-xft`, `--without-xim`, `--without-xdbe`, `--without-xinput2`, `--with-libgmp`, `--without-kerberos` | **No effect at all** -- sixteen flags, all leaving config.h unchanged |
| `--without-included-regex` | Does change the build despite an identical feature summary: it drops gnulib's regex (the `rpl_*` redirections disappear) in favour of the system one. Not recommended |
| `--without-sound` | Real: removes `HAVE_SOUND` and `HAVE_MMSYSTEM_H`; you lose the audible bell |
| `--disable-acl` | Real: `USE_ACL` 1 to 0. The rationale is POSIX-centric; on Windows this discards native ACL handling |
| `--disable-xattr` | No effect -- no extended attributes on this port |
| `--disable-build-details` | Real but cosmetic: reproducible build, no hostname or git revision in the version string |
| `--without-png/jpeg/gif/tiff/rsvg/webp/lcms2/sqlite3` | Each removes a real feature (eight flip to no) |
| `--without-toolkit-scroll-bars` | Hard error: `Non-toolkit scroll bars are not implemented for w32 build` |

Nothing from those lists is worth adopting: the useful ones
(`--without-dbus`, `--without-compress-install`,
`--disable-gc-mark-trace`) are already in the configure line.

**Method note:** the configure summary is not sufficient evidence that a flag did
nothing. `--without-included-regex` leaves the summary identical while
changing the headers. Diff `config.h`.

## 6. Packaging

`05-package-portable.sh` runs `make install DESTDIR=...` and takes
`<DESTDIR>/opt/emacs` as the application root, since the prefix is
`/opt/emacs`. Emacs is relocatable on Windows: `epaths.h` stores paths
as `%emacs_dir%/...` and `w32_relocate()` in `src/w32.c` derives
`emacs_dir` from the running executable's directory, stripping one level --
so `bin/` must stay next to `share/` and `libexec/`.

Only two libraries are linked into `emacs.exe` (`libwinpthread-1.dll`
and `libgmp-10.dll`); the rest are loaded at run time and their names are
listed in `lisp/term/w32-nt.el` (`dynamic-library-alist`).
`04-collect-dlls.sh` therefore bundles the transitive import closure of every
shipped executable plus every `.dll` name in that alist, expanding `%d`
placeholders into globs so it keeps working as library versions change. It finds
57 libraries, about 51 MB.

**Do not gate that recursion on objdump's exit status.** For some DLLs objdump
prints a complete import table and still exits non-zero; treating that as failure
silently drops whole subtrees -- an earlier version produced a plausible-looking
19-library set with GnuTLS, tree-sitter and SVG all dead.

The installer is generated from `installer/emacs.iss.in` by
`scripts/build-installer.ps1`. Two things are easy to get wrong:

* `ChangesEnvironment=yes` belongs in the **[Setup]** section. It is not a
  [Registry] parameter, even though it governs the PATH entry written there.
* Both `[Registry]` PATH entries must be guarded by
  `IsAdminInstallMode`. A check that only asks "is this directory already on
  PATH?" returns True during a per-user install, Inno then attempts the
  machine-wide write, and installation fails with
  `RegCreateKeyEx failed; code 5. Access is denied`. Uninstall mirrors the
  logic and deletes the `Path` value if nothing else remains.

ARM64 support needs Inno Setup 6.3 or newer; the architecture identifiers are
`arm64` (and `x64compatible`, `arm32compatible`, `win64`,
`x64os`).

## 7. Verification and performance

`smoke-test.sh` runs a feature check against a built or packaged
`emacs.exe`; in `clean` mode it strips MSYS2 from `PATH` first,
which is what proves the bundle is self-contained. `build-all.sh` runs it
both ways for each variant.

Performance is measured separately: see [BENCHMARKS.md](BENCHMARKS.md) and
[../bench](../bench). Headline result: about 3-4% faster on C-heavy work than an
unoptimised `-O2` build -- smaller than the run-to-run noise, so compare
medians of paired repetitions. The options that would matter more are either
unavailable (native Lisp compilation needs libgccjit) or unimplemented (PGO,
which needs an instrumented build plus a training run).

## 8. Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `Emacs does not support 'aarch64-w64-mingw32' systems` | Patches not applied, or configure regenerated after patching without `./autogen.sh autoconf` |
| `required libraries were not found: tree-sitter` | The `libtree-sitter` package is missing |
| `undefined symbol: rpl_nanosleep` or `clock_gettime64` | `-lpthread` missing from LDFLAGS while using LTO |
| `lld: error: unknown argument: -z` | ELF-only linker flag; remove it |
| `-mtune` appears ignored | Patch 002's CPPFLAGS arrives after CFLAGS; set the flag in both (section 3) |
| A feature works in `work/` but not in the packaged tree | Runtime libraries were not bundled; check the warning from `04-collect-dlls.sh` |
| `RegCreateKeyEx failed; code 5` during a per-user install | The HKLM PATH entry is not guarded by `IsAdminInstallMode` (section 6) |

## 9. Where the ARM64 support belongs

Upstream, not in a packaging repository. See `etc/CONTRIBUTE` in the Emacs
tree; the bug tracker is <https://debbugs.gnu.org/>.
