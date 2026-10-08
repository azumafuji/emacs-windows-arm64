#!/usr/bin/env bash
# Compare several Emacs builds on a fixed set of workloads.
#
#   bash bench/run-benchmarks.sh [repetitions]        (default 7)
#
# Which binaries to compare, as label=path pairs. The FIRST is the reference that
# the others are reported against. Override with BENCH_BINS.
#
#   BENCH_BINS="reference=work/build-ref/src/emacs.exe portable=work/build-portable/src/emacs.exe" \
#     bash bench/run-benchmarks.sh 7
#
# Protocol: builds are interleaved within each repetition so CPU frequency drift
# and background load affect all of them equally; one warm-up pass is discarded;
# the reported gain is the median of the per-repetition ratios, which cancels
# slow drift and discards outliers. Run-to-run noise on this machine reaches 15%
# on some workloads, so never compare single runs.
set -u
REPS="${1:-7}"
DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
EL="$DIR/workloads.el"
CSV="$DIR/results.csv"
SUM="$DIR/summary.csv"

if [ -n "${BENCH_BINS:-}" ]; then
  read -r -a SPECS <<< "$BENCH_BINS"
else
  SPECS=(
    "portable=$ROOT/work/build-portable/src/emacs.exe"
    "native=$ROOT/work/build-native/src/emacs.exe"
  )
fi

declare -A BINS=()
LABELS=()
for spec in "${SPECS[@]}"; do
  label="${spec%%=*}"; path="${spec#*=}"
  [ -x "$path" ] || { echo "missing binary for $label: $path" >&2; exit 1; }
  BINS[$label]="$path"; LABELS+=("$label")
done
REF="${LABELS[0]}"
echo "reference: $REF (${BINS[$REF]})"

WORKLOADS="regex base64 json sort gc strings replace hash read coding lisp-fib lisp-loop startup"

# Same load-path for every binary so the comparison cannot depend on which build
# happens to find the source Lisp tree on its own.
export EMACSLOADPATH="${EMACSLOADPATH:-$ROOT/work/emacs/lisp}"

run_one() {
  local w="$1" label="$2" exe="${BINS[$2]}" s e out secs
  s=$(date +%s.%N)
  out=$("$exe" -Q --batch -l "$EL" --eval "(bench-run \"$w\")" 2>/dev/null | tr -d '\r')
  e=$(date +%s.%N)
  if [ "$w" = "startup" ]; then
    secs=$(awk -v a="$s" -v b="$e" 'BEGIN{printf "%.4f", b-a}')
  else
    secs=$(printf '%s\n' "$out" | awk '/^BENCH /{print $3}')
  fi
  [ -z "$secs" ] && secs=NA
  printf '%s' "$secs"
}

echo "workload,label,rep,seconds" > "$CSV"
for w in $WORKLOADS; do
  for label in "${LABELS[@]}"; do run_one "$w" "$label" >/dev/null; done
  for i in $(seq 1 "$REPS"); do
    for label in "${LABELS[@]}"; do
      echo "$w,$label,$i,$(run_one "$w" "$label")" >> "$CSV"
    done
  done
done

# Per-repetition ratio against the reference (paired), then median of those.
awk -F, -v ref="$REF" '
  NR==1 { next }
  $4=="NA" { next }
  { key=$1; if ($2==ref) { r[key][$3]=$4 } else { v[key][$2][$3]=$4 } }
  END {
    print "workload,label,reps,median_s,gain_vs_" ref
    for (w in v)
      for (l in v[w]) {
        n=0; delete ratio
        for (rep in v[w][l]) if (rep in r[w] && r[w][rep]+0>0) { ratio[++n]=v[w][l][rep]/r[w][rep] }
        if (n==0) continue
        for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (ratio[i]>ratio[j]) { t=ratio[i]; ratio[i]=ratio[j]; ratio[j]=t }
        med = (n%2) ? ratio[(n+1)/2] : (ratio[n/2]+ratio[n/2+1])/2
        # median absolute time for this label
        m=0; delete abs
        for (rep in v[w][l]) abs[++m]=v[w][l][rep]
        for (i=1;i<=m;i++) for (j=i+1;j<=m;j++) if (abs[i]>abs[j]) { t=abs[i]; abs[i]=abs[j]; abs[j]=t }
        amed = (m%2) ? abs[(m+1)/2] : (abs[m/2]+abs[m/2+1])/2
        printf "%s,%s,%d,%.4f,%+.1f%%\n", w, l, m, amed, (med-1)*100
      }
  }' "$CSV" | { read -r h; echo "$h"; sort -t, -k1,1 -k2,2; } > "$SUM"

echo "wrote $CSV and $SUM"
column -s, -t "$SUM"
