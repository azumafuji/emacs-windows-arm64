;;; workloads.el --- benchmark workloads for comparing Emacs builds  -*- lexical-binding: t; -*-
;;
;; Deliberately loads no Lisp libraries (no `require'): every workload calls only
;; functions that are already inside the dumped executable, so the comparison is
;; purely about the compiled C code and not about which load-path a binary can
;; find.
;;
;; Usage:
;;   emacs -Q --batch -l workloads.el --eval '(bench-run "regex")'
;;
;; Output: one machine-readable line,  BENCH <name> <seconds>
;;
;; C-core workloads (regex base64 json sort gc strings replace hash read coding)
;; spend their time inside C: the regex engine, the base64 and JSON coders,
;; qsort, the allocator and garbage collector, the string primitives, the GMP
;; hash tables, the Lisp reader and the coding-system converters. Those are what a C compiler
;; can improve.
;;
;; Lisp workloads (lisp-fib lisp-loop) spend their time in the byte-code
;; interpreter, which is fixed machine code already in the binary: changing the C
;; compiler does not change its speed. They are the control group.

(defun bench--regex ()          ; regex engine (regexp.c)
  (dotimes (_ 800000)
    (string-match-p "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+" "user.name+tag@example.co.uk")))

(defun bench--base64 ()         ; base64 encode/decode (fns.c)
  (let ((s (make-string 4096 ?x)))
    (dotimes (_ 20000) (base64-decode-string (base64-encode-string s)))))

(defun bench--json ()           ; JSON parser (json.c)
  (let ((j "{\"a\":[1,2,3,4,5],\"b\":{\"c\":\"dddd\",\"e\":true},\"f\":null}"))
    (dotimes (_ 150000) (json-parse-string j))))

(defun bench--sort ()           ; qsort over large vectors (sort.c)
  (dotimes (_ 20) (sort (mapcar #'random (make-list 200000 1000)) #'<)))

(defun bench--gc ()             ; allocation + garbage collector (alloc.c)
  (dotimes (_ 1500) (make-vector 10000 1)))

(defun bench--strings ()        ; string primitives (fns.c)
  (dotimes (_ 400000)
    (let ((s (concat "abc" "def" (number-to-string 42))))
      (substring s 1 8) (upcase s))))

(defun bench--replace ()        ; replace-regexp-in-string (search.c + fns.c)
  (dotimes (_ 40000)
    (replace-regexp-in-string "[aeiou]" "_" "the quick brown fox jumps over the lazy dog")))

(defun bench--hash ()           ; hash tables + string allocation (fns.c)
  (let ((h (make-hash-table :test 'equal)))
    (dotimes (i 400000) (puthash (number-to-string i) i h))))

(defun bench--read ()           ; Lisp reader (lread.c)
  (dotimes (_ 300000) (read-from-string "(a b c (d e) 1 2 3 \"str\")")))

(defun bench--coding ()         ; coding-system conversion (coding.c)
  (let ((s (make-string 20000 ?a)))
    (dotimes (_ 3000) (decode-coding-string (encode-coding-string s 'utf-8) 'utf-8))))

(defun bench--fib (n) (if (< n 2) n (+ (bench--fib (- n 1)) (bench--fib (- n 2)))))
(defun bench--lisp-fib ()       ; pure byte-code interpretation
  (bench--fib 30))

(defun bench--lisp-loop ()      ; pure byte-code interpretation
  (let ((s 0)) (dotimes (i 3000000) (setq s (+ s i))) s))

(defconst bench-workloads
  '(("regex"     . bench--regex)     ("base64"   . bench--base64)
    ("json"      . bench--json)      ("sort"     . bench--sort)
    ("gc"        . bench--gc)        ("strings"  . bench--strings)
    ("replace"   . bench--replace)   ("hash"     . bench--hash)
    ("read"      . bench--read)
    ("coding"    . bench--coding)    ("lisp-fib" . bench--lisp-fib)
    ("lisp-loop" . bench--lisp-loop) ("startup"  . ignore)))

(defun bench-run (name)
  "Run workload NAME once and print BENCH <name> <seconds>."
  (if (equal name "startup")
      (princ (format "BENCH %s 0.0000\n" name))
    (let ((fn (cdr (assoc name bench-workloads))))
      (unless fn (error "unknown workload: %s" name))
      (let ((t0 (float-time)))
        (funcall fn)
        (princ (format "BENCH %s %.4f\n" name (- (float-time) t0)))))))
