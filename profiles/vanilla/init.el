;;; init.el --- Vanilla Emacs profile for EOR E2E testing -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Minimal emacs -Q config that bootstraps straight.el, installs
;; org-roam and endless-org-roam, then sets up two test instances.
;; Used by the E2E test runner in batch mode.
;;
;;; Code:

;; Override user-emacs-directory if EOR_EMACS_DIR is set, so
;; straight.el installs into an isolated location in CI.
(when (getenv "EOR_EMACS_DIR")
  (setq user-emacs-directory
        (file-name-as-directory (getenv "EOR_EMACS_DIR"))))

;; Bootstrap straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el"
                         user-emacs-directory))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Install dependencies
(straight-use-package 'org-roam)

;; Install EOR from local path (set via EOR_PACKAGE_DIR env var)
(let ((eor-dir (getenv "EOR_PACKAGE_DIR")))
  (when eor-dir
    (add-to-list 'load-path eor-dir)))

;; Require EOR
(require 'endless-org-roam)

;; Configure for testing
(setq eor-verbose t)

(message "[eor-test] Vanilla profile loaded")

(provide 'init)
;;; init.el ends here
