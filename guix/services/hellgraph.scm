;;; SourceOS Guix service — HellGraph always-on graph service.
;;;
;;; Parity target for modules/nixos/hellgraph/default.nix.
;;; Creates a shepherd service (Guix's init-service abstraction) that mirrors
;;; the NixOS module: local-only by default, p2p superpeer opt-in via a
;;; credential file, extra environment passthrough.
;;;
;;; Usage in a system config:
;;;   (use-modules (sourceos services hellgraph))
;;;   ...
;;;   (services (cons* (service hellgraph-service-type
;;;                             (hellgraph-configuration
;;;                              (hellgraph hellgraph-pkg)
;;;                              (superpeer? #f)))
;;;                    %base-services))

(define-module (sourceos services hellgraph)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (ice-9 match)
  #:export (hellgraph-configuration
            hellgraph-service-type))

;;; Configuration record — mirrors the NixOS module options.
(define-record-type* <hellgraph-configuration>
  hellgraph-configuration
  make-hellgraph-configuration
  hellgraph-configuration?
  ;; The hellgraph package (must export hellgraph-superpeer in bin/).
  (hellgraph             hellgraph-configuration-hellgraph)
  ;; OPT-IN: join the p2p superpeer mesh. Default off — sovereign local graph.
  (superpeer?            hellgraph-configuration-superpeer?
                         (default #f))
  ;; Path to a file holding HELLGRAPH_BOOTSTRAP_KEY when superpeer? is #t.
  ;; The service reads it at start so the key never appears in the environment
  ;; of the process table.
  (bootstrap-key-file    hellgraph-configuration-bootstrap-key-file
                         (default #f))
  ;; Extra environment variables forwarded to hellgraph-superpeer
  ;; (e.g. port/store overrides).
  (extra-environment     hellgraph-configuration-extra-environment
                         (default '())))

;;; Build the shepherd service from the configuration.
(define (hellgraph-shepherd-service config)
  (match-record config <hellgraph-configuration>
    (hellgraph superpeer? bootstrap-key-file extra-environment)
    (list
     (shepherd-service
      (documentation "HellGraph always-on graph service (local-only; p2p superpeer opt-in)")
      (provision '(hellgraph))
      (requirement '(networking))
      (start
       #~(make-forkexec-constructor
          (list (string-append #$hellgraph "/bin/hellgraph-superpeer"))
          #:environment-variables
          (append
           '#$extra-environment
           (if '#$superpeer?
               (if '#$bootstrap-key-file
                   (list (string-append "HELLGRAPH_BOOTSTRAP_KEY="
                                        (call-with-input-file
                                            '#$bootstrap-key-file
                                          (lambda (p) (string-trim-right
                                                       (get-string-all p))))))
                   '())
               (list "HELLGRAPH_SUPERPEER_DISABLED=1")))))
      (stop #~(make-kill-destructor))))))

(define hellgraph-service-type
  (service-type
   (name 'hellgraph)
   (extensions
    (list (service-extension shepherd-root-service-type
                             hellgraph-shepherd-service)))
   (description "Run the HellGraph graph engine as an always-on system service.")))
