GNU Emacs **31.1** for **Windows on ARM64** (aarch64), built by CI from commit `a55a70f5ec361f62de7c42a12cbeebd410126988`.

### What this is

Emacs upstream does not support `aarch64-w64-mingw32`, so this is the official
[emacs-31.1 release](https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz) with the four
MSYS2 ARM64 patches applied, built with the MSYS2 **CLANGARM64** toolchain
(clang 22, lld, ThinLTO) and packaged with every runtime library bundled.

### Downloads

| File | Use |
| --- | --- |
| `emacs-31.1-aarch64-portable.zip` | **Recommended.** Extract anywhere, run `bin\\runemacs.exe`. Runs on any Windows on ARM64 PC. |
| `emacs-31.1-aarch64-setup.exe` | Installer for the same build: Start Menu entries, optional PATH entry, uninstaller. |
| `emacs-31.1-aarch64-native-portable.zip` | Built with `-mcpu=native` on the CI machine's CPU. **Not portable** - may not start on other ARM64 machines. |
| `emacs-31.1-aarch64-native-setup.exe` | Installer for the native build. |
| `BUILD-INFO.txt`, `PACKAGES.txt` | Toolchain, date and the exact MSYS2 package versions used. |

Requires 64-bit ARM Windows. It will not run on x86-64.

### Notes

* **No native Lisp compilation.** `libgccjit` does not exist for clangarm64, so Lisp is byte-compiled only.
* Optimised builds are ~3-4% faster than a plain `-O2` build on C-heavy work (see `docs/BENCHMARKS.md`).
* **Unsigned binaries** - expect SmartScreen warnings.
* TIFF works via GDI+; XPM is unavailable.

Binaries are GPL-3.0-or-later; each archive contains `COPYING` and `SOURCE-CODE.txt`.
The patches come from [msys2/MINGW-packages](https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-emacs).
