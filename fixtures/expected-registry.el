;; -*- mode: emacs-lisp; no-byte-compile: t; -*-
;; Expected registry state after registering both fixture instances.
;; Used by E2E tests for assertion.

(((:id . "aaaaaaaa-1111-2222-3333-444444444444")
  (:name . "test-instance-a")
  (:roam-directory . "/FIXTURE_DIR/instance-a/")
  (:db-location . "/FIXTURE_DIR/instance-a/org-roam.db")
  (:endpoint . nil)
  (:registered-at . "TIMESTAMP"))
 ((:id . "bbbbbbbb-1111-2222-3333-444444444444")
  (:name . "test-instance-b")
  (:roam-directory . "/FIXTURE_DIR/instance-b/")
  (:db-location . "/FIXTURE_DIR/instance-b/org-roam.db")
  (:endpoint . nil)
  (:registered-at . "TIMESTAMP")))
