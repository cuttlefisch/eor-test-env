;;; config.el --- Doom Emacs config for EOR E2E testing -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Minimal Doom config that enables org-roam and EOR for testing.
;;
;;; Code:

(use-package! org-roam
  :config
  (setq org-roam-verbose nil))

(use-package! endless-org-roam
  :after org-roam
  :config
  (eor-mode 1)
  (setq eor-verbose t))

(message "[eor-test] Doom profile loaded")

;;; config.el ends here
