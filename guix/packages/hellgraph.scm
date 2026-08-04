;;; SourceOS Guix package — HellGraph graph engine.
;;;
;;; Parity target for packages/hellgraph/default.nix.
;;; HellGraph ships a committed, self-contained `ts/dist` with zero runtime
;;; npm dependencies — the daemon runs on `node` alone. We install bin/ + ts/
;;; preserving the relative layout (bin/*.mjs → ../ts/dist/index.mjs) and
;;; wrap the two public entrypoints.
;;;
;;; Build:
;;;   guix time-machine -C guix/channels.scm -- \
;;;     build -f guix/packages/hellgraph.scm

(define-module (sourceos packages hellgraph)
  #:use-module (guix packages)
  #:use-module (guix build-system copy)
  #:use-module (guix licenses)
  #:use-module (gnu packages node))

(define-public hellgraph
  (package
   (name "hellgraph")
   (version "0.1.0")
   ;; Source is the hellgraph repo's top-level (bin/ + ts/ are the install targets).
   ;; The caller substitutes the actual origin (local or git fetch) when building.
   (source #f)
   (build-system copy-build-system)
   (arguments
    `(#:install-plan
      '(("bin" "libexec/hellgraph/bin")
        ("ts"  "libexec/hellgraph/ts"))
      #:phases
      (modify-phases %standard-phases
        (add-after 'install 'wrap-entrypoints
          (lambda* (#:key inputs outputs #:allow-other-keys)
            (let* ((out   (assoc-ref outputs "out"))
                   (node  (string-append (assoc-ref inputs "node") "/bin/node"))
                   (lib   (string-append out "/libexec/hellgraph")))
              (for-each
               (lambda (ep)
                 (let ((wrapper (string-append out "/bin/" ep))
                       (target  (string-append lib "/bin/" ep ".mjs")))
                   (mkdir-p (string-append out "/bin"))
                   (call-with-output-file wrapper
                     (lambda (p)
                       (format p "#!/bin/sh\nexec ~a ~a \"$@\"\n" node target)))
                   (chmod wrapper #o755)))
               '("hellgraph-superpeer" "hellgraph-agent-ingest")))
            #t)))))
   (inputs
    (list node))
   (synopsis "HellGraph AtomSpace graph engine — always-on local graph service")
   (description
    "HellGraph serves the canonical graph over HTTP (local-only by default;
p2p superpeer mode opt-in via HELLGRAPH_BOOTSTRAP_KEY).  Ships a committed,
pre-built @code{ts/dist} with no npm runtime dependencies.")
   (license expat)))
