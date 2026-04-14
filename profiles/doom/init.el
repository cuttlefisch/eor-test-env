;;; init.el --- Doom Emacs profile for EOR E2E testing -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Minimal Doom Emacs init.el for testing EOR.  This is loaded by
;; Doom's init system.  The corresponding packages.el declares
;; dependencies.
;;
;;; Code:

(doom! :completion
       vertico

       :ui
       doom

       :tools
       (lookup +docsets)

       :lang
       org)

;;; init.el ends here
