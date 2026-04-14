;;; .spacemacs --- Spacemacs config for EOR E2E testing -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Minimal Spacemacs dotfile for testing EOR.  Only loads the org layer
;; with org-roam backend plus EOR.
;;
;;; Code:

(defun dotspacemacs/layers ()
  (setq-default
   dotspacemacs-distribution 'spacemacs-base
   dotspacemacs-enable-lazy-installation nil
   dotspacemacs-ask-for-lazy-installation nil
   dotspacemacs-configuration-layer-path '()
   dotspacemacs-configuration-layers
   '(emacs-lisp
     (org :variables
          org-enable-roam-support t))
   dotspacemacs-additional-packages
   '((endless-org-roam :location local))
   dotspacemacs-frozen-packages '()
   dotspacemacs-excluded-packages '()
   dotspacemacs-install-packages 'used-only))

(defun dotspacemacs/init ()
  (setq-default
   dotspacemacs-startup-banner nil
   dotspacemacs-startup-lists nil
   dotspacemacs-themes '(spacemacs-dark)
   dotspacemacs-mode-line-theme 'spacemacs))

(defun dotspacemacs/user-init ()
  (let ((eor-dir (getenv "EOR_PACKAGE_DIR")))
    (when eor-dir
      (add-to-list 'load-path eor-dir))))

(defun dotspacemacs/user-config ()
  (require 'endless-org-roam)
  (eor-mode 1)
  (setq eor-verbose t)
  (message "[eor-test] Spacemacs profile loaded"))

;;; .spacemacs ends here
