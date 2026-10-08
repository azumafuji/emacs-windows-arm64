# Benchmark results: impact of C optimisation on the Emacs runtime

Companion to BUILD.md. Purpose: show, reproducibly, where compiler optimisation
actually helps an Emacs build and where it does not.

Machine: Windows 11 on ARM64, Snapdragon X2 Elite Extreme (X2E94100, Qualcomm Oryon)
Emacs: GNU Emacs 31.1, aarch64-w64-mingw32, toolchain clang 22.1.8 + lld (MSYS2 CLANGARM64)

---

## 1. The three binaries compared

| Key | Binary | CFLAGS | LDFLAGS | configure extras |
| --- | --- | --- | --- | --- |
| reference-O2 | an unoptimised reference build (see below) | `-O2 -pipe -Wno-incompatible-pointer-types` | `-lpthread` | -- |
| portable-lto | work/build-portable/src/emacs.exe | `-O2 -pipe -Wno-incompatible-pointer-types -fno-omit-frame-pointer -march=armv8-a -mtune=cortex-a76 -flto=thin` | `-flto=thin -fuse-ld=lld -lpthread` | `--disable-gc-mark-trace` |
| native-lto | work/build-native/src/emacs.exe | same as portable but `-mcpu=native` instead of `-march=armv8-a -mtune=cortex-a76` | same | `--disable-gc-mark-trace` |

The reference also received `-mtune=cortex-a53` through CPPFLAGS (MSYS2's patch),
so the portable and native builds differ from it in three ways at once: ThinLTO,
the tuning target, and the disabled GC mark trace. That is what "optimised build"
means here; it is not a single-flag experiment.

All three are *build-tree* binaries with the same Lisp and the same dump contents,
so the only difference being measured is compiled C code.

## 2. Method

**Timing.** Each workload times itself from inside Emacs with `float-time` and
prints `BENCH <name> <seconds>`. Internal timing excludes process start-up,
which is measured separately with the external wall clock.

**Workloads.** Twelve workloads plus a start-up measurement. Ten are deliberately
C-heavy so that a change in compiler code generation has something to act on; two
are pure byte-code and act as a control.

| Workload | What it exercises | approx. duration |
| --- | --- | --- |
| regex | regex engine (regexp.c) | 0.50 s |
| strings | string primitives: concat, substring, upcase (fns.c) | 0.62 s |
| replace | replace-regexp-in-string (search.c + fns.c) | 0.53 s |
| json | JSON parser (json.c) | 0.53 s |
| base64 | base64 encode + decode (fns.c) | 1.03 s |
| coding | coding-system conversion (coding.c) | 0.56 s |
| hash | hash tables + string allocation (fns.c) | 0.13 s |
| read | Lisp reader (lread.c) | 0.46 s |
| sort | qsort over large vectors (sort.c) | 0.72 s |
| gc | allocation + garbage collector (alloc.c) | 0.53 s |
| lisp-fib | recursive fib, pure byte-code -- control group | 0.63 s |
| lisp-loop | tight arithmetic loop, pure byte-code -- control group | 0.79 s |
| startup | process start + dump load, measured externally | 0.17 s |

**Protocol.**

* 7 timed repetitions per (workload, build), plus one discarded warm-up pass.
* **Builds are interleaved**: within each repetition the three binaries run
  back to back, in the same order, for the same workload. CPU frequency drift,
  background load and cache state therefore hit all three roughly equally. This
  matters: an earlier, non-interleaved run produced a spurious -8.9% for the
  native build, which the interleaved run does not reproduce.
* The statistic reported is the **median of the per-repetition ratios**
  (portable/reference and native/reference for the same repetition). Pairing
  cancels slow drift; using the median discards outliers.
* `EMACSLOADPATH` is set to the same directory for all three binaries, so the
  comparison cannot depend on which build happens to find a Lisp directory.

**Reading the "ref spread" column.** It is `(max-min)/median` of the reference
build across its 7 runs, i.e. the run-to-run noise floor. Note that for several
workloads (base64 15%, gc 14%, lisp-loop 12%) **the noise is larger than the
effect being measured**. That is the single most important thing to take from
this document: you cannot see a 3% difference in a single run. Every conclusion
below rests on medians over paired repetitions.

## 3. Results

Median-of-paired-ratios gain versus the reference; negative is faster.

| Workload | What it exercises | reference -O2 (s) | portable (s) | native (s) | portable gain | native gain | ref spread |
| --- | --- | --- | --- | --- | --- | --- | --- |
| regex | regex engine (regexp.c) | 0.495 | 0.488 | 0.481 | -2.5% | -3.1% | 5% |
| strings | string primitives: concat/substring/upcase (fns.c) | 0.621 | 0.610 | 0.599 | -2.4% | -2.9% | 3% |
| replace | replace-regexp-in-string (search.c + fns.c) | 0.533 | 0.506 | 0.500 | -3.6% | -6.3% | 9% |
| json | JSON parser (json.c) | 0.532 | 0.510 | 0.509 | -4.2% | -3.5% | 4% |
| base64 | base64 encode/decode (fns.c) | 1.028 | 0.990 | 0.987 | -3.8% | -4.3% | 15% |
| coding | coding-system conversion (coding.c) | 0.565 | 0.553 | 0.552 | -4.1% | -1.6% | 5% |
| hash | hash tables + string allocation (fns.c) | 0.134 | 0.128 | 0.125 | -4.3% | -5.4% | 5% |
| read | Lisp reader (lread.c) | 0.455 | 0.443 | 0.436 | -5.3% | -4.2% | 7% |
| sort | qsort over large vectors (sort.c) | 0.716 | 0.709 | 0.704 | -0.7% | -1.4% | 8% |
| gc | allocation + garbage collector (alloc.c) | 0.533 | 0.506 | 0.517 | -4.5% | -4.3% | 14% |
| lisp-fib | recursive fib, pure byte-code (control) | 0.629 | 0.602 | 0.610 | -4.8% | -3.3% | 11% |
| lisp-loop | tight loop, pure byte-code (control) | 0.793 | 0.754 | 0.753 | -5.2% | -4.9% | 12% |
| startup | process start + dump load (external wall clock) | 0.167 | 0.173 | 0.160 | +3.9% | -4.0% | 15% |

Geometric mean over the ten C-core workloads:

* **portable: -3.6%**
* **native: -3.7%**

Absolute medians in seconds are in the table; every individual run is in
`results.csv` (273 rows) and the per-build statistics in `summary.csv`.

## 4. Interpretation

**The C core does get faster, but by a few percent, not tens of percent.** The
measured gains run from 0.7% (sort) to 5.3% (read), with the geometric mean
around -3.6%. Workloads dominated by string/list handling, the
Lisp reader, hashing and GC show the clearest improvement; qsort and the regex
engine barely move, presumably because they are small, already-tight loops whose
time goes into memory traffic rather than instruction count.

**The byte-code control group improved too (lisp-fib, lisp-loop, 3-5%).** This is
not a mistake: the byte-code interpreter (%exec_byte_code% in bytecode.c) is
itself compiled C code, so optimising it speeds up interpreted Lisp as well. The
control group is therefore *not* a true negative control; a true control would be
time spent inside prebuilt DLLs, which our flags cannot touch.

**ThinLTO is doing real work.** It is confirmed active (object files are LLVM
bitcode) and it is the most likely source of the cross-cutting improvement, since
it enables inlining between translation units -- Emacs is heavily modular, so
cross-module inlining of small accessors is exactly what helps.

**The native build is not meaningfully faster than the portable one** on this
suite (-3.7% vs -3.6%, within noise). Its SVE2/SME/i8mm/bf16
extensions only pay off on vectorisable code, and these workloads are mostly
scalar pointer-chasing. The consequence is a real trade-off: the native build is
restricted to this CPU generation and bought nothing measurable here. **For
general distribution the portable build is the better choice.** If you want to
look for a case where native wins, target large bulk data movement -- base64,
coding conversion and case conversion on multi-megabyte strings, or
`string-distance`/`compare-strings` on long inputs -- where auto-vectorisation
can engage.

**Start-up is unchanged** (0.167 s reference vs 0.173 s portable vs 0.160 s
native; the reference spread is 15%, so these are indistinguishable). This is
expected: the dump is data, and the binary is already demand-paged.

**Cost: the binaries are bigger.** 3,782 KB reference, 4,556 KB portable,
4,640 KB native. The growth is mostly `-fno-omit-frame-pointer`, an Emacs
developer recommendation for debuggability, not a performance flag. If binary
size matters more than crash backtraces, drop it and expect the sizes to
converge.

**Bottom line.** For an editor, a 3-4% improvement in the C core is a real but
modest win, and it is invisible in casual use. The bigger levers on this platform
are unavailable (native Lisp compilation needs libgccjit, which does not exist
for clangarm64) or unmeasured here (PGO, see section 7).

## 5. Reproducing this

The **reference** column is an unoptimised build: same source and configure line,
but plain `-O2 -pipe -Wno-incompatible-pointer-types` CFLAGS, no LTO and no
`--disable-gc-mark-trace`. To produce one, run `scripts/03-build.sh`
after temporarily overriding the flags, or ignore that column and compare
`portable` with `native`, which needs no extra build.

Everything lives in bench/. The binaries must be able to find
their DLLs, so run from a CLANGARM64 shell.

Full suite, 7 repetitions (about 4 minutes):

```
bash bench/run-benchmarks.sh 7
```

Single workload, single build, one run:

```
EMACSLOADPATH=D:/emacs/lisp \
  work/build-portable/src/emacs.exe -Q --batch \
  -l bench/workloads.el \
  --eval '(bench-run "regex")'
```

It prints one line: `BENCH regex 0.4871`.

Files it reads and writes:

| File | Contents |
| --- | --- |
| workloads.el | The workloads and the `bench-run` entry point |
| run-benchmarks.sh | The driver (interleaving, warm-up, statistics) |
| results.csv | One row per timed run: workload, build, rep, seconds |
| summary.csv | Per workload+build: reps, min, median, max, mean |
| run.log | Output of the last suite run |
| benchmark doc | This file (also copied to docs/BENCHMARKS.md) |

To add your own workload, append a function to `workloads.el`, add a
`. bench--yourname` entry to `bench-workloads`, and add the name to the
`WORKLOADS` line in `run-benchmarks.sh`. Keep it between roughly 0.3 s and
1.5 s: much shorter and the timer and cache state dominate.

For trustworthy numbers: run on AC power, close other applications, keep the
machine otherwise idle, and compare medians, never single runs.

## 6. Pitfalls worth knowing (all encountered while building this suite)

| Symptom | Cause |
| --- | --- |
| `Cannot open load file: rx` for one build only | The reference binary was copied out of its build tree and cannot find the installed Lisp directory. Setting `-L` or `EMACSLOADPATH` identically for every binary removes the difference. Better: use only functions that are already in the dump, so no Lisp is loaded at all |
| `void-function: factorial` | Emacs has no `factorial` function. Check that a primitive exists before building a workload on it |
| `Arithmetic overflow error` from `expt` and from `( * b b )` | Emacs refuses to build bignums beyond a size limit, so GMP workloads are hard to size this way |
| A GMP workload measures nothing | The expensive code is in the *prebuilt* `libgmp-10.dll`. Your flags never touched it. Any workload whose time is spent in a dependency DLL is blind to your optimisation |
| Results look erratic, gains appear and vanish | Run-to-run noise here reaches 15%, larger than the effect. Interleave the builds, discard a warm-up pass, and use medians of paired repetitions |
| A CSV header ends up at the bottom | Sorting a CSV that still contains its header line. Sort the data, then prepend the header |

## 7. If you want to go further

* **PGO** is the remaining significant C-level lever: build with
  `-fprofile-generate`, run a training workload that resembles real editing
  (start-up, load packages, byte-compile, visit large files), `llvm-profdata
  merge`, then rebuild with `-fprofile-use`. Expect roughly another 10% on
  C-heavy paths. Because the effect is larger, it is also easier to measure --
  you should not need paired ratios to see it.
* **Native Lisp compilation** would dwarf all of this, but needs libgccjit and
  is unavailable for clangarm64 (MSYS2 disables it for all CLANG* environments).
* **Real-world validation.** These are synthetic microbenchmarks. If you want to
  know whether the build feels faster, measure something you actually do: opening
  a large file, running a package-heavy start-up, byte-compiling a big project.
  Record wall time, repeat, and compare medians.
