;;; demo.el --- Non-interactive demo of EOR federation -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Batch-mode demo that exercises the core EOR federation features:
;; DB building, instance registration, cross-instance queries, link
;; resolution, and search candidate formatting.
;;
;; Run via demo.sh or directly:
;;   emacs --batch -l <init> -l demo.el -f eor-demo-run
;;
;; For interactive use, see the "Interactive Quick Start" section at
;; the bottom of this file.
;;
;;; Code:

(require 'endless-org-roam)
(require 'endless-org-roam-registry)
(require 'endless-org-roam-transport)
(require 'endless-org-roam-link)
(require 'endless-org-roam-search)
(require 'cl-lib)

;;; Demo Helpers

(defvar eor-demo--section 0 "Current section counter.")

(defun eor-demo--header (title)
  "Print a numbered section TITLE."
  (cl-incf eor-demo--section)
  (message "")
  (message "━━━ %d. %s ━━━" eor-demo--section title))

(defun eor-demo--item (label value)
  "Print a LABEL: VALUE pair."
  (message "  %s: %s" label value))

(defun eor-demo--ok (msg)
  "Print a success MSG."
  (message "  ✓ %s" msg))

(defun eor-demo--list-item (text)
  "Print a list item TEXT."
  (message "    • %s" text))

;;; Demo Runner

(defun eor-demo-run ()
  "Run the EOR federation demo in batch mode."
  (let* ((work-dir (or (getenv "EOR_WORK_DIR")
                       (error "EOR_WORK_DIR not set")))
         (instance-a-dir (expand-file-name "instance-a/" work-dir))
         (instance-b-dir (expand-file-name "instance-b/" work-dir))
         (registry-file (expand-file-name "eor-registry.el" work-dir)))

    ;; Fresh state
    (setq eor-registry-file registry-file)
    (setq eor--registry nil
          eor--registry-loaded-p nil)
    (setq eor-verbose nil)  ;; Suppress eor-message noise during demo
    (setq eor-demo--section 0)

    ;; ── 1. Build org-roam databases ──
    (eor-demo--header "Building org-roam databases")
    (eor-demo--item "Instance A" instance-a-dir)
    (eor-demo--item "Instance B" instance-b-dir)

    (dolist (dir (list instance-a-dir instance-b-dir))
      (let ((org-roam-directory dir)
            (org-roam-db-location (expand-file-name "org-roam.db" dir)))
        (org-roam-db-sync)))

    (eor-demo--ok "Databases built for both instances")

    ;; ── 2. Register instances ──
    (eor-demo--header "Registering instances in federation")

    (let ((entry-a (eor-register-instance instance-a-dir "personal"))
          (entry-b (eor-register-instance instance-b-dir "work")))
      (eor-demo--item "Personal KB" (format "UUID %s → %s"
                                             (alist-get :id entry-a)
                                             instance-a-dir))
      (eor-demo--item "Work KB" (format "UUID %s → %s"
                                         (alist-get :id entry-b)
                                         instance-b-dir))
      (eor-demo--ok (format "Registry contains %d instances"
                             (length (eor-registry-list)))))

    ;; ── 3. Show registry contents ──
    (eor-demo--header "Registry contents")
    (dolist (instance (eor-registry-list))
      (eor-demo--list-item
       (format "[%s] %s (dir: %s)"
               (alist-get :id instance)
               (alist-get :name instance)
               (alist-get :roam-directory instance))))

    ;; ── 4. Cross-instance node query ──
    (eor-demo--header "Cross-instance node lookup")
    (message "  Scenario: current KB is 'personal', querying 'work' for Delta Node")

    (let* ((org-roam-directory instance-a-dir)
           (org-roam-db-location
            (expand-file-name "org-roam.db" instance-a-dir))
           (entry-b (eor-registry-get "bbbbbbbb-1111-2222-3333-444444444444"))
           (entry-a (eor-registry-get "aaaaaaaa-1111-2222-3333-444444444444"))
           (delta-in-b (eor-transport-node-exists-p
                        entry-b "b2000001-0000-0000-0000-000000000001"))
           (delta-in-a (eor-transport-node-exists-p
                        entry-a "b2000001-0000-0000-0000-000000000001")))
      (eor-demo--item "Delta in work KB" (if delta-in-b "FOUND" "not found"))
      (eor-demo--item "Delta in personal KB" (if delta-in-a "found" "NOT FOUND (correct)"))
      (eor-demo--ok "Cross-instance query works: nodes isolated per-instance"))

    ;; ── 5. Cross-instance link resolution ──
    (eor-demo--header "Cross-instance link resolution")

    ;; Targeted link
    (let* ((org-roam-directory instance-a-dir)
           (org-roam-db-location
            (expand-file-name "org-roam.db" instance-a-dir))
           (visited-node nil))
      (message "  Targeted link: [[eor:bbbbbbbb-.../b2000001-...]]")
      (cl-letf (((symbol-function 'org-roam-node-visit)
                 (lambda (node &rest _args) (setq visited-node node))))
        (eor-link-follow
         "bbbbbbbb-1111-2222-3333-444444444444/b2000001-0000-0000-0000-000000000001"
         nil))
      (eor-demo--ok (format "Resolved to: %s"
                             (org-roam-node-title visited-node))))

    ;; Local-first link
    (let* ((org-roam-directory instance-a-dir)
           (org-roam-db-location
            (expand-file-name "org-roam.db" instance-a-dir))
           (visited-node nil))
      (message "  Local-first link: [[eor:a1000001-...]] (Alpha is local)")
      (cl-letf (((symbol-function 'org-roam-node-visit)
                 (lambda (node &rest _args) (setq visited-node node)))
                ((symbol-function 'org-mark-ring-push)
                 (lambda (&rest _args) nil)))
        (eor-link-follow
         "a1000001-0000-0000-0000-000000000001"
         nil))
      (eor-demo--ok (format "Resolved locally to: %s"
                             (org-roam-node-title visited-node))))

    ;; Federated fallback
    (let* ((org-roam-directory instance-a-dir)
           (org-roam-db-location
            (expand-file-name "org-roam.db" instance-a-dir))
           (eor-search-all-instances t)
           (visited-node nil))
      (message "  Federated fallback: [[eor:b2000001-...]] (Delta not local, search all)")
      (cl-letf (((symbol-function 'org-roam-node-visit)
                 (lambda (node &rest _args) (setq visited-node node))))
        (eor-link-follow
         "b2000001-0000-0000-0000-000000000001"
         nil))
      (eor-demo--ok (format "Found via federation: %s"
                             (org-roam-node-title visited-node))))

    ;; ── 6. Cross-instance search ──
    (eor-demo--header "Cross-instance search")

    (let ((all-nodes '()))
      (dolist (instance (eor-registry-list))
        (let ((nodes (eor-transport-node-list instance))
              (inst-name (alist-get :name instance)))
          (dolist (node nodes)
            (push (format "[%s] %s" inst-name (org-roam-node-title node))
                  all-nodes))))
      (setq all-nodes (sort all-nodes #'string<))
      (message "  Candidates (as shown in eor-node-find):")
      (dolist (candidate all-nodes)
        (eor-demo--list-item candidate))
      (eor-demo--ok (format "%d total nodes across %d instances"
                             (length all-nodes)
                             (length (eor-registry-list)))))

    ;; ── Summary ──
    (message "")
    (message "═══════════════════════════════════════════════════════")
    (message " EOR federation demo complete!")
    (message "")
    (message " Two independent org-roam KBs were:")
    (message "   • Built with real org-roam databases")
    (message "   • Registered in a shared federation registry")
    (message "   • Queried across instance boundaries")
    (message "   • Linked with eor: links (targeted + local-first)")
    (message "   • Searched together with unified candidates")
    (message "═══════════════════════════════════════════════════════"))

  (kill-emacs 0))

;;; ─── Interactive Quick Start ───────────────────────────────────────
;;
;; To try EOR interactively in your own Emacs:
;;
;;   ;; 1. Enable EOR
;;   (eor-mode 1)
;;
;;   ;; 2. Register your existing org-roam directory
;;   (eor-register-instance "~/RoamNotes" "personal")
;;
;;   ;; 3. Register a second knowledge base
;;   (eor-register-instance "~/WorkNotes" "work")
;;
;;   ;; 4. Search across both:  M-x eor-node-find
;;   ;; 5. Insert a cross-link: M-x eor-node-insert
;;   ;; 6. Follow eor: links normally — they resolve local-first
;;
;; See README.org for full configuration options.

(provide 'eor-demo)
;;; demo.el ends here
