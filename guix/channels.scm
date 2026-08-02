;;; SourceOS Guix channels — the Nix -> Guix migration spike.
;;;
;;; Two channels: upstream Guix, plus `nonguix` — Guix's analog of nixpkgs'
;;; `allowUnfree`. nonguix provides the real Linux kernel + firmware + CPU
;;; microcode + proprietary drivers/CUDA the estate's hardware needs. This is the
;;; SAME nonfree posture the estate already runs under nixpkgs + allowUnfree; the
;;; freedom stance is unchanged (we are NOT chasing the FSF/FSDG zero-blob badge).
;;;
;;; Reproducibility: PIN `commit` on both channels via `guix pull && guix describe`
;;; on the first Linux build runner, then commit the pinned result here. Real
;;; commit hashes cannot be fabricated offline — the branch pins below are only
;;; the spike starting point, not a reproducible pin.
;;;
;;; The nonguix `introduction` below is its PUBLISHED security bootstrap (the
;;; signing anchor). VERIFY it against the current nonguix README before the first
;;; pull — a wrong commit/fingerprint fails channel authentication by design.

(list (channel
        (name 'guix)
        (url "https://git.savannah.gnu.org/git/guix.git")
        (branch "master"))
      (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (branch "master")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5")))))
