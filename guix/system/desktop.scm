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
             (gnu packages)            ; specification->package (resolve by name)
             (nongnu packages linux)
             (nongnu system linux-initrd))
(use-service-modules desktop ssh docker)

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
                ;; `docker` group so the SociOS desktop's container workflow works.
                (supplementary-groups '("wheel" "netdev" "audio" "video" "docker")))
               %base-user-accounts))

  ;; The SociOS default desktop set (resolved by NAME so a missing package fails
  ;; cleanly on the runner). The menu / dock / monitors / web-search / consent UX
  ;; are the FIRST-CLASS owned SociOS shell (`sourceos-shell`), version-locked and
  ;; coherent — NOT third-party gnome-look extensions (see DESKTOP_COMPONENTS.md,
  ;; the 🔷 owned-shell build queue). So no ArcMenu/Vitals/dash-to-dock/plank here.
  (packages (append (map specification->package
                         '("nss-certs" "openssh"
                           "tilix"                 ; quake drop-down terminal
                           "gnome-tweaks"          ; native settings only
                           "icecat" "libreoffice" "gimp"
                           "redshift" "font-dejavu" "font-gnu-freefont"))
                    %base-packages))

  ;; Full GNOME on top of the desktop stack (%desktop-services provides gdm +
  ;; NetworkManager); Docker for the container workflow; openssh for headless
  ;; control from the Agent-S harness.
  (services (cons* (service gnome-desktop-service-type)
                   (service docker-service-type)
                   (service openssh-service-type
                            (openssh-configuration
                             (openssh (specification->package "openssh-sans-x"))))
                   %desktop-services)))
