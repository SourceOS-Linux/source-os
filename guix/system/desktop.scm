;;; SourceOS Guix desktop image (x86_64) — the Agent-S GUI test target.
;;;
;;; A GNOME desktop built from Guix + nonguix (real kernel/firmware/microcode),
;;; produced as a bootable qcow2 that Agent-S drives (open Activities, launch
;;; Files, see a window). This is the Guix equivalent of the Nix
;;; `sourceos-image-qcow2-desktop` the Agent-S Layer-2 harness consumes today.
;;;
;;; Build the image on a Linux runner (NOT macOS):
;;;   guix time-machine -C guix/channels.scm -- \
;;;     system image -t qcow2 guix/system/desktop.scm     # -> a bootable .qcow2
;;; then feed it to tests/agent-s (local or cloud) via tests/agent-s/run-guix.sh.
;;;
;;; NOTE for Agent-S: the login manager must AUTOLOGIN so the agent lands on a
;;; live desktop over VNC. gdm autologin is a small modify-services tweak added
;;; when this profile is first realised on a runner (kept out here until it can
;;; be build-validated — a wrong gdm-configuration would silently break the test).

(use-modules (gnu)
             (nongnu packages linux)
             (nongnu system linux-initrd))
(use-service-modules desktop ssh)
(use-package-modules certs ssh)

(define %keyboard-layout (keyboard-layout "us"))

(operating-system
  (host-name "sourceos-desktop")
  (timezone "UTC")
  (locale "en_US.utf8")
  (keyboard-layout %keyboard-layout)

  ;; nonguix: real Linux + firmware + microcode (the allowUnfree equivalent).
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

  (packages (append (list nss-certs) %base-packages))

  ;; Full GNOME on top of the desktop stack (%desktop-services provides gdm +
  ;; NetworkManager); openssh for headless control from the harness.
  (services (cons* (service gnome-desktop-service-type)
                   (service openssh-service-type
                            (openssh-configuration (openssh openssh-sans-x)))
                   %desktop-services)))
