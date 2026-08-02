;;; SourceOS Guix workstation profile (x86_64) — Nix -> Guix migration spike.
;;;
;;; Demonstrates the nonfree posture: the real Linux kernel + `linux-firmware`
;;; + CPU `microcode-initrd` from nonguix (the `allowUnfree` equivalent), not
;;; `linux-libre`. This is the first parity target — a plain workstation image —
;;; before the two hard ones (Asahi/Apple-Silicon, CUDA model-serving node).
;;;
;;; Build on a LINUX runner with the channels in ../channels.scm applied:
;;;   guix time-machine -C guix/channels.scm -- \
;;;     system build   guix/system/workstation.scm     # realize the closure
;;;   guix time-machine -C guix/channels.scm -- \
;;;     system vm      guix/system/workstation.scm      # boot-test in a VM
;;; NOT buildable from macOS (needs the guix-daemon on Linux).

(use-modules (gnu)
             (nongnu packages linux)
             (nongnu system linux-initrd))
(use-service-modules desktop ssh)
(use-package-modules certs ssh version-control)

;; Define the layout once so the OS and the bootloader share the same object.
(define %keyboard-layout (keyboard-layout "us"))

(operating-system
  (host-name "sourceos-workstation")
  (timezone "UTC")
  (locale "en_US.utf8")
  (keyboard-layout %keyboard-layout)

  ;; nonguix: real Linux + firmware + CPU microcode (the allowUnfree equivalent).
  (kernel linux)
  (firmware (list linux-firmware))
  (initrd microcode-initrd)

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (targets '("/boot/efi"))
               (keyboard-layout %keyboard-layout)))

  (file-systems (append
                 (list (file-system
                         (mount-point "/")
                         (device (file-system-label "SOURCEOS_ROOT"))
                         (type "ext4"))
                       (file-system
                         (mount-point "/boot/efi")
                         (device (file-system-label "SOURCEOS_EFI"))
                         (type "vfat")))
                 %base-file-systems))

  (users (cons (user-account
                (name "sourceos")
                (comment "SourceOS operator")
                (group "users")
                (supplementary-groups '("wheel" "netdev" "audio" "video")))
               %base-user-accounts))

  (packages (append (list nss-certs git)
                    %base-packages))

  ;; openssh (keys only) prepended to the desktop stack (which already provides
  ;; NetworkManager / wpa-supplicant — do not re-declare them here).
  (services (cons* (service openssh-service-type
                            (openssh-configuration
                             (openssh openssh-sans-x)
                             (password-authentication? #f)))
                   %desktop-services)))
