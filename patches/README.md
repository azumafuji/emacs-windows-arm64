# ARM64 patches

These four files are taken **unmodified** from the MSYS2 project, which is where
the Windows-on-ARM support for Emacs 31.1 came from. The Emacs 31.1 tree has
operating-system branches only for `i[3456]86-*-*` and `x86_64-*-*` in
`configure.ac`, so a plain checkout refuses to configure with:

```
configure: error: Emacs does not support 'aarch64-w64-mingw32' systems.
```

Upstream: <https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-emacs>
(The same files are listed in that package's `PKGBUILD`; the checksums below
match the ones published there.)

| File | SHA-256 |
| --- | --- |
| `001-clang-fixes.patch` | `d8732584a8f3bfd0badbd16d15384b7098e25c5df48632beb02d35f6050c358b` |
| `002-aarch64-fixes.patch` | `744620cb6c43c713120d5f43015d980aaf60910d9eef30180dbc920292785776` |
| `003-libtree-sitter-0.27.patch` | `e7936647b4de2e802cc972e06aa6a5a81d53545fe4cf58caf2573820ecfe7a99` |
| `emacs-ARM64.manifest` | `bfe64602dbeeec85799c1156ca4f3837fdac42a076e83a4221768db3417220e1` |

| File | Purpose |
| --- | --- |
| `001-clang-fixes.patch` | `nt/mingw-cfg.site`: forces `ac_cv_header_sys_wait_h=yes` so `sys/wait.h` from `nt/inc` is used with clang |
| `002-aarch64-fixes.patch` | `configure.ac`: adds `aarch64-*-*` to the MinGW host branch, `-mtune=cortex-a53`, ARM64 manifest and image base; `nt/emacs.rc.in`: selects the ARM64 manifest; `nt/inc/ms-w32.h` and `src/w32fns.c`: ARM64 stack-overflow recovery |
| `003-libtree-sitter-0.27.patch` | `lisp/term/w32-nt.el`: also probe `libtree-sitter-0.27.dll` |
| `emacs-ARM64.manifest` | Copied to `nt/`; the ARM64 application manifest embedded into `emacs.exe` |

`scripts/02-apply-patches.sh` verifies every checksum before applying anything,
so a corrupted or substituted file is caught immediately.

If you are reading this because you want ARM64 support in upstream Emacs rather
than in a packaging repository: the change itself is small and the maintainers
would want it submitted properly (see `etc/CONTRIBUTE` in the Emacs tree), not
carried forever as an out-of-tree patch.
