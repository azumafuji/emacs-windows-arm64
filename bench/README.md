# Benchmarks

`workloads.el` defines twelve workloads plus a start-up measurement, and
`run-benchmarks.sh` runs them across several builds.

```
bash bench/run-benchmarks.sh 7
```

By default it compares `work/build-portable` and `work/build-native`;
pass `BENCH_BINS` to compare anything else, for example an unoptimised
reference build:

```
BENCH_BINS="reference=work/build-ref/src/emacs.exe portable=work/build-portable/src/emacs.exe" \
  bash bench/run-benchmarks.sh 7
```

Results land in `results.csv` (every timed run) and `summary.csv`.

Method, measured results and the reasoning behind them are in
[../docs/BENCHMARKS.md](../docs/BENCHMARKS.md). The short version: the optimised
builds are roughly 3-4% faster on C-heavy work, and that is smaller than the
run-to-run noise, so compare medians of paired repetitions and never single runs.
