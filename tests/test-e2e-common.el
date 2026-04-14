;;; test-e2e-common.el --- E2E test framework for EOR -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Provides the E2E test runner and assertion framework.  This file is
;; loaded after the profile init.el and runs all E2E test suites.
;;
;; Unlike unit tests (which mock org-roam), E2E tests use real org-roam
;; databases built from fixture files.
;;
;;; Code:

(require 'endless-org-roam)
(require 'endless-org-roam-registry)
(require 'endless-org-roam-link)
(require 'endless-org-roam-transport)

;;; Test Framework

(defvar eor-e2e--pass-count 0 "Number of passing assertions.")
(defvar eor-e2e--fail-count 0 "Number of failing assertions.")
(defvar eor-e2e--test-name "" "Current test name for reporting.")

(defun eor-e2e--reset-registry ()
  "Reset registry state for a fresh test.
Deletes the registry file and clears in-memory state."
  (when (and eor-registry-file (file-exists-p eor-registry-file))
    (delete-file eor-registry-file))
  (setq eor--registry nil
        eor--registry-loaded-p nil))

(defmacro eor-e2e-deftest (name docstring &rest body)
  "Define an E2E test named NAME with DOCSTRING and BODY.
Each test starts with a fresh registry."
  (declare (indent 2) (debug t) (doc-string 2))
  `(defun ,(intern (concat "eor-e2e-test-" (symbol-name name))) ()
     ,docstring
     (setq eor-e2e--test-name ,(symbol-name name))
     (message "\n  TEST: %s" eor-e2e--test-name)
     (eor-e2e--reset-registry)
     (condition-case err
         (progn ,@body)
       (error
        (cl-incf eor-e2e--fail-count)
        (message "  FAIL: %s -- %s" eor-e2e--test-name
                 (error-message-string err))))))

(defun eor-e2e-assert (condition msg)
  "Assert that CONDITION is non-nil, reporting MSG on failure."
  (if condition
      (progn
        (cl-incf eor-e2e--pass-count)
        (message "    PASS: %s" msg))
    (cl-incf eor-e2e--fail-count)
    (message "    FAIL: %s" msg)))

(defun eor-e2e-assert-equal (actual expected msg)
  "Assert ACTUAL equals EXPECTED, reporting MSG."
  (eor-e2e-assert (equal actual expected)
                   (format "%s (expected: %S, got: %S)"
                           msg expected actual)))

(defun eor-e2e-assert-file-exists (path msg)
  "Assert that PATH exists as a file."
  (eor-e2e-assert (file-exists-p path)
                   (format "%s (%s)" msg path)))

;;; Test Environment Setup

(defvar eor-e2e--work-dir nil "Working directory for current test run.")

(defun eor-e2e--setup ()
  "Set up the E2E test environment."
  (setq eor-e2e--work-dir (or (getenv "EOR_WORK_DIR")
                               (make-temp-file "eor-e2e" t)))
  (setq eor-e2e--pass-count 0
        eor-e2e--fail-count 0)
  ;; Fresh registry for each run
  (setq eor-registry-file
        (expand-file-name "eor-registry.el" eor-e2e--work-dir))
  (setq eor--registry nil
        eor--registry-loaded-p nil)
  (message "\n=== EOR E2E Test Suite ===")
  (message "Work dir: %s" eor-e2e--work-dir))

(defun eor-e2e--teardown ()
  "Print results and exit with appropriate code."
  (message "\n=== Results: %d passed, %d failed ==="
           eor-e2e--pass-count eor-e2e--fail-count)
  (kill-emacs (if (> eor-e2e--fail-count 0) 1 0)))

;;; E2E Test Suites

(eor-e2e-deftest registration
  "Test that instances can be registered from fixture directories."
  (let* ((instance-a-dir (expand-file-name "instance-a/"
                                            eor-e2e--work-dir))
         (instance-b-dir (expand-file-name "instance-b/"
                                            eor-e2e--work-dir)))
    ;; Instance A already has a sentinel -- should reuse its UUID
    (eor-e2e-assert-file-exists
     (expand-file-name "eor-instance.org" instance-a-dir)
     "Instance A sentinel exists before registration")

    ;; Register instance A
    (let ((entry-a (eor-register-instance instance-a-dir
                                          "test-instance-a")))
      (eor-e2e-assert entry-a "Instance A registered successfully")
      (eor-e2e-assert-equal
       (alist-get :id entry-a)
       "aaaaaaaa-1111-2222-3333-444444444444"
       "Instance A reused sentinel UUID (idempotent)"))

    ;; Register instance B
    (let ((entry-b (eor-register-instance instance-b-dir
                                          "test-instance-b")))
      (eor-e2e-assert entry-b "Instance B registered successfully")
      (eor-e2e-assert-equal
       (alist-get :id entry-b)
       "bbbbbbbb-1111-2222-3333-444444444444"
       "Instance B reused sentinel UUID (idempotent)"))

    ;; Verify registry has both entries
    (eor-e2e-assert-equal
     (length (eor-registry-list)) 2
     "Registry contains exactly 2 instances")

    ;; Verify registry persisted to disk
    (eor-e2e-assert-file-exists
     eor-registry-file
     "Registry file written to disk")))

(eor-e2e-deftest registry-persistence
  "Test that the registry survives reload."
  (let* ((instance-a-dir (expand-file-name "instance-a/"
                                            eor-e2e--work-dir)))
    ;; Register and save
    (eor-register-instance instance-a-dir "test-instance-a")

    ;; Reset in-memory state and reload
    (setq eor--registry nil
          eor--registry-loaded-p nil)
    (eor-registry--load)

    (eor-e2e-assert-equal
     (length eor--registry) 1
     "Registry has 1 entry after reload")

    (let ((entry (eor-registry-get
                  "aaaaaaaa-1111-2222-3333-444444444444")))
      (eor-e2e-assert entry "Entry found by UUID after reload")
      (eor-e2e-assert-equal
       (alist-get :name entry) "test-instance-a"
       "Instance name preserved after reload"))))

(eor-e2e-deftest link-parsing
  "Test that eor: links parse correctly in a real Emacs environment."
  (let ((targeted (eor-link--parse
                   "aaaaaaaa-1111-2222-3333-444444444444/a1000001-0000-0000-0000-000000000001"))
        (local-first (eor-link--parse
                      "a1000001-0000-0000-0000-000000000001")))
    (eor-e2e-assert-equal
     (car targeted) "aaaaaaaa-1111-2222-3333-444444444444"
     "Targeted link: instance UUID parsed")
    (eor-e2e-assert-equal
     (cdr targeted) "a1000001-0000-0000-0000-000000000001"
     "Targeted link: node UUID parsed")
    (eor-e2e-assert-equal
     (car local-first) nil
     "Local-first link: no instance UUID")
    (eor-e2e-assert-equal
     (cdr local-first) "a1000001-0000-0000-0000-000000000001"
     "Local-first link: node UUID parsed")))

(eor-e2e-deftest sentinel-idempotence
  "Test that re-registering preserves the original UUID."
  (let* ((instance-a-dir (expand-file-name "instance-a/"
                                            eor-e2e--work-dir)))
    ;; Register twice
    (let ((first (eor-register-instance instance-a-dir "test-a")))
      (let ((second (eor-register-instance instance-a-dir "test-a-renamed")))
        (eor-e2e-assert-equal
         (alist-get :id first) (alist-get :id second)
         "UUID unchanged after re-registration")
        (eor-e2e-assert-equal
         (length (eor-registry-list)) 1
         "No duplicate registry entries")))))

;;; Runner

(defun eor-e2e-run-all ()
  "Run all E2E tests and exit."
  (eor-e2e--setup)
  (eor-e2e-test-registration)
  (eor-e2e-test-registry-persistence)
  (eor-e2e-test-link-parsing)
  (eor-e2e-test-sentinel-idempotence)
  (eor-e2e--teardown))

(provide 'test-e2e-common)
;;; test-e2e-common.el ends here
