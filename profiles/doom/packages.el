;;; packages.el --- Doom Emacs packages for EOR E2E testing -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Declares org-roam and endless-org-roam for Doom's package manager.
;;
;;; Code:

(package! org-roam)

;; Install EOR from local path
(package! endless-org-roam
  :recipe (:local-repo nil  ; overridden by EOR_PACKAGE_DIR at runtime
           :files ("*.el")))

;;; packages.el ends here
