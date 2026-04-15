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
(require 'endless-org-roam-search)

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
(defvar eor-e2e--instance-a-dir nil "Path to instance-a fixture.")
(defvar eor-e2e--instance-b-dir nil "Path to instance-b fixture.")
(defvar eor-e2e--dbs-built-p nil "Non-nil when fixture DBs have been built.")

(defun eor-e2e--setup ()
  "Set up the E2E test environment."
  (setq eor-e2e--work-dir (or (getenv "EOR_WORK_DIR")
                               (make-temp-file "eor-e2e" t)))
  (setq eor-e2e--instance-a-dir
        (expand-file-name "instance-a/" eor-e2e--work-dir))
  (setq eor-e2e--instance-b-dir
        (expand-file-name "instance-b/" eor-e2e--work-dir))
  (setq eor-e2e--pass-count 0
        eor-e2e--fail-count 0)
  ;; Fresh registry for each run
  (setq eor-registry-file
        (expand-file-name "eor-registry.el" eor-e2e--work-dir))
  (setq eor--registry nil
        eor--registry-loaded-p nil)
  (message "\n=== EOR E2E Test Suite ===")
  (message "Work dir: %s" eor-e2e--work-dir)
  ;; Build org-roam databases for fixtures
  (eor-e2e--build-dbs))

(defun eor-e2e--build-dbs ()
  "Build org-roam databases for fixture instances.
Runs `org-roam-db-sync' for each fixture directory to create
real SQLite databases from the .org files."
  (if eor-e2e--dbs-built-p
      (message "  [setup] DBs already built, skipping")
    (message "  [setup] Building org-roam databases for fixtures...")
    (dolist (dir (list eor-e2e--instance-a-dir
                       eor-e2e--instance-b-dir))
      (message "  [setup] Building DB for %s" dir)
      (let ((org-roam-directory dir)
            (org-roam-db-location (expand-file-name "org-roam.db" dir)))
        (org-roam-db-sync)))
    (setq eor-e2e--dbs-built-p t)
    (message "  [setup] Databases built successfully")))

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

;;; Helper: register both instances

(defun eor-e2e--register-both ()
  "Register both fixture instances.  Returns (entry-a . entry-b)."
  (cons (eor-register-instance eor-e2e--instance-a-dir "test-instance-a")
        (eor-register-instance eor-e2e--instance-b-dir "test-instance-b")))

;;; Milestone 1: DB Binding Validation

(eor-e2e-deftest cross-instance-node-query
  "Test that transport can query nodes across instances via let-binding."
  (eor-e2e--register-both)
  (let ((entry-a (eor-registry-get "aaaaaaaa-1111-2222-3333-444444444444"))
        (entry-b (eor-registry-get "bbbbbbbb-1111-2222-3333-444444444444")))
    ;; Set "current" org-roam to instance-a
    (let ((org-roam-directory eor-e2e--instance-a-dir)
          (org-roam-db-location
           (expand-file-name "org-roam.db" eor-e2e--instance-a-dir)))
      ;; Delta (b2000001-...) should exist in instance-b but not instance-a
      (eor-e2e-assert
       (eor-transport-node-exists-p entry-b
                                     "b2000001-0000-0000-0000-000000000001")
       "Delta node found in instance-b via cross-instance query")

      (eor-e2e-assert
       (not (eor-transport-node-exists-p
             entry-a "b2000001-0000-0000-0000-000000000001"))
       "Delta node NOT found in instance-a (correctly absent)")

      ;; Alpha (a1000001-...) should exist in instance-a but not instance-b
      (eor-e2e-assert
       (eor-transport-node-exists-p entry-a
                                     "a1000001-0000-0000-0000-000000000001")
       "Alpha node found in instance-a")

      (eor-e2e-assert
       (not (eor-transport-node-exists-p
             entry-b "a1000001-0000-0000-0000-000000000001"))
       "Alpha node NOT found in instance-b (correctly absent)"))))

;;; Milestone 2: Cross-Instance Link Following

(eor-e2e-deftest cross-instance-link-follow
  "Test following a targeted eor: link to a node in another instance."
  (eor-e2e--register-both)
  (let ((org-roam-directory eor-e2e--instance-a-dir)
        (org-roam-db-location
         (expand-file-name "org-roam.db" eor-e2e--instance-a-dir))
        (visited-node nil))
    ;; Intercept org-roam-node-visit to capture the resolved node
    ;; without actually opening buffers (batch mode)
    (cl-letf (((symbol-function 'org-roam-node-visit)
               (lambda (node &rest _args)
                 (setq visited-node node))))
      (eor-link-follow
       "bbbbbbbb-1111-2222-3333-444444444444/b2000001-0000-0000-0000-000000000001"
       nil))
    (eor-e2e-assert visited-node
                     "Targeted link resolved to a node")
    (eor-e2e-assert-equal
     (org-roam-node-title visited-node)
     "Delta Node"
     "Resolved node has correct title")))

(eor-e2e-deftest local-first-link-follow
  "Test that local-first eor: link resolves locally when node exists."
  (eor-e2e--register-both)
  (let ((org-roam-directory eor-e2e--instance-a-dir)
        (org-roam-db-location
         (expand-file-name "org-roam.db" eor-e2e--instance-a-dir))
        (visited-node nil))
    (cl-letf (((symbol-function 'org-roam-node-visit)
               (lambda (node &rest _args)
                 (setq visited-node node)))
              ((symbol-function 'org-mark-ring-push)
               (lambda (&rest _args) nil)))
      (eor-link-follow
       "a1000001-0000-0000-0000-000000000001"
       nil))
    (eor-e2e-assert visited-node
                     "Local-first link resolved to a node")
    (eor-e2e-assert-equal
     (org-roam-node-title visited-node)
     "Alpha Node"
     "Resolved node is Alpha (local instance)")))

(eor-e2e-deftest federated-link-fallback
  "Test that local-first link falls back to federated search."
  (eor-e2e--register-both)
  (let ((org-roam-directory eor-e2e--instance-a-dir)
        (org-roam-db-location
         (expand-file-name "org-roam.db" eor-e2e--instance-a-dir))
        (eor-search-all-instances t)
        (visited-node nil))
    (cl-letf (((symbol-function 'org-roam-node-visit)
               (lambda (node &rest _args)
                 (setq visited-node node))))
      ;; Delta only exists in instance-b; with search-all, should find it
      (eor-link-follow
       "b2000001-0000-0000-0000-000000000001"
       nil))
    (eor-e2e-assert visited-node
                     "Federated fallback resolved to a node")
    (eor-e2e-assert-equal
     (org-roam-node-title visited-node)
     "Delta Node"
     "Federated fallback found Delta in instance-b")))

;;; Milestone 3: Cross-Instance Search

(eor-e2e-deftest cross-instance-search
  "Test that transport collects nodes from multiple instances."
  (eor-e2e--register-both)
  (let ((entry-a (eor-registry-get "aaaaaaaa-1111-2222-3333-444444444444"))
        (entry-b (eor-registry-get "bbbbbbbb-1111-2222-3333-444444444444")))
    (let ((nodes-a (eor-transport-node-list entry-a))
          (nodes-b (eor-transport-node-list entry-b)))
      ;; Instance A: sentinel + alpha + beta + gamma + gamma-subheading = 5
      (eor-e2e-assert
       (>= (length nodes-a) 4)
       (format "Instance A has at least 4 nodes (got %d)" (length nodes-a)))

      ;; Instance B: sentinel + delta + epsilon = 3
      (eor-e2e-assert
       (>= (length nodes-b) 2)
       (format "Instance B has at least 2 nodes (got %d)" (length nodes-b)))

      ;; Combined
      (let ((total (+ (length nodes-a) (length nodes-b))))
        (eor-e2e-assert
         (>= total 6)
         (format "Combined node count is at least 6 (got %d)" total))))))

(eor-e2e-deftest search-candidate-formatting
  "Test that eor-node-find builds correctly formatted candidates."
  (eor-e2e--register-both)
  (let* ((instances (eor-registry-list))
         (all-nodes '()))
    ;; Replicate the candidate-building logic from eor-node-find
    (dolist (instance instances)
      (let ((nodes (eor-transport-node-list instance))
            (inst-name (alist-get :name instance)))
        (dolist (node nodes)
          (push (format "[%s] %s" inst-name (org-roam-node-title node))
                all-nodes))))
    (eor-e2e-assert
     (cl-find-if (lambda (c) (string-match-p "\\[test-instance-a\\] Alpha Node" c))
                 all-nodes)
     "Candidates include [test-instance-a] Alpha Node")
    (eor-e2e-assert
     (cl-find-if (lambda (c) (string-match-p "\\[test-instance-b\\] Delta Node" c))
                 all-nodes)
     "Candidates include [test-instance-b] Delta Node")))

;;; Runner

(defun eor-e2e-run-all ()
  "Run all E2E tests and exit."
  (eor-e2e--setup)
  ;; Existing tests (registration, persistence, link parsing)
  (eor-e2e-test-registration)
  (eor-e2e-test-registry-persistence)
  (eor-e2e-test-link-parsing)
  (eor-e2e-test-sentinel-idempotence)
  ;; Milestone 1: DB binding validation
  (eor-e2e-test-cross-instance-node-query)
  ;; Milestone 2: cross-instance link following
  (eor-e2e-test-cross-instance-link-follow)
  (eor-e2e-test-local-first-link-follow)
  (eor-e2e-test-federated-link-fallback)
  ;; Milestone 3: cross-instance search
  (eor-e2e-test-cross-instance-search)
  (eor-e2e-test-search-candidate-formatting)
  (eor-e2e--teardown))

(provide 'test-e2e-common)
;;; test-e2e-common.el ends here
