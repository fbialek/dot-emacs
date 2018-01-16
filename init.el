;; (require 'profiler)
;; (profiler-start 'cpu+mem)

(defconst emacs-start-time (current-time))

(setq package-enable-at-startup nil
      message-log-max 16384)

;;; Functions

(eval-and-compile
  (defsubst emacs-path (path)
    (expand-file-name path user-emacs-directory))

  (defsubst lookup-password (host user port)
    (require 'auth-source)
    (let ((auth (auth-source-search :host host :user user :port port)))
      (if auth
          (let ((secretf (plist-get (car auth) :secret)))
            (if secretf
                (funcall secretf)
              (error "Auth entry for %s@%s:%s has no secret!"
                     user host port)))
        (error "No auth entry found for %s@%s:%s" user host port))))

  (defun get-jobhours-string ()
    (with-current-buffer (get-buffer-create "*scratch*")
      (let ((str (shell-command-to-string "jobhours")))
        (require 'ansi-color)
        (ansi-color-apply (substring str 0 (1- (length str))))))))

;;; Environment

(eval-when-compile
  (require 'cl))

(eval-and-compile
  (require 'seq)

  (defconst emacs-environment
    (let ((name (getenv "NIX_MYENV_NAME")))
      (if (or (null name)
              (string= name (concat "ghc" (getenv "GHCVER"))))
          "emacs26full"
        name)))

  (setq load-path
        (append '("~/emacs"
                  "~/emacs/lib"
                  "~/emacs/site-lisp"
                  "~/emacs/lisp"
                  "~/emacs/lisp/use-package")
                (cl-remove-if
                 (apply-partially #'string-match "/org\\'")
                 (delete-dups load-path))))

  (defun nix-read-environment (name)
    (ignore-errors
      (with-temp-buffer
        (insert-file-contents-literally
         (with-temp-buffer
           (insert-file-contents-literally
            (executable-find (concat "load-env-" name)))
           (and (re-search-forward "^source \\(.+\\)$" nil t)
                (match-string 1))))
        (and (or (re-search-forward "^  nativeBuildInputs=\"\\(.+?\\)\"" nil t)
                 (re-search-forward "^  buildInputs=\"\\(.+?\\)\"" nil t))
             (split-string (match-string 1))))))

  (require 'use-package)

  (if init-file-debug
      (setq use-package-verbose t
            use-package-expand-minimally nil
            use-package-compute-statistics t
            debug-on-error t)
    (setq use-package-verbose nil
          use-package-expand-minimally t)))

;; (advice-add 'use-package-handler/:load-path :around
;;             #'(lambda (orig-func name keyword args rest state)
;;                 (unless (string= emacs-environment "emacs26full")
;;                   (if (or (memq name '(agda-input hyperbole proof-site slime
;;                                                   flycheck-haskell ghc))
;;                           (cl-some (apply-partially #'string-match "\\`~") args))
;;                       (funcall orig-func name keyword arg rest state)
;;                     (use-package-process-keywords name rest state)))))

;;; Settings

(eval-and-compile
  (defconst emacs-data-suffix
    (cond ((string= "emacsHEAD" emacs-environment) "alt")
          ((string-match "emacs26\\(.+\\)$" emacs-environment)
           (match-string 1 emacs-environment))))

  (defconst running-alternate-emacs (string= emacs-data-suffix "alt"))

  (defconst user-data-directory
    (emacs-path (if emacs-data-suffix
                    (format "data-%s" emacs-data-suffix)
                  "data")))

  (load (emacs-path "settings"))

  (when emacs-data-suffix
    (let ((settings (with-temp-buffer
                      (insert-file-contents (emacs-path "settings.el"))
                      (read (current-buffer)))))
      (pcase-dolist (`(quote (,var ,value . ,_)) (cdr settings))
        (when (and (stringp value)
                   (string-match "/\\.emacs\\.d/data" value))
          (set var (replace-regexp-in-string
                    "/\\.emacs\\.d/data"
                    (format "/.emacs.d/data-%s" emacs-data-suffix)
                    value)))))))

(defvar Info-directory-list
  (mapcar 'expand-file-name
          (list
           (emacs-path "info")
           "~/Library/Info"
           (if (executable-find "nix-env")
               (expand-file-name
                "share/info"
                (car (nix-read-environment emacs-environment)))
             "~/share/info")
           "/run/current-system/sw/share/info"
           "~/.nix-profile/share/info")))

(setq disabled-command-function nil)

(eval-when-compile
  (setplist 'flet (use-package-plist-delete (symbol-plist 'flet)
                                            'byte-obsolete-info)))

;;; Libraries

(use-package alert         :defer t  :load-path "lisp/alert")
(use-package anaphora      :defer t  :load-path "lib/anaphora")
(use-package apiwrap       :defer t  :load-path "lib/apiwrap")
(use-package asoc          :defer t  :load-path "lib/asoc")
(use-package async         :defer t  :load-path "lisp/emacs-async")
(use-package button-lock   :defer t  :load-path "lib/button-lock")
(use-package ctable        :defer t  :load-path "lib/ctable")
(use-package dash          :defer t  :load-path "lib/dash-el")
(use-package deferred      :defer t  :load-path "lib/deferred")
(use-package diminish      :demand t :load-path "lib/diminish")
(use-package el-mock       :defer t  :load-path "lib")
(use-package elisp-refs    :defer t  :load-path "lib/elisp-refs")
(use-package emojify       :defer t  :load-path "lib/emojify")
(use-package epc           :defer t  :load-path "lib/epc")
(use-package epl           :defer t  :load-path "lib/epl")
(use-package esxml         :defer t  :load-path "lib/esxml")
(use-package f             :defer t  :load-path "lib/f-el")
(use-package fn            :defer t  :load-path "lib/fn-el")
(use-package fringe-helper :defer t  :load-path "lib/fringe-helper-el")
(use-package fuzzy         :defer t  :load-path "lib/fuzzy-el")
(use-package ghub          :defer t  :load-path "lib/ghub")
(use-package ghub+         :defer t  :load-path "lib/ghub-plus")
(use-package ht            :defer t  :load-path "lib/ht-el")
(use-package kv            :defer t  :load-path "lib/kv")
(use-package list-utils    :defer t  :load-path "lib/list-utils")
(use-package logito        :defer t  :load-path "lib/logito")
(use-package loop          :defer t  :load-path "lib/loop")
(use-package m-buffer      :defer t  :load-path "lib/m-buffer")
(use-package makey         :defer t  :load-path "lib/makey")
(use-package marshal       :defer t  :load-path "lib/marshal-el")
(use-package names         :defer t  :load-path "lib/names")
(use-package noflet        :defer t  :load-path "lib/noflet")
(use-package oauth2        :defer t  :load-path "lib/oauth2")
(use-package ov            :defer t  :load-path "lib/ov-el")
(use-package packed        :defer t  :load-path "lib/packed")
(use-package parent-mode   :defer t  :load-path "lib/parent-mode")
(use-package parsebib      :defer t  :load-path "lib/parsebib")
(use-package parsec        :defer t  :load-path "lib/parsec")
(use-package peval         :defer t  :load-path "lib/peval")
(use-package pfuture       :defer t  :load-path "lib/pfuture")
(use-package pkg-info      :defer t  :load-path "lib/pkg-info")
(use-package popup         :defer t  :load-path "lib/popup-el")
(use-package popup-pos-tip :defer t  :load-path "lib")
(use-package popwin        :defer t  :load-path "site-lisp/popwin")
(use-package pos-tip       :defer t  :load-path "lib")
(use-package request       :defer t  :load-path "lib/request")
(use-package rich-minority :defer t  :load-path "lib/rich-minority")
(use-package s             :defer t  :load-path "lib/s-el")
(use-package simple-httpd  :defer t  :load-path "lib/simple-httpd")
(use-package spinner       :defer t  :load-path "lib/spinner")
(use-package tablist       :defer t  :load-path "lib/tablist")
(use-package uuidgen       :defer t  :load-path "lib/uuidgen-el")
(use-package web           :defer t  :load-path "lib/web")
(use-package web-server    :defer t  :load-path "lib/web-server")
(use-package websocket     :defer t  :load-path "lib/websocket")
(use-package with-editor   :defer t  :load-path "lib/with-editor")
(use-package xml-rpc       :defer t  :load-path "lib")
(use-package zoutline      :defer t  :load-path "lib/zoutline")

;;; Keymaps

(define-key input-decode-map [?\C-m] [C-m])

(eval-and-compile
  (mapc #'(lambda (entry)
            (define-prefix-command (cdr entry))
            (bind-key (car entry) (cdr entry)))
        '(("<C-m>" . my-ctrl-m-map)

          ("C-h e" . my-ctrl-h-e-map)

          ("C-c e" . my-ctrl-c-e-map)
          ("C-c m" . my-ctrl-c-m-map)
          ("C-c y" . my-ctrl-c-y-map)

          ("C-."   . my-ctrl-dot-map)
          ("C-. =" . my-ctrl-dot-equals-map)
          ("C-. f" . my-ctrl-dot-f-map)
          ("C-. g" . my-ctrl-dot-g-map)
          ("C-. h" . my-ctrl-dot-h-map)
          ("C-. m" . my-ctrl-dot-m-map)
          ("C-. r" . my-ctrl-dot-r-map))))

;;; Packages

(use-package abbrev
  :defer 5
  :diminish
  :hook
  ((text-mode prog-mode erc-mode LaTeX-mode) . abbrev-mode)
  (expand-load
   . (lambda ()
       (add-hook 'expand-expand-hook 'indent-according-to-mode)
       (add-hook 'expand-jump-hook 'indent-according-to-mode)))
  :config
  (if (file-exists-p abbrev-file-name)
      (quietly-read-abbrev-file)))

(use-package ace-jump-mode
  :load-path "site-lisp/ace-jump-mode"
  :defer t)

(use-package ace-link
  :load-path "site-lisp/ace-link"
  :defer 10
  :config
  (ace-link-setup-default)

  (add-hook 'org-mode-hook
            #'(lambda () (bind-key "C-c C-o" #'ace-link-org org-mode-map)))
  (add-hook 'gnus-summary-mode-hook
            #'(lambda () (bind-key "M-o" #'ace-link-gnus gnus-summary-mode-map)))
  (add-hook 'gnus-article-mode-hook
            #'(lambda () (bind-key "M-o" #'ace-link-gnus gnus-article-mode-map)))
  (add-hook 'ert-results-mode-hook
            #'(lambda () (bind-key "o" #'ace-link-help ert-results-mode-map)))

  (bind-key "C-c M-o" 'ace-link-addr))

(use-package ace-mc
  :load-path "site-lisp/ace-mc"
  :bind (("<C-m> h"   . ace-mc-add-multiple-cursors)
         ("<C-m> M-h" . ace-mc-add-single-cursor)))

(use-package ace-window
  :load-path "site-lisp/ace-window"
  :bind* ("<C-return>" . ace-window))

(use-package agda-input
  :defer 5
  :load-path
  (lambda ()
    (delete
     nil
     (mapcar
      #'(lambda (dir)
          ;; The Emacs files for Agda are installed by Nix as part of the
          ;; haskellPackages.Agda package.
          (let ((exe (expand-file-name "bin/agda-mode" dir)))
            (when (file-executable-p exe)
              (file-name-directory
               (substring (shell-command-to-string (concat exe " locate"))
                          0 -1)))))
      (seq-filter
       (apply-partially #'string-match "-\\(Agda-\\|with-packages\\)")
       (nix-read-environment "ghc80")))))
  :config
  (setq-default default-input-method "Agda"))

(use-package agda2-mode
  ;; This declaration depends on the load-path established by agda-input.
  :mode "\\.agda\\'"
  :bind (:map agda2-mode-map
              ("C-c C-i" . agda2-insert-helper-function))
  :preface
  (defun agda2-insert-helper-function (&optional prefix)
    (interactive "P")
    (let ((func-def (with-current-buffer "*Agda information*"
                      (buffer-string))))
      (save-excursion
        (forward-paragraph)
        (let ((name (car (split-string func-def " "))))
          (insert "  where\n    " func-def "    " name " x = ?\n"))))))

(use-package aggressive-indent
  :load-path "site-lisp/aggressive-indent-mode"
  :diminish
  :hook (emacs-lisp-mode . aggressive-indent-mode))

(use-package align
  :bind (("M-["   . align-code)
         ("C-c [" . align-regexp))
  :commands align
  :preface
  (defun align-code (beg end &optional arg)
    (interactive "rP")
    (if (null arg)
        (align beg end)
      (let ((end-mark (copy-marker end)))
        (indent-region beg end-mark nil)
        (align beg end-mark)))))

(use-package anki-editor
  :load-path "site-lisp/anki-editor"
  :commands anki-editor-submit)

(use-package aria2
  :load-path "site-lisp/aria2"
  :commands aria2-downloads-list)

(use-package ascii
  :bind ("C-c e A" . ascii-toggle)
  :commands (ascii-on ascii-off)
  :preface
  (defun ascii-toggle ()
    (interactive)
    (if ascii-display
        (ascii-off)
      (ascii-on))))

(use-package auctex
  :load-path "site-lisp/auctex"
  :mode ("\\.tex\\'" . TeX-latex-mode)
  :config
  (defun latex-help-get-cmd-alist ()    ;corrected version:
    "Scoop up the commands in the index of the latex info manual.
   The values are saved in `latex-help-cmd-alist' for speed."
    ;; mm, does it contain any cached entries
    (if (not (assoc "\\begin" latex-help-cmd-alist))
        (save-window-excursion
          (setq latex-help-cmd-alist nil)
          (Info-goto-node (concat latex-help-file "Command Index"))
          (goto-char (point-max))
          (while (re-search-backward "^\\* \\(.+\\): *\\(.+\\)\\." nil t)
            (let ((key (buffer-substring (match-beginning 1) (match-end 1)))
                  (value (buffer-substring (match-beginning 2)
                                           (match-end 2))))
              (add-to-list 'latex-help-cmd-alist (cons key value))))))
    latex-help-cmd-alist)

  (add-hook 'TeX-after-compilation-finished-functions
            #'TeX-revert-document-buffer))

(use-package auth-source-pass
  :defer 5
  :config
  (auth-source-pass-enable)

  (defun auth-source-pass--read-entry (entry)
    "Return a string with the file content of ENTRY."
    (with-temp-buffer
      (insert-file-contents (expand-file-name
                             (format "%s.gpg" entry)
                             (getenv "PASSWORD_STORE_DIR")))
      (buffer-substring-no-properties (point-min) (point-max))))

  (defun auth-source-pass-entries ()
    "Return a list of all password store entries."
    (let ((store-dir (getenv "PASSWORD_STORE_DIR")))
      (mapcar
       (lambda (file) (file-name-sans-extension (file-relative-name file store-dir)))
       (directory-files-recursively store-dir "\.gpg$")))))

(use-package auto-yasnippet
  :load-path "site-lisp/auto-yasnippet"
  :after yasnippet
  :bind (("C-c y a" . aya-create)
         ("C-c y e" . aya-expand)
         ("C-c y o" . aya-open-line)))

(use-package avy
  :load-path "site-lisp/avy"
  :bind ("M-h" . avy-goto-char-timer)
  :config
  (avy-setup-default))

(use-package avy-zap
  :load-path "site-lisp/avy-zap"
  :bind (("M-z" . avy-zap-to-char-dwim)
         ("M-Z" . avy-zap-up-to-char-dwim)))

(use-package backup-each-save
  :commands backup-each-save
  :preface
  (defun my-make-backup-file-name (file)
    (make-backup-file-name-1 (file-truename file)))

  (defun backup-each-save-filter (filename)
    (not (string-match
          (concat "\\(^/tmp\\|\\.emacs\\.d/data\\(-alt\\)?/"
                  "\\|\\.newsrc\\(\\.eld\\)?\\|"
                  "\\(archive/sent/\\|recentf\\`\\)\\)")
          filename)))

  (defun my-dont-backup-files-p (filename)
    (unless (string-match filename "\\(archive/sent/\\|recentf\\`\\)")
      (normal-backup-enable-predicate filename)))

  :hook after-save
  :config
  (setq backup-each-save-filter-function 'backup-each-save-filter
        backup-enable-predicate 'my-dont-backup-files-p))

(use-package beacon
  :load-path "site-lisp/beacon"
  :diminish
  :commands beacon-mode)

(use-package biblio
  :load-path "site-lisp/biblio"
  :commands biblio-lookup)

(use-package bm
  :unless running-alternate-emacs
  :load-path "site-lisp/bm"
  :bind (("C-. b" . bm-toggle)
         ("C-. ." . bm-next)
         ("C-. ," . bm-previous))
  :commands (bm-repository-load
             bm-buffer-save
             bm-buffer-save-all
             bm-buffer-restore)
  :init
  (add-hook' after-init-hook 'bm-repository-load)
  (add-hook 'find-file-hooks 'bm-buffer-restore)
  (add-hook 'after-revert-hook #'bm-buffer-restore)
  (add-hook 'kill-buffer-hook #'bm-buffer-save)
  (add-hook 'after-save-hook #'bm-buffer-save)
  (add-hook 'vc-before-checkin-hook #'bm-buffer-save)
  (add-hook 'kill-emacs-hook #'(lambda nil
                                 (bm-buffer-save-all)
                                 (bm-repository-save))))

(use-package bookmark+
  :load-path "site-lisp/bookmark-plus"
  :after bookmark
  :bind ("M-B" . bookmark-bmenu-list)
  :commands bmkp-jump-dired)

(use-package browse-at-remote
  :load-path "site-lisp/browse-at-remote"
  :bind ("C-. g g" . browse-at-remote))

(use-package browse-kill-ring
  :load-path "site-lisp/browse-kill-ring"
  :defer 5
  :commands browse-kill-ring)

(use-package browse-kill-ring+
  :after browse-kill-ring)

(use-package bytecomp-simplify
  :defer 15)

(use-package c-includes
  :disabled t
  :commands c-includes
  :after cc-mode
  :bind (:map c-mode-base-map
              ("C-c C-i"  . c-includes-current-file)))

(use-package calc
  :defer t
  :custom
  (math-additional-units
   '((GiB "1024 * MiB" "Giga Byte")
     (MiB "1024 * KiB" "Mega Byte")
     (KiB "1024 * B" "Kilo Byte")
     (B nil "Byte")
     (Gib "1024 * Mib" "Giga Bit")
     (Mib "1024 * Kib" "Mega Bit")
     (Kib "1024 * b" "Kilo Bit")
     (b "B / 8" "Bit")))
  :config
  (setq math-units-table nil))

(use-package cc-mode
  :mode (("\\.h\\(h?\\|xx\\|pp\\)\\'" . c++-mode)
         ("\\.m\\'" . c-mode)
         ("\\.mm\\'" . c++-mode))
  :bind (:map c++-mode-map
              ("<" . self-insert-command)
              (">" . self-insert-command))
  :bind (:map c-mode-base-map
              ("#" . self-insert-command)
              ("{" . self-insert-command)
              ("}" . self-insert-command)
              ("/" . self-insert-command)
              ("*" . self-insert-command)
              (";" . self-insert-command)
              ("," . self-insert-command)
              (":" . self-insert-command)
              ("(" . self-insert-command)
              (")" . self-insert-command)
              ("<return>" . newline-and-indent)
              ("M-q" . c-fill-paragraph)
              ("M-j"))
  :preface
  (defun my-c-mode-common-hook ()
    (require 'flycheck)
    (flycheck-define-checker
     c++-ledger
     "A C++ syntax checker for the Ledger project specifically."
     :command ("ninja"
               "-C"
               (eval (expand-file-name "~/Products/ledger"))
               (eval (concat "src/CMakeFiles/libledger.dir/"
                             (file-name-nondirectory (buffer-file-name))
                             ".o")))
     :error-patterns
     ((error line-start
             (message "In file included from") " " (or "<stdin>" (file-name))
             ":" line ":" line-end)
      (info line-start (or "<stdin>" (file-name)) ":" line ":" column
            ": note: " (optional (message)) line-end)
      (warning line-start (or "<stdin>" (file-name)) ":" line ":" column
               ": warning: " (optional (message)) line-end)
      (error line-start (or "<stdin>" (file-name)) ":" line ":" column
             ": " (or "fatal error" "error") ": " (optional (message)) line-end))
     :error-filter
     (lambda (errors)
       (let ((errors (flycheck-sanitize-errors errors)))
         (dolist (err errors)
           ;; Clang will output empty messages for #error/#warning pragmas
           ;; without messages. We fill these empty errors with a dummy message
           ;; to get them past our error filtering
           (setf (flycheck-error-message err)
                 (or (flycheck-error-message err) "no message")))
         (flycheck-fold-include-levels errors "In file included from")))
     :modes c++-mode
     :next-checkers ((warning . c/c++-cppcheck)))

    (flycheck-mode 1)
    (flycheck-select-checker 'c++-ledger)
    (setq-local flycheck-check-syntax-automatically nil)
    (setq-local flycheck-highlighting-mode nil)

    (set (make-local-variable 'parens-require-spaces) nil)

    (let ((bufname (buffer-file-name)))
      (when bufname
        (cond
         ((string-match "/ledger/" bufname)
          (c-set-style "ledger"))
         ((string-match "/edg/" bufname)
          (c-set-style "edg"))
         (t
          (c-set-style "clang")))))

    (font-lock-add-keywords
     'c++-mode '(("\\<\\(assert\\|DEBUG\\)(" 1 font-lock-warning-face t))))

  :hook (c-mode-common . my-c-mode-common-hook)
  :config
  (add-to-list
   'c-style-alist
   '("edg"
     (indent-tabs-mode . nil)
     (c-basic-offset . 2)
     (c-comment-only-line-offset . (0 . 0))
     (c-hanging-braces-alist
      . ((substatement-open before after)
         (arglist-cont-nonempty)))
     (c-offsets-alist
      . ((statement-block-intro . +)
         (knr-argdecl-intro . 5)
         (substatement-open . 0)
         (substatement-label . 0)
         (label . 0)
         (case-label . +)
         (statement-case-open . 0)
         (statement-cont . +)
         (arglist-intro . +)
         (arglist-close . +)
         (inline-open . 0)
         (brace-list-open . 0)
         (topmost-intro-cont
          . (first c-lineup-topmost-intro-cont
                   c-lineup-gnu-DEFUN-intro-cont))))
     (c-special-indent-hook . c-gnu-impose-minimum)
     (c-block-comment-prefix . "")))

  (add-to-list
   'c-style-alist
   '("ledger"
     (indent-tabs-mode . nil)
     (c-basic-offset . 2)
     (c-comment-only-line-offset . (0 . 0))
     (c-hanging-braces-alist
      . ((substatement-open before after)
         (arglist-cont-nonempty)))
     (c-offsets-alist
      . ((statement-block-intro . +)
         (knr-argdecl-intro . 5)
         (substatement-open . 0)
         (substatement-label . 0)
         (label . 0)
         (case-label . 0)
         (statement-case-open . 0)
         (statement-cont . +)
         (arglist-intro . +)
         (arglist-close . +)
         (inline-open . 0)
         (brace-list-open . 0)
         (topmost-intro-cont
          . (first c-lineup-topmost-intro-cont
                   c-lineup-gnu-DEFUN-intro-cont))))
     (c-special-indent-hook . c-gnu-impose-minimum)
     (c-block-comment-prefix . "")))

  (add-to-list
   'c-style-alist
   '("clang"
     (indent-tabs-mode . nil)
     (c-basic-offset . 2)
     (c-comment-only-line-offset . (0 . 0))
     (c-hanging-braces-alist
      . ((substatement-open before after)
         (arglist-cont-nonempty)))
     (c-offsets-alist
      . ((statement-block-intro . +)
         (knr-argdecl-intro . 5)
         (substatement-open . 0)
         (substatement-label . 0)
         (label . 0)
         (case-label . 0)
         (statement-case-open . 0)
         (statement-cont . +)
         (arglist-intro . +)
         (arglist-close . +)
         (inline-open . 0)
         (brace-list-open . 0)
         (topmost-intro-cont
          . (first c-lineup-topmost-intro-cont
                   c-lineup-gnu-DEFUN-intro-cont))))
     (c-special-indent-hook . c-gnu-impose-minimum)
     (c-block-comment-prefix . ""))))

(use-package centered-cursor-mode
  :commands centered-cursor-mode)

(use-package change-inner
  :load-path "site-lisp/change-inner"
  :bind (("M-i"     . change-inner)
         ("M-o M-o" . change-outer)))

(use-package chess
  :load-path "lisp/chess"
  :commands chess)

(use-package chess-ics
  :after chess
  :commands chess-ics
  :config
  (defun chess ()
    (interactive)
    (chess-ics "freechess.org" 5000 "jwiegley"
               (lookup-password "freechess.org" "jwiegley" 80))))

(use-package circe
  :load-path "site-lisp/circe"
  :if running-alternate-emacs
  :defer t)

(use-package cl-info
  ;; jww (2017-12-10): Need to configure.
  :disabled t)

(use-package cldoc
  :commands (cldoc-mode turn-on-cldoc-mode)
  :diminish)

(use-package clipmon
  :load-path "site-lisp/clipmon"
  :bind ("<f2>" . clipmon-autoinsert-toggle)
  :hook (after-init . clipmon-mode-start))

(use-package cmake-font-lock
  :load-path "site-lisp/cmake-font-lock"
  :hook (cmake-mode . cmake-font-lock-activate))

(use-package cmake-mode
  :mode ("CMakeLists.txt" "\\.cmake\\'"))

(use-package col-highlight
  :commands col-highlight-mode)

(use-package color-moccur
  :load-path "site-lisp/color-moccur"
  :commands (isearch-moccur isearch-all isearch-moccur-all)
  :bind (("M-s O" . moccur)
         :map isearch-mode-map
         ("M-o" . isearch-moccur)
         ("M-O" . isearch-moccur-all)))

(use-package command-log-mode
  :load-path "site-lisp/command-log-mode"
  :bind (("C-c e M" . command-log-mode)
         ("C-c e L" . clm/open-command-log-buffer)))

(use-package company
  :load-path "site-lisp/company-mode"
  :defer 5
  :diminish
  :commands (company-mode company-indent-or-complete-common)
  :init
  (dolist (hook '(emacs-lisp-mode-hook
                  haskell-mode-hook
                  c-mode-common-hook))
    (add-hook hook
              #'(lambda ()
                  (local-set-key (kbd "<tab>")
                                 #'company-indent-or-complete-common))))
  :config
  ;; From https://github.com/company-mode/company-mode/issues/87
  ;; See also https://github.com/company-mode/company-mode/issues/123
  (defadvice company-pseudo-tooltip-unless-just-one-frontend
      (around only-show-tooltip-when-invoked activate)
    (when (company-explicit-action-p)
      ad-do-it))

  ;; See http://oremacs.com/2017/12/27/company-numbers/
  (defun ora-company-number ()
    "Forward to `company-complete-number'.

Unless the number is potentially part of the candidate.
In that case, insert the number."
    (interactive)
    (let* ((k (this-command-keys))
           (re (concat "^" company-prefix k)))
      (if (cl-find-if (lambda (s) (string-match re s))
                      company-candidates)
          (self-insert-command 1)
        (company-complete-number (string-to-number k)))))

  (let ((map company-active-map))
    (mapc
     (lambda (x)
       (define-key map (format "%d" x) 'ora-company-number))
     (number-sequence 0 9))
    (define-key map " " (lambda ()
                          (interactive)
                          (company-abort)
                          (self-insert-command 1)))
    (define-key map (kbd "<return>") nil))

  (defun check-expansion ()
    (save-excursion
      (if (outline-on-heading-p t)
          nil
        (if (looking-at "\\_>") t
          (backward-char 1)
          (if (looking-at "\\.") t
            (backward-char 1)
            (if (looking-at "->") t nil))))))

  (define-key company-mode-map [tab]
    '(menu-item "maybe-company-expand" nil
                :filter (lambda (&optional _)
                          (when (check-expansion)
                            #'company-complete-common))))

  (eval-after-load "yasnippet"
    '(progn
       (defun company-mode/backend-with-yas (backend)
         (if (and (listp backend) (member 'company-yasnippet backend))
             backend
           (append (if (consp backend) backend (list backend))
                   '(:with company-yasnippet))))
       (setq company-backends
             (mapcar #'company-mode/backend-with-yas company-backends))))

  (global-company-mode 1))

(use-package company-auctex
  :load-path "site-lisp/company-auctex"
  :after (company latex))

(use-package company-cabal
  :load-path "site-lisp/company-cabal"
  :after (company haskell-cabal))

(use-package company-coq
  :load-path "site-lisp/company-coq"
  :after coq
  :commands company-coq-mode
  :bind (:map company-coq-map
              ("M-<return>"))
  :bind (:map coq-mode-map
              ("C-M-h" . company-coq-toggle-definition-overlay)))

(use-package company-ghc
  :load-path "site-lisp/company-ghc"
  :after (company ghc)
  :config
  (push 'company-ghc company-backends))

(use-package company-math
  :load-path "site-lisp/company-math"
  :defer t)

(use-package company-quickhelp
  :load-path "site-lisp/company-quickhelp"
  :after company
  :bind (:map company-active-map
              ("C-c ?" . company-quickhelp-manual-begin)))

(use-package company-restclient
  :load-path "site-lisp/company-restclient"
  :after (company restclient))

(use-package company-rtags
  :disabled t
  :load-path "~/.nix-profile/share/emacs/site-lisp/rtags"
  :after (company rtags)
  :config
  (push 'company-rtags company-backends))

(use-package compile
  :no-require
  :bind (("C-c c" . compile)
         ("M-O"   . show-compilation))
  :preface
  (defun show-compilation ()
    (interactive)
    (let ((it
           (catch 'found
             (dolist (buf (buffer-list))
               (when (string-match "\\*compilation\\*" (buffer-name buf))
                 (throw 'found buf))))))
      (if it
          (display-buffer it)
        (call-interactively 'compile))))

  (defun compilation-ansi-color-process-output ()
    (ansi-color-process-output nil)
    (set (make-local-variable 'comint-last-output-start)
         (point-marker)))

  :hook (compilation-filter . compilation-ansi-color-process-output))

(use-package copy-as-format
  :load-path "site-lisp/copy-as-format"
  :bind ("C-. M-w" . copy-as-format)
  :init
  (setq copy-as-format-default "github"))

(use-package counsel
  :load-path "site-lisp/swiper"
  :after ivy
  :demand t
  :diminish
  :custom (counsel-find-file-ignore-regexp
           (concat "\\(\\`\\.[^.]\\|"
                   (regexp-opt completion-ignored-extensions)
                   "\\)"))
  :bind (("C-*"     . counsel-org-agenda-headlines)
         ("C-x C-f" . counsel-find-file)
         ("C-c e l" . counsel-find-library)
         ("C-c e q" . counsel-set-variable)
         ("C-h e l" . counsel-find-library)
         ("C-h e u" . counsel-unicode-char)
         ("C-h f"   . counsel-describe-function)
         ("C-x r b" . counsel-bookmark)
         ("M-x"     . counsel-M-x)
         ("M-y"     . counsel-yank-pop)

         ("M-s f" . counsel-rg)
         ("M-s j" . counsel-dired-jump)
         ("M-s n" . counsel-file-jump))
  :commands counsel-minibuffer-history
  :init
  (bind-key "M-r" #'counsel-minibuffer-history minibuffer-local-map)
  :config
  (add-to-list 'ivy-sort-matches-functions-alist
               '(counsel-find-file . ivy--sort-files-by-date)))

(use-package counsel-projectile
  :load-path "site-lisp/counsel-projectile"
  :after (counsel projectile)
  :config
  (counsel-projectile-on)
  (define-key projectile-mode-map [remap projectile-ag]
    #'counsel-projectile-rg))

(use-package crosshairs
  :bind ("M-o c" . crosshairs-mode))

(use-package crux
  :load-path "site-lisp/crux"
  :bind ("C-c e i" . crux-find-user-init-file))

(use-package css-mode
  :mode "\\.css\\'")

(use-package csv-mode
  :load-path "site-lisp/csv-mode"
  :mode "\\.csv\\'")

(use-package cursor-chg
  :commands change-cursor-mode
  :config
  (change-cursor-mode 1)
  (toggle-cursor-type-when-idle 1))

(use-package cus-edit
  :bind (("C-c o" . customize-option)
         ("C-c O" . customize-group)
         ("C-c F" . customize-face)))

(use-package dash-at-point
  :load-path "site-lisp/dash-at-point"
  :bind ("C-c D" . dash-at-point)
  :config
  (add-to-list 'dash-at-point-mode-alist
               '(haskell-mode . "haskell")))

(use-package debbugs-gnu
  :load-path "site-lisp/debbugs"
  :commands (debbugs-gnu debbugs-gnu-search)
  :bind ("C-. #" . gnus-read-ephemeral-emacs-bug-group))

(use-package dedicated
  :bind ("C-. D" . dedicated-mode))

(use-package deft
  :load-path "site-lisp/deft"
  :bind ("C-. C-," . deft))

(use-package diff-hl
  :load-path "site-lisp/diff-hl"
  :commands (diff-hl-mode diff-hl-dired-mode)
  :hook (magit-post-refresh . diff-hl-magit-post-refresh))

(use-package diff-hl-flydiff
  :load-path "site-lisp/diff-hl"
  :commands diff-hl-flydiff-mode)

(use-package diff-mode
  :commands diff-mode)

(use-package diffview
  :load-path "site-lisp/diffview-mode"
  :commands (diffview-current diffview-region diffview-message))

(use-package dired
  :bind ("C-c J" . dired-double-jump)
  :bind (:map dired-mode-map
              ("e"     . ora-ediff-files)
              ("l"     . dired-up-directory)
              ("Y"     . ora-dired-rsync)
              ("<tab>" . my-dired-switch-window)
              ("M-!"   . async-shell-command)
              ("M-G"))
  :preface
  (defvar mark-files-cache (make-hash-table :test #'equal))

  (defun mark-similar-versions (name)
    (let ((pat name))
      (if (string-match "^\\(.+?\\)-[0-9._-]+$" pat)
          (setq pat (match-string 1 pat)))
      (or (gethash pat mark-files-cache)
          (ignore (puthash pat t mark-files-cache)))))

  (defun dired-mark-similar-version ()
    (interactive)
    (setq mark-files-cache (make-hash-table :test #'equal))
    (dired-mark-sexp '(mark-similar-versions name)))

  (defun dired-double-jump (first-dir second-dir)
    (interactive
     (list (read-directory-name "First directory: "
                                (expand-file-name "~")
                                nil nil "dl/")
           (read-directory-name "Second directory: "
                                (expand-file-name "~")
                                nil nil "Archives/")))
    (dired first-dir)
    (dired-other-window second-dir))

  (defun my-dired-switch-window ()
    (interactive)
    (if (eq major-mode 'sr-mode)
        (call-interactively #'sr-change-window)
      (call-interactively #'other-window)))

  (defun ora-dired-rsync (dest)
    (interactive
     (list
      (expand-file-name
       (read-file-name "Rsync to: " (dired-dwim-target-directory)))))
    (let ((files (dired-get-marked-files
                  nil current-prefix-arg))
          (tmtxt/rsync-command
           "rsync -arvz --progress "))
      (dolist (file files)
        (setq tmtxt/rsync-command
              (concat tmtxt/rsync-command
                      (shell-quote-argument file)
                      " ")))
      (setq tmtxt/rsync-command
            (concat tmtxt/rsync-command
                    (shell-quote-argument dest)))
      (async-shell-command tmtxt/rsync-command "*rsync*")
      (other-window 1)))

  (defun ora-ediff-files ()
    (interactive)
    (let ((files (dired-get-marked-files))
          (wnd (current-window-configuration)))
      (if (<= (length files) 2)
          (let ((file1 (car files))
                (file2 (if (cdr files)
                           (cadr files)
                         (read-file-name
                          "file: "
                          (dired-dwim-target-directory)))))
            (if (file-newer-than-file-p file1 file2)
                (ediff-files file2 file1)
              (ediff-files file1 file2))
            (add-hook 'ediff-after-quit-hook-internal
                      `(lambda ()
                         (setq ediff-after-quit-hook-internal nil)
                         (set-window-configuration ,wnd))))
        (error "no more than 2 files should be marked"))))

  :config
  (ignore-errors
    (unbind-key "M-s f" dired-mode-map))

  (defadvice dired-omit-startup (after diminish-dired-omit activate)
    "Make sure to remove \"Omit\" from the modeline."
    (diminish 'dired-omit-mode) dired-mode-map)

  (defadvice dired-next-line (around dired-next-line+ activate)
    "Replace current buffer if file is a directory."
    ad-do-it
    (while (and  (not  (eobp)) (not ad-return-value))
      (forward-line)
      (setq ad-return-value(dired-move-to-filename)))
    (when (eobp)
      (forward-line -1)
      (setq ad-return-value(dired-move-to-filename))))

  (defadvice dired-previous-line (around dired-previous-line+ activate)
    "Replace current buffer if file is a directory."
    ad-do-it
    (while (and  (not  (bobp)) (not ad-return-value))
      (forward-line -1)
      (setq ad-return-value(dired-move-to-filename)))
    (when (bobp)
      (call-interactively 'dired-next-line)))

  (defvar dired-omit-regexp-orig (symbol-function 'dired-omit-regexp))

  ;; Omit files that Git would ignore
  (defun dired-omit-regexp ()
    (let ((file (expand-file-name ".git"))
          parent-dir)
      (while (and (not (file-exists-p file))
                  (progn
                    (setq parent-dir
                          (file-name-directory
                           (directory-file-name
                            (file-name-directory file))))
                    ;; Give up if we are already at the root dir.
                    (not (string= (file-name-directory file)
                                  parent-dir))))
        ;; Move up to the parent dir and try again.
        (setq file (expand-file-name ".git" parent-dir)))
      ;; If we found a change log in a parent, use that.
      (if (file-exists-p file)
          (let ((regexp (funcall dired-omit-regexp-orig))
                (omitted-files
                 (shell-command-to-string "git clean -d -x -n")))
            (if (= 0 (length omitted-files))
                regexp
              (concat
               regexp
               (if (> (length regexp) 0)
                   "\\|" "")
               "\\("
               (mapconcat
                #'(lambda (str)
                    (concat
                     "^"
                     (regexp-quote
                      (substring str 13
                                 (if (= ?/ (aref str (1- (length str))))
                                     (1- (length str))
                                   nil)))
                     "$"))
                (split-string omitted-files "\n" t)
                "\\|")
               "\\)")))
        (funcall dired-omit-regexp-orig)))))

(use-package dired-ranger
  :load-path "site-lisp/dired-hacks"
  :bind (:map dired-mode-map
              ("W" . dired-ranger-copy)
              ("X" . dired-ranger-move)
              ("Y" . dired-ranger-paste)))

(use-package dired-toggle
  :load-path "site-lisp/dired-toggle"
  :bind ("C-. d" . dired-toggle)
  :preface
  (defun my-dired-toggle-mode-hook ()
    (interactive)
    (visual-line-mode 1)
    (setq-local visual-line-fringe-indicators '(nil right-curly-arrow))
    (setq-local word-wrap nil))
  :hook (dired-toggle-mode . my-dired-toggle-mode-hook))

(use-package dired-x
  :after dired)

(use-package discover
  :disabled t
  :load-path "site-lisp/discover"
  :defer 5
  :commands global-discover-mode
  :hook (dired-mode-hook . dired-turn-on-discover)
  :config
  (global-discover-mode 1))

(use-package discover-my-major
  :load-path "site-lisp/discover-my-major"
  :bind (("C-h <C-m>" . discover-my-major)
         ("C-h M-m"   . discover-my-mode)))

(use-package docker
  :load-path "site-lisp/docker-el"
  :defer 15
  :diminish
  :config
  (require 'docker-images)
  (require 'docker-containers)
  (require 'docker-volumes)
  (require 'docker-networks)
  (docker-global-mode))

(use-package docker-compose-mode
  :load-path "site-lisp/docker-compose-mode"
  :mode "docker-compose.*\.yml\\'")

(use-package docker-tramp
  :load-path "site-lisp/docker-tramp"
  :after tramp
  :defer 5)

(use-package dockerfile-mode
  :load-path "site-lisp/dockerfile-mode"
  :mode "Dockerfile")

(use-package dot-gnus
  :after auth-source-pass
  :bind (("M-G"   . switch-to-gnus)
         ("C-x m" . compose-mail))
  :init
  ;; Have to set these here, because initsplit sends their customization
  ;; values to gnus-settings.el.
  (setq gnus-init-file (emacs-path "dot-gnus")
        gnus-home-directory "~/Messages/Gnus/")

  (defun fetchmail-password ()
    (lookup-password "imap.fastmail.com" "johnw" 993)))

(use-package dot-org
  :load-path ("site-lisp/org-mode/lisp"
              "site-lisp/org-mode/contrib/lisp")
  :commands my-org-startup
  :bind (("M-C"   . jump-to-org-agenda)
         ("M-m"   . org-smart-capture)
         ("M-M"   . org-inline-note)
         ("C-c a" . org-agenda)
         ("C-c S" . org-store-link)
         ("C-c l" . org-insert-link))
  :bind (:map org-mode-map
              ("C-'"))
  :config
  (unless running-alternate-emacs
    (run-with-idle-timer 300 t 'jump-to-org-agenda)
    (my-org-startup)))

(use-package doxymacs
  :load-path "site-lisp/doxymacs/lisp"
  :commands (doxymacs-mode doxymacs-font-lock)
  :config
  (doxymacs-mode 1)
  (doxymacs-font-lock))

(use-package dumb-jump
  :load-path "site-lisp/dumb-jump"
  :hook ((coq-mode haskell-mode) . dumb-jump-mode))

(use-package easy-kill
  :disabled t
  :load-path "site-lisp/easy-kill"
  :bind (("C-. w" . easy-kill)
         ("C-. @" . easy-mark)))

(use-package ebdb-com
  :load-path "site-lisp/ebdb"
  :commands ebdb)

(use-package ediff
  :bind (("C-. = b" . ediff-buffers)
         ("C-. = B" . ediff-buffers3)
         ("C-. = c" . compare-windows)
         ("C-. = =" . ediff-files)
         ("C-. = f" . ediff-files)
         ("C-. = F" . ediff-files3)
         ("C-. = r" . ediff-revision)
         ("C-. = p" . ediff-patch-file)
         ("C-. = P" . ediff-patch-buffer)
         ("C-. = l" . ediff-regions-linewise)
         ("C-. = w" . ediff-regions-wordwise)))

(use-package ediff-keep
  :after ediff)

(use-package edit-env
  :commands edit-env)

(use-package edit-indirect
  :load-path "site-lisp/edit-indirect"
  :bind (("C-c '" . edit-indirect-region)))

(use-package edit-rectangle
  :bind ("C-x r e" . edit-rectangle))

(use-package edit-server
  :if window-system
  :load-path "site-lisp/emacs-chrome/servers"
  :defer 5
  :config
  (edit-server-start))

(use-package edit-var
  :bind ("C-c e v" . edit-variable))

(use-package eldoc
  :diminish
  :hook ((c-mode-common emacs-lisp-mode) . eldoc-mode))

(use-package elfeed
  :load-path "site-lisp/elfeed"
  :bind ("M-F" . elfeed)
  :config
  (add-hook 'elfeed-search-update-hook
            #'(lambda () (selected-minor-mode -1))))

(use-package elint
  :commands (elint-initialize elint-current-buffer)
  :bind ("C-c e E" . my-elint-current-buffer)
  :preface
  (defun my-elint-current-buffer ()
    (interactive)
    (elint-initialize)
    (elint-current-buffer))
  :config
  (add-to-list 'elint-standard-variables 'current-prefix-arg)
  (add-to-list 'elint-standard-variables 'command-line-args-left)
  (add-to-list 'elint-standard-variables 'buffer-file-coding-system)
  (add-to-list 'elint-standard-variables 'emacs-major-version)
  (add-to-list 'elint-standard-variables 'window-system))

(use-package elisp-depend
  :commands elisp-depend-print-dependencies)

(use-package elisp-docstring-mode
  :load-path "site-lisp/elisp-docstring-mode"
  :commands elisp-docstring-mode)

(use-package elisp-slime-nav
  :load-path "site-lisp/elisp-slime-nav"
  :diminish
  :commands (elisp-slime-nav-mode
             elisp-slime-nav-find-elisp-thing-at-point))

(use-package elmacro
  :load-path "site-lisp/elmacro"
  :bind (("C-c m e" . elmacro-mode)
         ("C-x C-)" . elmacro-show-last-macro)))

(use-package emacs-cl
  ;; jww (2017-12-10): This is not building under Emacs 26.
  :disabled t
  :load-path "site-lisp/emacs-cl")

(use-package counsel-gtags
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :load-path "site-lisp/counsel-gtags"
  :after counsel)

(use-package emms-setup
  :load-path "site-lisp/emms/lisp"
  :bind ("M-E" . emms-browser)
  :config
  (emms-all)
  (emms-default-players))

(use-package engine-mode
  :load-path "site-lisp/engine-mode"
  :defer 5
  :config
  (defengine google "https://www.google.com/search?q=%s"
    :keybinding "/")
  (engine-mode 1))

(use-package erc
  :commands (erc erc-tls)
  :bind (:map erc-mode-map
              ("C-c r" . reset-erc-track-mode))
  :preface
  (defun irc (&optional arg)
    (interactive "P")
    (require 'auth-source-pass)
    (if arg
        (pcase-dolist (`(,server . ,nick)
                       '(("irc.freenode.net"     . "johnw")
                         ("irc.gitter.im"        . "jwiegley")
                         ("plclub.irc.slack.com" . "jwiegley")
                         ;; ("irc.oftc.net"         . "johnw")
                         ))
          (erc-tls :server server :port 6697 :nick (concat nick "_")
                   :password (lookup-password server nick 6697)))
      (let ((pass (lookup-password "irc.freenode.net" "johnw" 6697)))
        (erc :server "127.0.0.1" :port 6697 :nick "johnw"
             :password (concat "johnw/gitter:" pass))
        (sleep-for 5)
        (erc :server "127.0.0.1" :port 6697 :nick "johnw"
             :password (concat "johnw/plclub:" pass))
        (sleep-for 5)
        (erc :server "127.0.0.1" :port 6697 :nick "johnw"
             :password (concat "johnw/freenode:" pass)))))

  (defun reset-erc-track-mode ()
    (interactive)
    (setq erc-modified-channels-alist nil)
    (erc-modified-channels-update)
    (erc-modified-channels-display)
    (force-mode-line-update))

  (defun setup-irc-environment ()
    (set (make-local-variable 'scroll-conservatively) 100)
    (setq erc-timestamp-only-if-changed-flag nil
          erc-timestamp-format "%H:%M "
          erc-fill-prefix "          "
          erc-fill-column 78
          erc-insert-timestamp-function 'erc-insert-timestamp-left
          ivy-use-virtual-buffers nil))

  (defcustom erc-foolish-content '()
    "Regular expressions to identify foolish content.
    Usually what happens is that you add the bots to
    `erc-ignore-list' and the bot commands to this list."
    :group 'erc
    :type '(repeat regexp))

  (defun erc-foolish-content (msg)
    "Check whether MSG is foolish."
    (erc-list-match erc-foolish-content msg))

  :init
  (add-hook 'erc-mode-hook #'setup-irc-environment)
  (when running-alternate-emacs
    (add-hook 'after-init-hook 'irc))

  :config
  (erc-track-minor-mode 1)
  (erc-track-mode 1)

  (add-hook 'erc-insert-pre-hook
            #'(lambda (s)
                (when (erc-foolish-content s)
                  (setq erc-insert-this nil)))))

(use-package erc-alert
  :after erc)

(use-package erc-highlight-nicknames
  :after erc)

(use-package erc-macros
  :after erc)

(use-package erc-patch
  :after erc)

(use-package erc-question
  :after erc)

(use-package erc-yank
  :load-path "lisp/erc-yank"
  :after erc
  :bind (:map erc-mode-map
              ("C-y" . erc-yank )))

(use-package erefactor
  :load-path "site-lisp/erefactor"
  :bind (:map emacs-lisp-mode-map
              ("C-c C-v" . erefactor-map)))

(use-package ert
  :bind ("C-c e t" . ert-run-tests-interactively))

(use-package esh-buf-stack
  :load-path "site-lisp/esh-buf-stack"
  :after eshell
  :config
  (setup-eshell-buf-stack)
  (add-hook 'eshell-prepare-command-hook
            #'(lambda ()
                (bind-keys :map eshell-command-map
                           ("M-p" . eshell-push-command)))))

(use-package esh-help
  :load-path "site-lisp/esh-help"
  :after eshell
  :config
  (setup-esh-help-eldoc))

(use-package esh-toggle
  :bind ("C-x C-z" . eshell-toggle))

(use-package eshell
  :commands (eshell eshell-command)
  :preface
  (defvar eshell-isearch-map
    (let ((map (copy-keymap isearch-mode-map)))
      (define-key map [(control ?m)] 'eshell-isearch-return)
      (define-key map [return]       'eshell-isearch-return)
      (define-key map [(control ?r)] 'eshell-isearch-repeat-backward)
      (define-key map [(control ?s)] 'eshell-isearch-repeat-forward)
      (define-key map [(control ?g)] 'eshell-isearch-abort)
      (define-key map [backspace]    'eshell-isearch-delete-char)
      (define-key map [delete]       'eshell-isearch-delete-char)
      map)
    "Keymap used in isearch in Eshell.")

  (defun eshell-initialize ()
    (defun eshell-spawn-external-command (beg end)
      "Parse and expand any history references in current input."
      (save-excursion
        (goto-char end)
        (when (looking-back "&!" beg)
          (delete-region (match-beginning 0) (match-end 0))
          (goto-char beg)
          (insert "spawn "))))

    (add-hook 'eshell-expand-input-functions 'eshell-spawn-external-command)

    (use-package em-unix
      :defer t
      :config
      (unintern 'eshell/su nil)
      (unintern 'eshell/sudo nil)))

  :init
  (add-hook 'eshell-first-time-mode-hook 'eshell-initialize))

(use-package eshell-autojump
  ;; jww (2017-12-10): I'm using eshell-z.
  :disabled t
  :load-path "site-lisp/eshell-autojump")

(use-package eshell-bookmark
  :load-path "site-lisp/eshell-bookmark"
  :hook (eshell-mode . eshell-bookmark-setup))

(use-package eshell-up
  :load-path "site-lisp/eshell-up"
  :commands eshell-up)

(use-package eshell-z
  :load-path "site-lisp/eshell-z"
  :after eshell)

(use-package etags
  :bind ("M-T" . tags-search))

(use-package eval-expr
  :load-path "site-lisp/eval-expr"
  :bind ("M-:" . eval-expr)
  :config
  (defun eval-expr-minibuffer-setup ()
    (set-syntax-table emacs-lisp-mode-syntax-table)
    (paredit-mode)))

(use-package eval-in-repl
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :load-path "site-lisp/eval-in-repl")

(use-package evil
  :load-path "site-lisp/evil"
  :commands evil-mode)

(use-package expand-region
  :load-path "site-lisp/expand-region-el"
  :bind ("C-=" . er/expand-region))

(use-package eyebrowse
  :load-path "site-lisp/eyebrowse"
  :bind-keymap ("C-\\" . eyebrowse-mode-map)
  :bind (:map eyebrowse-mode-map
              ("C-\\ C-\\" . eyebrowse-last-window-config))
  :config
  (eyebrowse-mode))

(use-package fancy-narrow
  :load-path "site-lisp/fancy-narrow"
  :bind (("C-. n" . fancy-narrow-to-region)
         ("C-. N" . fancy-widen))
  :commands (fancy-narrow-to-region fancy-widen))

(use-package feebleline
  :load-path "site-lisp/feebleline"
  :commands feebleline-mode
  :config
  (window-divider-mode t))

(use-package fence-edit
  :load-path "site-lisp/fence-edit"
  :commands fence-edit-code-at-point)

(use-package fetchmail-mode
  :commands fetchmail-mode)

(use-package ffap
  :bind ("C-c v" . ffap))

(use-package flycheck
  :load-path "site-lisp/flycheck"
  :commands (flycheck-mode
             flycheck-next-error
             flycheck-previous-error)
  :init
  (dolist (where '((emacs-lisp-mode-hook . emacs-lisp-mode-map)
                   (haskell-mode-hook    . haskell-mode-map)
                   (js2-mode-hook        . js2-mode-map)
                   (c-mode-common-hook   . c-mode-base-map)))
    (add-hook (car where)
              `(lambda ()
                 (bind-key "M-n" #'flycheck-next-error ,(cdr where))
                 (bind-key "M-p" #'flycheck-previous-error ,(cdr where)))
              t))
  :config
  (defalias 'show-error-at-point-soon
    'flycheck-show-error-at-point))

(use-package flycheck-haskell
  :load-path "site-lisp/flycheck-haskell"
  :after haskell-mode
  :config
  (flycheck-haskell-setup))

(use-package flycheck-hdevtools
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :load-path "site-lisp/flycheck-hdevtools"
  :after flycheck)

(use-package flycheck-package
  :load-path "site-lisp/flycheck-package"
  :after flycheck)

(use-package flycheck-rtags
  :disabled t
  :load-path "~/.nix-profile/share/emacs/site-lisp/rtags"
  :after flycheck)

(use-package flyspell
  :bind (("C-c i b" . flyspell-buffer)
         ("C-c i f" . flyspell-mode))
  :bind (:map flyspell-mode-map
              ("C-."))
  :config
  (defun my-flyspell-maybe-correct-transposition (beg end candidates)
    (unless (let (case-fold-search)
              (string-match "\\`[A-Z0-9]+\\'"
                            (buffer-substring-no-properties beg end)))
      (flyspell-maybe-correct-transposition beg end candidates))))

(use-package focus
  :load-path "site-lisp/focus"
  :commands focus-mode)

(use-package font-lock-studio
  :load-path "site-lisp/font-lock-studio"
  :commands (font-lock-studio
             font-lock-studio-region))

(use-package free-keys
  :load-path "site-lisp/free-keys"
  :commands free-keys)

(use-package fullframe
  :load-path "site-lisp/fullframe"
  :defer t
  :init
  (autoload #'fullframe "fullframe"))

(use-package ggtags
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :load-path "site-lisp/ggtags"
  :commands ggtags-mode
  :diminish)

(use-package ghc
  :disabled t
  :load-path
  (lambda ()
    (cl-mapcan
     #'(lambda (lib) (directory-files lib t "^ghc-"))
     (cl-mapcan
      #'(lambda (lib) (directory-files lib t "^elpa$"))
      (seq-filter (apply-partially #'string-match "-emacs-ghc-") load-path))))
  :after haskell-mode
  :commands ghc-init
  :hook (haskell-mode . ghc-init)
  :config
  (setenv "cabal_helper_libexecdir"
          (file-name-directory
           (substring
            (shell-command-to-string "which cabal-helper-wrapper") 0 -1))))

(use-package gist
  :no-require t
  :bind ("C-c G" . my-gist-region-or-buffer)
  :preface
  (defun my-gist-region-or-buffer (start end)
    (interactive "r")
    (copy-region-as-kill start end)
    (deactivate-mark)
    (let ((file-name buffer-file-name))
      (with-temp-buffer
        (if file-name
            (call-process "gist" nil t nil "-f" file-name "-P")
          (call-process "gist" nil t nil "-P"))
        (kill-ring-save (point-min) (1- (point-max)))
        (message (buffer-substring (point-min) (1- (point-max))))))))

(use-package git-link
  :load-path "site-lisp/git-link"
  :bind ("C-. G" . git-link)
  :commands (git-link git-link-commit git-link-homepage))

(use-package git-modes
  :load-path "site-lisp/git-modes"
  :defer 5
  :config
  (require 'gitattributes-mode)
  (require 'gitconfig-mode)
  (require 'gitignore-mode))

(use-package git-timemachine
  :load-path "site-lisp/git-timemachine"
  :commands git-timemachine)

(use-package git-undo
  :load-path "lisp/git-undo-el"
  :bind ("C-. C-/" . git-undo))

(use-package github-pullrequest
  :load-path "site-lisp/github-pullrequest"
  :commands (github-pullrequest-new
             github-pullrequest-checkout))

(use-package gitpatch
  :load-path "site-lisp/gitpatch"
  :commands gitpatch-mail)

(use-package google-this
  :load-path "site-lisp/google-this"
  :bind-keymap ("C-. /" . google-this-mode-submap)
  :bind ("A-M-f" . google-this-search))

(use-package goto-last-change
  :bind ("C-x C-/" . goto-last-change))

(use-package graphviz-dot-mode
  :load-path "site-lisp/graphviz-dot-mode"
  :mode "\\.dot\\'")

(use-package grep
  :bind (("M-s d" . find-name-dired)
         ("M-s F" . find-grep)
         ("M-s g" . grep)
         ("M-s m" . find-grep-dired)))

(use-package gud
  :commands gud-gdb
  :bind (("<f9>"    . gud-cont)
         ("<f10>"   . gud-next)
         ("<f11>"   . gud-step)
         ("S-<f11>" . gud-finish))
  :init
  (defun show-debugger ()
    (interactive)
    (let ((gud-buf
           (catch 'found
             (dolist (buf (buffer-list))
               (if (string-match "\\*gud-" (buffer-name buf))
                   (throw 'found buf))))))
      (if gud-buf
          (switch-to-buffer-other-window gud-buf)
        (call-interactively 'gud-gdb)))))

(use-package haskell-edit
  :load-path "lisp/haskell-config"
  :after haskell-mode
  :bind (:map haskell-mode-map
              ("C-c M-q" . haskell-edit-reformat)))

(use-package haskell-mode
  :load-path "site-lisp/haskell-mode"
  :mode (("\\.hs\\(c\\|-boot\\)?\\'" . haskell-mode)
         ("\\.lhs\\'" . literate-haskell-mode)
         ("\\.cabal\\'" . haskell-cabal-mode))
  :bind (:map haskell-mode-map
              ("C-c C-h" . my-haskell-hoogle)
              ("C-c C-," . haskell-navigate-imports)
              ("C-c C-." . haskell-mode-format-imports)
              ("C-c C-u" . my-haskell-insert-undefined)
              ("M-s")
              ("M-t"))
  :preface
  (defun my-haskell-insert-undefined ()
    (interactive) (insert "undefined"))

  (defun snippet (name)
    (interactive "sName: ")
    (find-file (expand-file-name (concat name ".hs") "~/src/notes"))
    (haskell-mode)
    (goto-char (point-min))
    (when (eobp)
      (insert "hdr")
      (yas-expand)))

  (defvar hoogle-server-process nil)
  (defun my-haskell-hoogle (query &optional arg)
    "Do a Hoogle search for QUERY."
    (interactive
     (let ((def (haskell-ident-at-point)))
       (if (and def (symbolp def)) (setq def (symbol-name def)))
       (list (read-string (if def
                              (format "Hoogle query (default %s): " def)
                            "Hoogle query: ")
                          nil nil def)
             current-prefix-arg)))
    (unless (and hoogle-server-process
                 (process-live-p hoogle-server-process))
      (message "Starting local Hoogle server on port 8687...")
      (with-current-buffer (get-buffer-create " *hoogle-web*")
        (cd temporary-file-directory)
        (setq hoogle-server-process
              (start-process "hoogle-web" (current-buffer) "hoogle"
                             "server" "--local" "--port=8687")))
      (message "Starting local Hoogle server on port 8687...done"))
    (browse-url
     (format "http://127.0.0.1:8687/?hoogle=%s"
             (replace-regexp-in-string
              " " "+" (replace-regexp-in-string "\\+" "%2B" query)))))

  (defvar haskell-prettify-symbols-alist
    '(("::"     . ?∷)
      ("forall" . ?∀)
      ("exists" . ?∃)
      ("->"     . ?→)
      ("<-"     . ?←)
      ("=>"     . ?⇒)
      ("~>"     . ?⇝)
      ("<~"     . ?⇜)
      ("<>"     . ?⨂)
      ("msum"   . ?⨁)
      ("\\"     . ?λ)
      ("not"    . ?¬)
      ("&&"     . ?∧)
      ("||"     . ?∨)
      ("/="     . ?≠)
      ("<="     . ?≤)
      (">="     . ?≥)
      ("<<<"    . ?⋘)
      (">>>"    . ?⋙)

      ("`elem`"             . ?∈)
      ("`notElem`"          . ?∉)
      ("`member`"           . ?∈)
      ("`notMember`"        . ?∉)
      ("`union`"            . ?∪)
      ("`intersection`"     . ?∩)
      ("`isSubsetOf`"       . ?⊆)
      ("`isProperSubsetOf`" . ?⊂)
      ("undefined"          . ?⊥)))

  :config
  (require 'haskell)
  (require 'haskell-doc)

  (defun my-haskell-mode-hook ()
    (haskell-indentation-mode)
    (interactive-haskell-mode)
    (flycheck-mode 1)
    (setq-local prettify-symbols-alist haskell-prettify-symbols-alist)
    (prettify-symbols-mode 1)
    (bug-reference-prog-mode 1))

  (add-hook 'haskell-mode-hook 'my-haskell-mode-hook)

  (eval-after-load 'align
    '(nconc
      align-rules-list
      (mapcar #'(lambda (x)
                  `(,(car x)
                    (regexp . ,(cdr x))
                    (modes quote (haskell-mode literate-haskell-mode))))
              '((haskell-types       . "\\(\\s-+\\)\\(::\\|∷\\)\\s-+")
                (haskell-assignment  . "\\(\\s-+\\)=\\s-+")
                (haskell-arrows      . "\\(\\s-+\\)\\(->\\|→\\)\\s-+")
                (haskell-left-arrows . "\\(\\s-+\\)\\(<-\\|←\\)\\s-+"))))))

(use-package helm
  :load-path "site-lisp/helm"
  :if (not running-alternate-emacs)
  :bind (:map helm-map
              ("<tab>" . helm-execute-persistent-action)
              ("C-i"   . helm-execute-persistent-action)
              ("C-z"   . helm-select-action)
              ("A-v"   . helm-previous-page))
  :config
  (helm-autoresize-mode 1))

(use-package helm-dash
  :load-path "site-lisp/helm-dash"
  :commands helm-dash)

(use-package helm-descbinds
  :load-path "site-lisp/helm-descbinds"
  :bind ("C-h b" . helm-descbinds)
  :init
  (fset 'describe-bindings 'helm-descbinds))

(use-package helm-describe-modes
  :load-path "site-lisp/helm-describe-modes"
  :after helm
  :bind ("C-h m" . helm-describe-modes))

(use-package helm-firefox
  :load-path "site-lisp/helm-firefox"
  :commands helm-firefox
  :bind ("A-M-b" . helm-firefox-bookmarks))

(use-package helm-google
  :load-path "site-lisp/helm-google"
  :commands helm-google
  :bind ("A-M-g" . helm-google))

(use-package helm-navi
  :load-path "site-lisp/helm-navi"
  :after (helm navi)
  :commands helm-navi)

(use-package helpful
  :load-path "site-lisp/helpful"
  :bind (("C-h e F" . helpful-function)
         ("C-h e C" . helpful-command)
         ("C-h e M" . helpful-macro)
         ("C-h e L" . helpful-callable)
         ("C-h e S" . helpful-at-point)
         ("C-h e V" . helpful-variable)))

(use-package hi-lock
  :bind (("M-o l" . highlight-lines-matching-regexp)
         ("M-o r" . highlight-regexp)
         ("M-o w" . highlight-phrase)))

(use-package hideif
  :diminish hide-ifdef-mode
  :hook (c-mode-common . hide-ifdef-mode))

(use-package hideshow
  :diminish hs-minor-mode
  :hook (prog-mode . hs-minor-mode)
  :bind (:map prog-mode-map
              ("C-c h" . hs-toggle-hiding)))

(use-package highlight
  :bind (("C-. h h" . hlt-highlight-region)
         ("C-. h u" . hlt-unhighlight-region)))

(use-package highlight-cl
  :hook (emacs-lisp-mode . highlight-cl-add-font-lock-keywords))

(use-package highlight-defined
  :load-path "site-lisp/highlight-defined"
  :commands highlight-defined-mode)

(use-package highlight-numbers
  :load-path "site-lisp/highlight-numbers"
  :hook (prog-mode . highlight-numbers-mode))

(use-package hilit-chg
  :bind ("M-o C" . highlight-changes-mode))

(use-package hippie-exp
  :bind (("M-/"   . hippie-expand)
         ("C-M-/" . dabbrev-completion)))

(use-package hl-line
  :commands hl-line-mode
  :bind ("M-o h" . hl-line-mode))

(use-package hl-line+
  :after hl-line)

(use-package hydra
  :load-path "site-lisp/hydra"
  :defer t
  :config
  (defhydra hydra-zoom (global-map "<f2>")
    "zoom"
    ("g" text-scale-increase "in")
    ("l" text-scale-decrease "out")))

(use-package hyperbole
  :load-path "site-lisp/hyperbole"
  :defer 10
  :bind* (("C-M-." . hkey-either)
          ("A-<return>" . hkey-operate))
  :init
  (setq hbmap:dir-user (expand-file-name "hyperb" user-data-directory))
  :config
  (when (eq temp-buffer-show-function #'hkey-help-show)
    (setq temp-buffer-show-function nil))
  (remove-hook 'temp-buffer-show-hook #'hkey-help-show)

  (defact visit-haskell-definition ()
    "Go to the definition of a symbol in Haskell."
    (interactive)
    (condition-case err
        (call-interactively #'haskell-mode-jump-to-def-or-tag)
      (error
       (call-interactively #'dumb-jump-go))))

  (defib haskell-definition-link ()
    "Go to the definition of a symbol in Haskell."
    (and (eq major-mode 'haskell-mode)
         (hact #'visit-haskell-definition)))

  (defib gnus-article-urls-link ()
    "Visit the URLs in a Gnus article."
    (and (eq major-mode 'gnus-summary-mode)
         (hact #'gnus-article-browse-urls))))

(use-package ibuffer
  :bind ("C-x C-b" . ibuffer)
  :init
  (add-hook 'ibuffer-mode-hook
            #'(lambda ()
                (ibuffer-switch-to-saved-filter-groups "default"))))

(use-package ibuffer-vc
  :load-path "site-lisp/ibuffer-vc"
  :commands ibuffer-vc-set-filter-groups-by-vc-root
  :hook (ibuffer . (lambda ()
                     (ibuffer-vc-set-filter-groups-by-vc-root)
                     (unless (eq ibuffer-sorting-mode 'alphabetic)
                       (ibuffer-do-sort-by-alphabetic)))))

(use-package ido
  ;; jww (2017-12-10): I now use ivy.
  :disabled t
  :bind (("C-x b" . ido-switch-buffer)
         ("C-x B" . ido-switch-buffer-other-window)))

(use-package iedit
  :load-path "site-lisp/iedit"
  :defer t)

(use-package ielm
  :commands ielm
  :bind (:map ielm-map ("<return>" . my-ielm-return))
  :config
  (defun my-ielm-return ()
    (interactive)
    (let ((end-of-sexp (save-excursion
                         (goto-char (point-max))
                         (skip-chars-backward " \t\n\r")
                         (point))))
      (if (>= (point) end-of-sexp)
          (progn
            (goto-char (point-max))
            (skip-chars-backward " \t\n\r")
            (delete-region (point) (point-max))
            (call-interactively #'ielm-return))
        (call-interactively #'paredit-newline)))))

(use-package iflipb
  :load-path "site-lisp/iflipb"
  :bind* ("<S-return>" . my-iflipb-next-buffer)
  :commands (iflipb-next-buffer iflipb-previous-buffer)
  :preface
  (defvar my-iflipb-auto-off-timeout-sec 1)
  (defvar my-iflipb-auto-off-timer nil)
  (defvar my-iflipb-auto-off-timer-canceler-internal nil)
  (defvar my-iflipb-ing-internal nil)

  (defun my-iflipb-auto-off ()
    (setq my-iflipb-auto-off-timer-canceler-internal nil
          my-iflipb-ing-internal nil)
    (when my-iflipb-auto-off-timer
      (message nil)
      (cancel-timer my-iflipb-auto-off-timer)
      (setq my-iflipb-auto-off-timer nil)))

  (defun my-iflipb-next-buffer (arg)
    (interactive "P")
    (iflipb-next-buffer arg)
    (if my-iflipb-auto-off-timer-canceler-internal
        (cancel-timer my-iflipb-auto-off-timer-canceler-internal))
    (setq my-iflipb-auto-off-timer
          (run-with-idle-timer my-iflipb-auto-off-timeout-sec 0
                               'my-iflipb-auto-off)
          my-iflipb-ing-internal t))

  (defun my-iflipb-previous-buffer ()
    (interactive)
    (iflipb-previous-buffer)
    (if my-iflipb-auto-off-timer-canceler-internal
        (cancel-timer my-iflipb-auto-off-timer-canceler-internal))
    (setq my-iflipb-auto-off-timer
          (run-with-idle-timer my-iflipb-auto-off-timeout-sec 0
                               'my-iflipb-auto-off)
          my-iflipb-ing-internal t))

  :config
  (setq iflipb-always-ignore-buffers
        "\\`\\( \\|diary\\|ipa\\|\\.newsrc-dribble\\'\\)"
        iflipb-wrap-around t)

  (defun iflipb-first-iflipb-buffer-switch-command ()
    (not (and (or (eq last-command 'my-iflipb-next-buffer)
                  (eq last-command 'my-iflipb-previous-buffer))
              my-iflipb-ing-internal))))

(use-package image-file
  :defer 5
  :config
  (auto-image-file-mode 1))

(use-package imenu-list
  :load-path "site-lisp/imenu-list"
  :commands imenu-list-minor-mode)

(use-package indent
  :commands indent-according-to-mode)

(use-package indent-shift
  :load-path "site-lisp/indent-shift"
  :bind (("C-c <" . indent-shift-left)
         ("C-c >" . indent-shift-right)))

(use-package inf-ruby
  :load-path "site-lisp/ruby-mode"
  :after ruby-mode
  :hook (ruby-mode . inf-ruby-keys))

(use-package info
  :bind ("C-h C-i" . info-lookup-symbol))

(use-package info-look
  :defer t
  :init
  (autoload 'info-lookup-add-help "info-look"))

(use-package info-lookmore
  :load-path "site-lisp/info-lookmore"
  :after info-look
  :config
  (info-lookmore-elisp-cl)
  (info-lookmore-elisp-userlast)
  (info-lookmore-elisp-gnus)
  (info-lookmore-apropos-elisp))

(use-package initsplit
  :load-path "lisp/initsplit"
  :after cus-edit
  :defer 5)

(use-package ialign
  :load-path "site-lisp/interactive-align"
  :bind ("C-. [" . ialign-interactive-align))

(use-package inventory
  :commands (inventory sort-package-declarations))

(use-package ipcalc
  :load-path "site-lisp/ipcalc"
  :commands ipcalc)

(use-package isearch
  :no-require t
  :bind (("C-M-r" . isearch-backward-other-window)
         ("C-M-s" . isearch-forward-other-window))
  :bind (:map isearch-mode-map
              ("C-c" . isearch-toggle-case-fold)
              ("C-t" . isearch-toggle-regexp)
              ("C-^" . isearch-edit-string)
              ("C-i" . isearch-complete))
  :preface
  (defun isearch-backward-other-window ()
    (interactive)
    (split-window-vertically)
    (other-window 1)
    (call-interactively 'isearch-backward))

  (defun isearch-forward-other-window ()
    (interactive)
    (split-window-vertically)
    (other-window 1)
    (call-interactively 'isearch-forward)))

(use-package ispell
  :no-require t
  :bind (("C-c i c" . ispell-comments-and-strings)
         ("C-c i d" . ispell-change-dictionary)
         ("C-c i k" . ispell-kill-ispell)
         ("C-c i m" . ispell-message)
         ("C-c i r" . ispell-region)))

(use-package ivy
  :load-path "site-lisp/swiper"
  :defer 5
  :diminish

  :bind (("C-x b" . ivy-switch-buffer)
         ("C-x B" . ivy-switch-buffer-other-window)
         ("M-H"   . ivy-resume))

  :bind (:map ivy-minibuffer-map
              ("<tab>" . ivy-alt-done)
              ("SPC"   . ivy-alt-done-or-space)
              ("C-d"   . ivy-done-or-delete-char)
              ("C-i"   . ivy-partial-or-done)
              ("C-r"   . ivy-previous-line-or-history)
              ("M-r"   . ivy-reverse-i-search))

  :bind (:map ivy-switch-buffer-map
              ("C-k" . ivy-switch-buffer-kill))

  :custom
  (ivy-dynamic-exhibit-delay-ms 200)
  (ivy-height 10)
  (ivy-initial-inputs-alist nil t)
  (ivy-magic-tilde nil)
  (ivy-re-builders-alist '((t . ivy--regex-ignore-order)))
  (ivy-use-virtual-buffers t)
  (ivy-wrap t)

  :preface
  (defun ivy-done-or-delete-char ()
    (interactive)
    (call-interactively
     (if (eolp)
         #'ivy-immediate-done
       #'ivy-delete-char)))

  (defun ivy-alt-done-or-space ()
    (interactive)
    (call-interactively
     (if (= ivy--length 1)
         #'ivy-alt-done
       #'self-insert-command)))

  (defun ivy-switch-buffer-kill ()
    (interactive)
    (debug)
    (let ((bn (ivy-state-current ivy-last)))
      (when (get-buffer bn)
        (kill-buffer bn))
      (unless (buffer-live-p (ivy-state-buffer ivy-last))
        (setf (ivy-state-buffer ivy-last)
              (with-ivy-window (current-buffer))))
      (setq ivy--all-candidates (delete bn ivy--all-candidates))
      (ivy--exhibit)))

  ;; This is the value of `magit-completing-read-function', so that we see
  ;; Magit's own sorting choices.
  (defun my-ivy-completing-read (&rest args)
    (let ((ivy-sort-functions-alist '((t . nil))))
      (apply 'ivy-completing-read args)))

  :config
  (ivy-mode 1)
  (ivy-set-occur 'ivy-switch-buffer 'ivy-switch-buffer-occur))

(use-package ivy-bibtex
  :load-path "site-lisp/helm-bibtex"
  :commands ivy-bibtex)

(use-package ivy-hydra
  :after (ivy hydra)
  :defer t)

(use-package ivy-pass
  :load-path "site-lisp/ivy-pass"
  :commands ivy-pass)

(use-package ivy-rich
  :load-path "site-lisp/ivy-rich"
  :after ivy
  :demand t
  :config
  (ivy-set-display-transformer 'ivy-switch-buffer
                               'ivy-rich-switch-buffer-transformer)
  (setq ivy-virtual-abbreviate 'full
        ivy-rich-switch-buffer-align-virtual-buffer t
        ivy-rich-path-style 'abbrev))

(use-package ivy-rtags
  :disabled t
  :load-path "~/.nix-profile/share/emacs/site-lisp/rtags"
  :after (ivy rtags))

(use-package jq-mode
  :load-path "site-lisp/jq-mode"
  :mode "\\.jq\\'")

(use-package js2-mode
  :load-path "site-lisp/js2-mode"
  :mode "\\.js\\'"
  :config
  (add-to-list 'flycheck-disabled-checkers #'javascript-jshint)
  (flycheck-add-mode 'javascript-eslint 'js2-mode)
  (flycheck-mode 1))

(use-package js3-mode
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :load-path "site-lisp/js3-mode")

(use-package json-mode
  :load-path "site-lisp/json-mode"
  :mode "\\.json\\'")

(use-package json-reformat
  :load-path "site-lisp/json-reformat"
  :after json-mode)

(use-package json-snatcher
  :load-path "site-lisp/json-snatcher"
  :after json-mode)

(use-package key-chord
  :commands key-chord-mode)

(use-package know-your-http-well
  :load-path "site-lisp/know-your-http-well/emacs"
  :commands (http-header
             http-method
             http-relation
             http-status-code
             media-type))

(use-package kotl-mode
  :load-path "site-lisp/hyperbole/kotl"
  :mode "\\.kotl\\'")

(use-package langtool
  :load-path "site-lisp/langtool"
  :bind ("C-. l" . langtool-check))

(use-package latex
  :after auctex
  :config
  (require 'preview)
  (load (emacs-path "site-lisp/auctex/style/minted"))
  (info-lookup-add-help :mode 'LaTeX-mode
                        :regexp ".*"
                        :parse-rule "\\\\?[a-zA-Z]+\\|\\\\[^a-zA-Z]"
                        :doc-spec '(("(latex2e)Concept Index")
                                    ("(latex2e)Command Index"))))

(use-package ledger-mode
  :load-path "~/src/ledger/lisp"
  :commands ledger-mode
  :bind ("C-c L" . my-ledger-start-entry)
  :preface
  (defun my-ledger-start-entry (&optional arg)
    (interactive "p")
    (find-file-other-window "/Volumes/Files/Accounts/ledger.dat")
    (goto-char (point-max))
    (skip-syntax-backward " ")
    (if (looking-at "\n\n")
        (goto-char (point-max))
      (delete-region (point) (point-max))
      (insert ?\n)
      (insert ?\n))
    (insert (format-time-string "%Y/%m/%d ")))

  (defun ledger-matchup ()
    (interactive)
    (while (re-search-forward "\\(\\S-+Unknown\\)\\s-+\\$\\([-,0-9.]+\\)"
                              nil t)
      (let ((account-beg (match-beginning 1))
            (account-end (match-end 1))
            (amount (match-string 2))
            account answer)
        (goto-char account-beg)
        (set-window-point (get-buffer-window) (point))
        (recenter)
        (redraw-display)
        (with-current-buffer (get-buffer "nrl-mastercard-old.dat")
          (goto-char (point-min))
          (when (re-search-forward (concat "\\(\\S-+\\)\\s-+\\$" amount)
                                   nil t)
            (setq account (match-string 1))
            (goto-char (match-beginning 1))
            (set-window-point (get-buffer-window) (point))
            (recenter)
            (redraw-display)
            (setq answer
                  (read-char (format "Is this a match for %s (y/n)? "
                                     account)))))
        (when (eq answer ?y)
          (goto-char account-beg)
          (delete-region account-beg account-end)
          (insert account))
        (forward-line)))))

(use-package lentic-mode
  :load-path "site-lisp/lentic"
  :diminish
  :commands global-lentic-mode)

(use-package lisp-mode
  :defer t
  :hook ((emacs-lisp-mode lisp-mode)
         . (lambda () (add-hook 'after-save-hook 'check-parens nil t)))
  :init
  (dolist (mode '(ielm-mode
                  inferior-emacs-lisp-mode
                  inferior-lisp-mode
                  lisp-interaction-mode
                  lisp-mode
                  emacs-lisp-mode))
    (font-lock-add-keywords
     mode
     '(("(\\(lambda\\)\\>"
        (0 (ignore
            (compose-region (match-beginning 1)
                            (match-end 1) ?λ))))
       ("(\\(ert-deftest\\)\\>[         '(]*\\(setf[    ]+\\sw+\\|\\sw+\\)?"
        (1 font-lock-keyword-face)
        (2 font-lock-function-name-face
           nil t))))))

(use-package lispy
  :load-path "site-lisp/lispy"
  :commands lispy-mode
  :bind (:map lispy-mode-map
              ("M-j"))
  :bind (:map emacs-lisp-mode-map
              ("C-1"     . lispy-describe-inline)
              ("C-2"     . lispy-arglist-inline)
              ("C-c C-j" . lispy-goto)))

(use-package llvm-mode
  :mode "\\.ll\\'")

(use-package lsp-haskell
  ;; jww (2017-11-26): https://github.com/haskell/haskell-ide-engine/issues/117
  :disabled t
  :load-path "site-lisp/lsp-haskell")

(use-package lsp-mode
  ;; jww (2017-11-26): Need to install LSP for Haskell
  :disabled t
  :load-path "site-lisp/lsp-mode")

(use-package lua-mode
  :load-path "site-lisp/lua-mode"
  :mode "\\.lua\\'"
  :interpreter "lua")

(use-package lusty-explorer
  :disabled t
  :load-path "site-lisp/lusty-emacs"
  :bind (("C-x C-f" . my-lusty-file-explorer))
  :preface
  (defun lusty-read-directory ()
    "Launch the file/directory mode of LustyExplorer."
    (interactive)
    (require 'lusty-explorer)
    (let ((lusty--active-mode :file-explorer))
      (lusty--define-mode-map)
      (let* ((lusty--ignored-extensions-regex
              (concat "\\(?:" (regexp-opt completion-ignored-extensions)
                      "\\)$"))
             (minibuffer-local-filename-completion-map lusty-mode-map)
             (lusty-only-directories t))
        (lusty--run 'read-directory-name default-directory ""))))

  (defun lusty-read-file-name
      (prompt &optional dir default-filename mustmatch initial predicate)
    "Launch the file/directory mode of LustyExplorer."
    (interactive)
    (require 'lusty-explorer)
    (let ((lusty--active-mode :file-explorer)
          (ivy-mode-prev (and (boundp 'ivy-mode) ivy-mode)))
      (if (fboundp 'ivy-mode)
          (ivy-mode -1))
      (unwind-protect
          (progn
            (lusty--define-mode-map)
            (let* ((lusty--ignored-extensions-regex
                    (concat "\\(?:" (regexp-opt completion-ignored-extensions)
                            "\\)$"))
                   (minibuffer-local-filename-completion-map lusty-mode-map)
                   (lusty-only-directories nil))
              (lusty--run 'read-file-name
                          dir default-filename mustmatch initial predicate)))
        (if (fboundp 'ivy-mode)
            (ivy-mode (if ivy-mode-prev 1 -1))))))

  (defun my-lusty-file-explorer ()
    "Launch the file/directory mode of LustyExplorer."
    (interactive)
    (require 'lusty-explorer)
    (let ((lusty--active-mode :file-explorer)
          (ivy-mode-prev (and (boundp 'ivy-mode) ivy-mode)))
      (if (fboundp 'ivy-mode)
          (ivy-mode -1))
      (unwind-protect
          (progn
            (lusty--define-mode-map)
            (let* ((lusty--ignored-extensions-regex
                    (concat "\\(?:" (regexp-opt
                                     completion-ignored-extensions) "\\)$"))
                   (minibuffer-local-filename-completion-map lusty-mode-map)
                   (file
                    ;; read-file-name is silly in that if the result is equal
                    ;; to the dir argument, it gets converted to the
                    ;; default-filename argument.  Set it explicitly to "" so
                    ;; if lusty-launch-dired is called in the directory we
                    ;; start at, the result is that directory instead of the
                    ;; name of the current buffer.
                    (lusty--run 'read-file-name default-directory "")))
              (when file
                (switch-to-buffer
                 (find-file-noselect
                  (expand-file-name file))))))
        (if (fboundp 'ivy-mode)
            (ivy-mode (if ivy-mode-prev 1 -1))))))

  :config
  (defun my-lusty-setup-hook ()
    (bind-key "SPC" #'lusty-select-match lusty-mode-map)
    (bind-key "C-d" #'exit-minibuffer lusty-mode-map)
    (bind-key "C-M-j" #'exit-minibuffer lusty-mode-map))

  (add-hook 'lusty-setup-hook 'my-lusty-setup-hook)

  (defun lusty-open-this ()
    "Open the given file/directory/buffer, creating it if not already present."
    (interactive)
    (when lusty--active-mode
      (ecase lusty--active-mode
        (:file-explorer
         (let* ((path (minibuffer-contents-no-properties))
                (last-char (aref path (1- (length path)))))
           (lusty-select-match)
           (lusty-select-current-name)))
        (:buffer-explorer (lusty-select-match)))))

  (defvar lusty-only-directories nil)
  (defun lusty-file-explorer-matches (path)
    (let* ((dir (lusty-normalize-dir (file-name-directory path)))
           (file-portion (file-name-nondirectory path))
           (files
            (and dir
                 ;; NOTE: directory-files is quicker but
                 ;;       doesn't append slash for directories.
                 ;;(directory-files dir nil nil t)
                 (file-name-all-completions "" dir)))
           (filtered (lusty-filter-files
                      file-portion
                      (if lusty-only-directories
                          (loop for f in files
                                when (= ?/ (aref f (1- (length f))))
                                collect f)
                        files))))
      (if (or (string= file-portion "")
              (string= file-portion "."))
          (sort filtered 'string<)
        (lusty-sort-by-fuzzy-score filtered file-portion)))))

(use-package macrostep
  :load-path "site-lisp/macrostep"
  :bind ("C-c e m" . macrostep-expand))

(use-package magit
  :load-path ("site-lisp/magit/lisp"
              "lib/with-editor")
  :bind (("C-x g" . magit-status)
         ("C-x G" . magit-status-with-prefix))
  :bind (:map magit-mode-map
              ("U" . magit-unstage-all)
              ("M-h")
              ("M-s")
              ("M-m")
              ("M-w"))
  :bind (:map magit-file-section-map ("<C-return>"))
  :bind (:map magit-hunk-section-map ("<C-return>"))
  :preface
  (defun magit-monitor (&optional no-display)
    "Start git-monitor in the current directory."
    (interactive)
    (let* ((path (file-truename
                  (directory-file-name
                   (expand-file-name default-directory))))
           (name (format "*git-monitor: %s*"
                         (file-name-nondirectory path))))
      (unless (and (get-buffer name)
                   (with-current-buffer (get-buffer name)
                     (string= path (directory-file-name default-directory))))
        (with-current-buffer (get-buffer-create name)
          (cd path)
          (ignore-errors
            (start-process "*git-monitor*" (current-buffer)
                           "git-monitor" "-d" path))))))

  (defun magit-status-with-prefix ()
    (interactive)
    (let ((current-prefix-arg '(4)))
      (call-interactively 'magit-status)))

  (defun eshell/git (&rest args)
    (cond
     ((or (null args)
          (and (string= (car args) "status") (null (cdr args))))
      (magit-status-internal default-directory))
     ((and (string= (car args) "log") (null (cdr args)))
      (magit-log "HEAD"))
     (t (throw 'eshell-replace-command
               (eshell-parse-command
                "*git"
                (eshell-stringify-list (eshell-flatten-list args)))))))

  :hook (magit-mode . hl-line-mode)
  :init
  (setenv "GIT_PAGER" "")
  :config
  (use-package magit-commit
    :config
    (use-package git-commit))

  (use-package magit-files
    :config
    (global-magit-file-mode))

  (add-hook 'magit-status-mode-hook #'(lambda () (magit-monitor t)))

  (defvar magit--rev-parse-toplevel-cache (make-hash-table :test #'equal))
  (defvar magit--rev-parse-cdup-cache (make-hash-table :test #'equal))
  (defvar magit--rev-parse-git-dir-cache (make-hash-table :test #'equal))

  (defmacro magit--use-rev-parse-cache (cmd args)
    `(pcase ,args
       ('("--show-toplevel")
        (or (gethash default-directory magit--rev-parse-toplevel-cache)
            (let ((dir ,cmd))
              (puthash default-directory dir magit--rev-parse-toplevel-cache)
              dir)))
       ('("--show-cdup")
        (or (gethash default-directory magit--rev-parse-cdup-cache)
            (let ((dir ,cmd))
              (puthash default-directory dir magit--rev-parse-cdup-cache)
              dir)))
       ('("--git-dir")
        (or (gethash default-directory magit--rev-parse-git-dir-cache)
            (let ((dir ,cmd))
              (puthash default-directory dir magit--rev-parse-git-dir-cache)
              dir)))
       (_ ,cmd)))

  (defun magit-rev-parse (&rest args)
    "Execute `git rev-parse ARGS', returning first line of output.
  If there is no output, return nil."
    (magit--use-rev-parse-cache
     (apply #'magit-git-string "rev-parse" args) args))

  (defun magit-rev-parse-safe (&rest args)
    "Execute `git rev-parse ARGS', returning first line of output.
  If there is no output, return nil.  Like `magit-rev-parse' but
  ignore `magit-git-debug'."
    (magit--use-rev-parse-cache
     (apply #'magit-git-str "rev-parse" args) args))

  (eval-after-load 'magit-remote
    '(progn
       (magit-define-popup-action 'magit-fetch-popup
         ?f 'magit-get-remote #'magit-fetch-from-upstream ?u t)
       (magit-define-popup-action 'magit-pull-popup
         ?F 'magit-get-upstream-branch #'magit-pull-from-upstream ?u t)
       (magit-define-popup-action 'magit-push-popup
         ?P 'magit--push-current-to-upstream-desc
         #'magit-push-current-to-upstream ?u t))))

(use-package magit-popup
  :load-path "site-lisp/magit-popup"
  :defer t)

(use-package magit-imerge
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :load-path "site-lisp/magit-imerge"
  :after magit)

(use-package magithub
  :load-path "site-lisp/magithub"
  :after magit
  :config
  (magithub-feature-autoinject t)

  (defvar my-ghub-token-cache nil)

  (advice-add
   'ghub--token :around
   #'(lambda (orig-func host username package &optional nocreate)
       (or my-ghub-token-cache
           (setq my-ghub-token-cache
                 (funcall orig-func host username package nocreate))))))

(use-package makefile-runner
  :load-path "site-lisp/makefile-runner"
  :bind ("C-c M-C" . makefile-runner))

(use-package malyon
  :load-path "site-lisp/malyon"
  :commands malyon
  :config
  (defun replace-invisiclues ()
    (interactive)
    (query-replace-regexp
     "^\\( +\\)\\(\\([A-Z]\\)\\. \\)?\\(.+\\)"
     (quote (replace-eval-replacement
             concat "\\1\\2" (replace-quote (rot13 (match-string 4)))))
     nil (if (use-region-p) (region-beginning))
     (if (use-region-p) (region-end)) nil nil)))

(use-package markdown-mode
  :load-path "site-lisp/markdown-mode"
  :mode (("\\`README\\.md\\'" . gfm-mode)
         ("\\.md\\'"          . markdown-mode)
         ("\\.markdown\\'"    . markdown-mode))
  :init (setq markdown-command "multimarkdown"))

(use-package markdown-preview-mode
  :load-path "site-lisp/markdown-preview-mode"
  :after markdown-mode
  :config
  (setq markdown-preview-stylesheets
        (list (concat "https://github.com/dmarcotte/github-markdown-preview/"
                      "blob/master/data/css/github.css"))))

(use-package math-symbol-lists
  :load-path "site-lisp/math-symbol-lists"
  :defer t)

(use-package mc-extras
  :load-path "site-lisp/mc-extras"
  :after multiple-cursors
  :bind (("<C-m> M-C-f" . mc/mark-next-sexps)
         ("<C-m> M-C-b" . mc/mark-previous-sexps)
         ("<C-m> <"     . mc/mark-all-above)
         ("<C-m> >"     . mc/mark-all-below)
         ("<C-m> C-d"   . mc/remove-current-cursor)
         ("<C-m> C-k"   . mc/remove-cursors-at-eol)
         ("<C-m> M-d"   . mc/remove-duplicated-cursors)
         ("<C-m> |"     . mc/move-to-column)
         ("<C-m> ~"     . mc/compare-chars)))

(use-package mc-freeze
  :load-path "site-lisp/mc-extras"
  :after multiple-cursors
  :bind ("<C-m> f" . mc/freeze-fake-cursors-dwim))

(use-package mc-rect
  :load-path "site-lisp/mc-extras"
  :after multiple-cursors
  :bind ("C-\"" . mc/rect-rectangle-to-multiple-cursors))

(use-package mediawiki
  :load-path "site-lisp/mediawiki"
  :commands mediawiki-open)

(use-package memory-usage
  :load-path "site-lisp/memory-usage"
  :commands memory-usage)

(use-package mhtml-mode
  :bind (:map html-mode-map
              ("<return>" . newline-and-indent)))

(use-package mic-paren
  :defer 5
  :config
  (paren-activate))

(use-package midnight
  :bind ("C-c z" . clean-buffer-list))

(use-package minimap
  :load-path "site-lisp/minimap"
  :commands minimap-mode)

(use-package mmm-mode
  :load-path "site-lisp/mmm-mode"
  :defer t)

(use-package moccur-edit
  :load-path "site-lisp/moccur-edit"
  :after color-moccur)

(use-package mode-line-bell
  :load-path "site-lisp/mode-line-bell"
  :defer 5
  :config
  (mode-line-bell-mode))

(use-package monitor
  :load-path "site-lisp/monitor"
  :defer t
  :init
  (autoload #'define-monitor "monitor"))

(use-package mudel
  :commands mudel
  :bind ("C-c M" . mud)
  :init
  (defun mud ()
    (interactive)
    (mudel "4dimensions" "4dimensions.org" 6000)))

(use-package mule
  :no-require t
  :config
  (prefer-coding-system 'utf-8)
  (set-terminal-coding-system 'utf-8)
  (setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING)))

(use-package multi-term
  :load-path "site-lisp/multi-term"
  :bind (("C-. t" . multi-term-next)
         ("C-. T" . multi-term))
  :init
  (defun screen ()
    (interactive)
    (let (term-buffer)
      ;; Set buffer.
      (setq term-buffer
            (let ((multi-term-program (executable-find "screen"))
                  (multi-term-program-switches "-DR"))
              (multi-term-get-buffer)))
      (set-buffer term-buffer)
      (multi-term-internal)
      (switch-to-buffer term-buffer)))

  :config
  (require 'term)

  (defalias 'my-term-send-raw-at-prompt 'term-send-raw)

  (defun my-term-end-of-buffer ()
    (interactive)
    (call-interactively #'end-of-buffer)
    (if (and (eobp) (bolp))
        (delete-char -1)))

  (defadvice term-process-pager (after term-process-rebind-keys activate)
    (define-key term-pager-break-map  "\177" 'term-pager-back-page)))

(use-package multifiles
  :load-path "site-lisp/multifiles-el"
  :bind ("C-c m f" . mf/mirror-region-in-multifile))

(use-package multiple-cursors
  :load-path "site-lisp/multiple-cursors"
  :after phi-search
  :defer 5

  ;; - Sometimes you end up with cursors outside of your view. You can scroll
  ;;   the screen to center on each cursor with `C-v` and `M-v`.
  ;;
  ;; - If you get out of multiple-cursors-mode and yank - it will yank only
  ;;   from the kill-ring of main cursor. To yank from the kill-rings of every
  ;;   cursor use yank-rectangle, normally found at C-x r y.

  :bind (("C-'" . set-rectangular-region-anchor)

         ("<C-m> ^"     . mc/edit-beginnings-of-lines)
         ("<C-m> `"     . mc/edit-beginnings-of-lines)
         ("<C-m> $"     . mc/edit-ends-of-lines)
         ("<C-m> '"     . mc/edit-ends-of-lines)
         ("<C-m> R"     . mc/reverse-regions)
         ("<C-m> S"     . mc/sort-regions)
         ("<C-m> W"     . mc/mark-all-words-like-this)
         ("<C-m> Y"     . mc/mark-all-symbols-like-this)
         ("<C-m> a"     . mc/mark-all-like-this-dwim)
         ("<C-m> c"     . mc/mark-all-dwim)
         ("<C-m> l"     . mc/insert-letters)
         ("<C-m> n"     . mc/insert-numbers)
         ("<C-m> r"     . mc/mark-all-in-region)
         ("<C-m> /"     . mc/mark-all-in-region-regexp)
         ("<C-m> t"     . mc/mark-sgml-tag-pair)
         ("<C-m> w"     . mc/mark-next-like-this-word)
         ("<C-m> x"     . mc/mark-more-like-this-extended)
         ("<C-m> y"     . mc/mark-next-like-this-symbol)
         ("<C-m> C-x"   . reactivate-mark)
         ("<C-m> C-SPC" . mc/mark-pop)
         ("<C-m> ("     . mc/mark-all-symbols-like-this-in-defun)
         ("<C-m> C-("   . mc/mark-all-words-like-this-in-defun)
         ("<C-m> M-("   . mc/mark-all-like-this-in-defun)
         ("<C-m> ["     . mc/vertical-align-with-space)
         ("<C-m> {"     . mc/vertical-align)

         ("S-<down-mouse-1>")
         ("S-<mouse-1>" . mc/add-cursor-on-click))

  :bind (:map selected-keymap
              ("C-'" . mc/edit-lines)
              ("c"   . mc/edit-lines)
              ("."   . mc/mark-next-like-this)
              ("<"   . mc/unmark-next-like-this)
              ("C->" . mc/skip-to-next-like-this)
              (","   . mc/mark-previous-like-this)
              (">"   . mc/unmark-previous-like-this)
              ("C-<" . mc/skip-to-previous-like-this)
              ("y"   . mc/mark-next-symbol-like-this)
              ("Y"   . mc/mark-previous-symbol-like-this)
              ("w"   . mc/mark-next-word-like-this)
              ("W"   . mc/mark-previous-word-like-this))

  :preface
  (defun reactivate-mark ()
    (interactive)
    (activate-mark)))

(use-package navi-mode
  :load-path "site-lisp/navi"
  :after outshine
  :bind ("M-s s" . navi-search-and-switch))

(use-package nf-procmail-mode
  :commands nf-procmail-mode)

(use-package nginx-mode
  :load-path "site-lisp/nginx-mode"
  :commands nginx-mode)

(use-package nix-buffer
  :load-path "site-lisp/nix-buffer"
  :commands nix-buffer)

(use-package nix-mode
  :load-path "site-lisp/nix-mode"
  :mode "\\.nix\\'")

(use-package nov
  :load-path "site-lisp/nov-el"
  :mode ("\\.epub\\'" . nov-mode))

(use-package nroff-mode
  :commands nroff-mode
  :config
  (defun update-nroff-timestamp ()
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^\\.Dd " nil t)
        (let ((stamp (format-time-string "%B %e, %Y")))
          (unless (looking-at stamp)
            (delete-region (point) (line-end-position))
            (insert stamp)
            (let (after-save-hook)
              (save-buffer)))))))

  (add-hook 'nroff-mode-hook
            #'(lambda () (add-hook 'after-save-hook 'update-nroff-timestamp nil t))))

(use-package nxml-mode
  :commands nxml-mode
  :bind (:map nxml-mode-map
              ("<return>" . newline-and-indent)
              ("C-c M-h"  . tidy-xml-buffer))
  :preface
  (defun tidy-xml-buffer ()
    (interactive)
    (save-excursion
      (call-process-region (point-min) (point-max) "tidy" t t nil
                           "-xml" "-i" "-wrap" "0" "-omit" "-q" "-utf8")))
  :init
  (defalias 'xml-mode 'nxml-mode)
  :config
  (autoload 'sgml-skip-tag-forward "sgml-mode")
  (add-to-list 'hs-special-modes-alist
               '(nxml-mode
                 "<!--\\|<[^/>]*[^/]>"
                 "-->\\|</[^/>]*[^/]>"
                 "<!--"
                 sgml-skip-tag-forward
                 nil)))

(use-package olivetti
  :load-path "site-lisp/olivetti"
  :commands olivetti-mode)

(use-package operate-on-number
  :load-path "site-lisp/operate-on-number"
  :bind ("C-. '" . operate-on-number-at-point))

(use-package origami
  :load-path "site-lisp/origami"
  :commands origami-mode)

(use-package outline
  :diminish outline-minor-mode
  :hook ((emacs-lisp-mode LaTeX-mode) . outline-minor-mode))

(use-package outorg
  :load-path "site-lisp/outorg"
  :after outshine)

(use-package outshine
  :load-path "site-lisp/outshine"
  :after (:or outline org-mode)
  :hook (outline-minor-mode . outshine-hook-function))

(use-package ovpn-mode
  :load-path "site-lisp/ovpn-mode"
  :commands ovpn)

(use-package package-lint
  :load-path "site-lisp/package-lint"
  :commands package-lint-current-buffer)

(use-package pandoc-mode
  :load-path "site-lisp/pandoc-mode"
  :hook (markdown-mode
         (pandoc-mode   . pandoc-load-default-settings)))

(use-package paradox
  :load-path "site-lisp/paradox"
  :commands paradox-list-packages)

(use-package paredit
  :load-path "site-lisp/paredit"
  :diminish
  :hook ((lisp-mode emacs-lisp-mode) . paredit-mode)
  :bind (:map paredit-mode-map
              ("[")
              ("M-k"   . paredit-raise-sexp)
              ("M-I"   . paredit-splice-sexp)
              ("C-M-l" . paredit-recentre-on-sexp)

              ("C-. M-f" . paredit-forward-down)
              ("C-. B" . paredit-splice-sexp-killing-backward)
              ("C-. C" . paredit-convolute-sexp)
              ("C-. F" . paredit-splice-sexp-killing-forward)
              ("C-. a" . paredit-add-to-next-list)
              ("C-. A" . paredit-add-to-previous-list)
              ("C-. j" . paredit-join-with-next-list)
              ("C-. J" . paredit-join-with-previous-list))
  :bind (:map lisp-mode-map       ("<return>" . paredit-newline))
  :bind (:map emacs-lisp-mode-map ("<return>" . paredit-newline))
  :hook (paredit-mode
         . (lambda ()
             (unbind-key "M-r" paredit-mode-map)
             (unbind-key "M-s" paredit-mode-map)))
  :config
  (require 'eldoc)
  (eldoc-add-command 'paredit-backward-delete
                     'paredit-close-round))

(use-package paredit-ext
  :after paredit)

(use-package parinfer
  :load-path "site-lisp/parinfer-mode"
  :bind ("C-. C-(" . parinfer-toggle-mode)
  :config
  (setq parinfer-extensions '(defaults paredit smart-yank)))

(use-package pass
  :load-path "site-lisp/pass"
  :commands (pass pass-view-mode)
  :mode ("\\.passwords/.*\\.gpg\\'" . pass-view-mode))

(use-package password-store
  :load-path "site-lisp/password-store/contrib/emacs"
  :defer 5
  :commands (password-store-insert
             password-store-copy
             password-store-get)
  :config
  (defun password-store--run-edit (entry)
    (require 'pass)
    (find-file (concat (expand-file-name entry (password-store-dir))
                       ".gpg"))))

(use-package password-store-otp
  :load-path "site-lisp/password-store-otp"
  :defer t
  :config
  (defun password-store-otp-append-from-image (entry)
    "Check clipboard for an image and scan it to get an OTP URI,
append it to ENTRY."
    (interactive (list (read-string "Password entry: ")))
    (let ((qr-image-filename (password-store-otp--get-qr-image-filename entry)))
      (when (not (zerop (call-process "screencapture" nil nil nil
                                      "-T5" qr-image-filename)))
        (error "Couldn't get image from clipboard"))
      (with-temp-buffer
        (condition-case nil
            (call-process "zbarimg" nil t nil "-q" "--raw"
                          qr-image-filename)
          (error
           (error "It seems you don't have `zbar-tools' installed")))
        (password-store-otp-append
         entry
         (buffer-substring (point-min) (point-max))))
      (when (not password-store-otp-screenshots-path)
        (delete-file qr-image-filename)))))

(use-package pcre2el
  :load-path "site-lisp/pcre2el"
  :commands (rxt-mode rxt-global-mode))

(use-package pdf-tools
  :load-path "site-lisp/pdf-tools/lisp"
  :magic ("%PDF" . pdf-view-mode)
  :config
  (dolist
      (pkg
       '(pdf-annot pdf-cache pdf-dev pdf-history pdf-info pdf-isearch
                   pdf-links pdf-misc pdf-occur pdf-outline pdf-sync
                   pdf-util pdf-view pdf-virtual))
    (require pkg))
  (pdf-tools-install))

(use-package per-window-point
  :load-path "site-lisp/per-window-point"
  :defer 5
  :commands pwp-mode
  :config
  (pwp-mode 1))

(use-package persistent-scratch
  :load-path "site-lisp/persistent-scratch"
  :unless (or (null window-system)
              running-alternate-emacs
              noninteractive)
  :defer 5
  :config
  (persistent-scratch-autosave-mode)
  (with-demoted-errors "Error: %S"
    (persistent-scratch-setup-default))
  :commands persistent-scratch-setup-default)

(use-package personal
  :init
  (define-key key-translation-map (kbd "A-TAB") (kbd "C-TAB"))
  :commands unfill-region
  :bind (("M-L"  . mark-line)
         ("M-S"  . mark-sentence)
         ("M-j"  . delete-indentation-forward)

         ("C-c )"   . close-all-parentheses)
         ("C-c 0"   . recursive-edit-preserving-window-config-pop)
         ("C-c 1"   . recursive-edit-preserving-window-config)
         ("C-c C-0" . copy-current-buffer-name)
         ("C-c C-z" . delete-to-end-of-buffer)
         ("C-c M-q" . unfill-paragraph)
         ("C-c V"   . view-clipboard)
         ("C-c e P" . check-papers)
         ("C-c e b" . do-eval-buffer)
         ("C-c e r" . do-eval-region)
         ("C-c e s" . scratch)
         ("C-c n"   . insert-user-timestamp)
         ("C-x C-d" . duplicate-line)
         ("C-x C-v" . find-alternate-file-with-sudo)
         ("C-x K"   . delete-current-buffer-file)
         ("C-x M-q" . refill-paragraph))
  :init
  (bind-keys ("<C-M-backspace>" . backward-kill-sexp)

             ("M-!"   . async-shell-command)
             ("M-'"   . insert-pair)
             ("M-J"   . delete-indentation)
             ("M-\""  . insert-pair)
             ("M-`"   . other-frame)
             ("M-g c" . goto-char)
             ("C-M-;" . comment-and-copy)

             ("C-c ="   . count-matches)
             ("C-c SPC" . just-one-space)
             ("C-c e c" . cancel-debug-on-entry)
             ("C-c e d" . debug-on-entry)
             ("C-c e e" . toggle-debug-on-error)
             ("C-c e f" . emacs-lisp-byte-compile-and-load)
             ("C-c e j" . emacs-lisp-mode)
             ("C-c e z" . byte-recompile-directory)
             ("C-c f"   . flush-lines)
             ("C-c g"   . goto-line)
             ("C-c k"   . keep-lines)
             ("C-c m k" . kmacro-keymap)
             ("C-c m m" . emacs-toggle-size)
             ("C-c q"   . fill-region)
             ("C-c s"   . replace-string)
             ("C-c u"   . rename-uniquely)
             ("C-h e a" . apropos-value)
             ("C-h e e" . view-echo-area-messages)
             ("C-h e f" . find-function)
             ("C-h e k" . find-function-on-key)
             ("C-h e v" . find-variable)
             ("C-h v"   . describe-variable)
             ("C-x C-e" . pp-eval-last-sexp)
             ("C-x d"   . delete-whitespace-rectangle)
             ("C-x t"   . toggle-truncate-lines)
             ("C-z"     . delete-other-windows)))

(use-package phi-search
  :load-path "site-lisp/phi-search"
  :defer 5)

(use-package phi-search-mc
  :load-path "site-lisp/phi-search-mc"
  :after (phi-search multiple-cursors)
  :config
  (phi-search-mc/setup-keys)
  (add-hook 'isearch-mode-mode #'phi-search-from-isearch-mc/setup-keys))

(use-package po-mode
  :mode "\\.\\(po\\'\\|po\\.\\)")

(use-package popup-ruler
  :bind ("C-. C-r" . popup-ruler))

(use-package pp-c-l
  :hook (prog-mode . pretty-control-l-mode))

(use-package prodigy
  :load-path "site-lisp/prodigy"
  :commands prodigy)

(use-package projectile
  :load-path "site-lisp/projectile"
  :defer 5
  :diminish
  :bind* ("C-c TAB" . projectile-find-other-file)
  :bind-keymap ("C-c p" . projectile-command-map)
  :config
  (projectile-global-mode))

(use-package proof-site
  :load-path ("site-lisp/proof-general/generic"
              "site-lisp/proof-general/lib"
              "site-lisp/proof-general/coq")
  :defer 5
  :preface
  (defun my-layout-proof-windows ()
    (interactive)
    (proof-layout-windows)
    (proof-prf))

  :config
  (use-package coq
    :defer t
    :config

    (defalias 'coq-Search #'coq-SearchConstant)
    (defalias 'coq-SearchPattern #'coq-SearchIsos)

    (bind-keys :map coq-mode-map
               ("M-RET"       . proof-goto-point)
               ("RET"         . newline-and-indent)
               ("C-c h")
               ("C-c C-p"     . my-layout-proof-windows)
               ("C-c C-a C-s" . coq-Search)
               ("C-c C-a C-o" . coq-SearchPattern)
               ("C-c C-a C-a" . coq-SearchAbout)
               ("C-c C-a C-r" . coq-SearchRewrite))

    (add-hook 'coq-mode-hook
              #'(lambda ()
                  (set-input-method "Agda")
                  (holes-mode -1)
                  (company-coq-mode 1)
                  (set (make-local-variable 'fill-nobreak-predicate)
                       #'(lambda ()
                           (pcase (get-text-property (point) 'face)
                             ('font-lock-comment-face nil)
                             ((and (pred listp)
                                   x (guard (memq 'font-lock-comment-face x)))
                              nil)
                             (_ t)))))))

  (use-package pg-user
    :defer t
    :config
    (defadvice proof-retract-buffer
        (around my-proof-retract-buffer activate)
      (condition-case err ad-do-it
        (error (shell-command "killall coqtop"))))))

(use-package prover
  :after coq)

(use-package ps-print
  :defer t
  :preface
  (defun ps-spool-to-pdf (beg end &rest ignore)
    (interactive "r")
    (let ((temp-file (concat (make-temp-name "ps2pdf") ".pdf")))
      (call-process-region beg end (executable-find "ps2pdf")
                           nil nil nil "-" temp-file)
      (call-process (executable-find "open") nil nil nil temp-file)))
  :config
  (setq ps-print-region-function 'ps-spool-to-pdf))

(use-package python-mode
  :load-path "site-lisp/python-mode"
  :mode "\\.py\\'"
  :interpreter "python"
  :bind (:map python-mode-map
              ("C-c c")
              ("C-c C-z" . python-shell))
  :config
  (defvar python-mode-initialized nil)

  (defun my-python-mode-hook ()
    (unless python-mode-initialized
      (setq python-mode-initialized t)

      (info-lookup-add-help
       :mode 'python-mode
       :regexp "[a-zA-Z_0-9.]+"
       :doc-spec
       '(("(python)Python Module Index" )
         ("(python)Index"
          (lambda
            (item)
            (cond
             ((string-match
               "\\([A-Za-z0-9_]+\\)() (in module \\([A-Za-z0-9_.]+\\))" item)
              (format "%s.%s" (match-string 2 item)
                      (match-string 1 item)))))))))

    (set (make-local-variable 'parens-require-spaces) nil)
    (setq indent-tabs-mode nil))

  (add-hook 'python-mode-hook 'my-python-mode-hook))

(use-package rainbow-delimiters
  :load-path "site-lisp/rainbow-delimiters"
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package rainbow-mode
  :load-path "site-lisp/rainbow-mode"
  :commands rainbow-mode)

(use-package recentf
  :defer 10
  :commands (recentf-mode
             recentf-add-file
             recentf-apply-filename-handlers)
  :preface
  (defun recentf-add-dired-directory ()
    (if (and dired-directory
             (file-directory-p dired-directory)
             (not (string= "/" dired-directory)))
        (let ((last-idx (1- (length dired-directory))))
          (recentf-add-file
           (if (= ?/ (aref dired-directory last-idx))
               (substring dired-directory 0 last-idx)
             dired-directory)))))
  :hook (dired-mode . recentf-add-dired-directory)
  :config
  (recentf-mode 1))

(use-package rect
  :bind ("C-. r t" . rectangle-mark-mode))

(use-package redshank
  :load-path "site-lisp/redshank"
  :diminish
  :hook ((lisp-mode emacs-lisp-mode) . redshank-mode))

(use-package reftex
  :after auctex
  :hook (LaTeX-mode . reftex-mode))

(use-package regex-tool
  :load-path "lisp/regex-tool"
  :commands regex-tool)

(use-package repl-toggle
  ;; jww (2017-12-10): Need to configure.
  :disabled t
  :load-path "site-lisp/repl-toggle")

(use-package restclient
  :load-path "site-lisp/restclient"
  :mode ("\\.rest\\'" . restclient-mode))

(use-package reveal-in-osx-finder
  :no-require t
  :bind ("C-c M-v" .
         (lambda () (interactive)
           (call-process "/usr/bin/open" nil nil nil
                         "-R" (expand-file-name
                               (or (buffer-file-name)
                                   default-directory))))))

(use-package riscv-mode
  :load-path "site-lisp/riscv-mode"
  :commands riscv-mode)

(use-package rtags
  ;; jww (2018-01-09): https://github.com/Andersbakken/rtags/issues/1123
  :disabled t
  :load-path "~/.nix-profile/share/emacs/site-lisp/rtags"
  :commands rtags-mode
  :bind (("C-. r D" . rtags-dependency-tree)
         ("C-. r F" . rtags-fixit)
         ("C-. r R" . rtags-rename-symbol)
         ("C-. r T" . rtags-tagslist)
         ("C-. r d" . rtags-create-doxygen-comment)
         ("C-. r c" . rtags-display-summary)
         ("C-. r e" . rtags-print-enum-value-at-point)
         ("C-. r f" . rtags-find-file)
         ("C-. r i" . rtags-include-file)
         ("C-. r i" . rtags-symbol-info)
         ("C-. r m" . rtags-imenu)
         ("C-. r n" . rtags-next-match)
         ("C-. r p" . rtags-previous-match)
         ("C-. r r" . rtags-find-references)
         ("C-. r s" . rtags-find-symbol)
         ("C-. r v" . rtags-find-virtuals-at-point))
  :bind (:map c-mode-base-map
              ("M-." . rtags-find-symbol-at-point)))

(use-package ruby-mode
  :load-path "site-lisp/ruby-mode"
  :mode "\\.rb\\'"
  :interpreter "ruby"
  :bind (:map ruby-mode-map
              ("<return>" . my-ruby-smart-return))
  :preface
  (defun my-ruby-smart-return ()
    (interactive)
    (when (memq (char-after) '(?\| ?\" ?\'))
      (forward-char))
    (call-interactively 'newline-and-indent)))

(use-package savehist
  :unless noninteractive
  :defer 5
  :config
  (savehist-mode 1))

(use-package saveplace
  :unless noninteractive
  :defer 5
  :config
  (save-place-mode 1))

(use-package sdcv-mode
  :load-path "site-lisp/sdcv"
  :bind ("C-. w" . my-sdcv-search)
  :config
  (defvar sdcv-index nil)

  (defun my-sdcv-search ()
    (interactive)
    (flet ((read-string
            (prompt &optional initial-input history
                    default-value inherit-input-method)
            (ivy-read prompt
                      (or sdcv-index
                          (with-temp-buffer
                            (insert-file-contents
                             "~/.local/share/dictionary/websters.index")
                            (goto-char (point-max))
                            (insert ")")
                            (goto-char (point-min))
                            (insert "(")
                            (goto-char (point-min))
                            (setq sdcv-index (read (current-buffer)))))
                      :history history
                      :initial-input initial-input
                      :def default-value)))
      (call-interactively #'sdcv-search))))

(use-package selected
  :load-path "site-lisp/selected"
  :defer 5
  :diminish selected-minor-mode
  :bind (:map selected-keymap
              ("[" . align-code)
              ("f" . fill-region)
              ("U" . unfill-region)
              ("d" . downcase-region)
              ("u" . upcase-region)
              ("r" . reverse-region)
              ("s" . sort-lines))
  :config
  (selected-global-mode 1))

(use-package server
  :unless (or noninteractive
              running-alternate-emacs)
  :no-require
  :hook (after-init . server-start))

(use-package sh-script
  :defer t
  :init
  (defvar sh-script-initialized nil)
  (defun initialize-sh-script ()
    (unless sh-script-initialized
      (setq sh-script-initialized t)
      (info-lookup-add-help :mode 'shell-script-mode
                            :regexp ".*"
                            :doc-spec '(("(bash)Index")))))
  (add-hook 'shell-mode-hook 'initialize-sh-script))

(use-package sh-toggle
  :bind ("C-. C-z" . shell-toggle))

(use-package shackle
  :load-path "site-lisp/shackle"
  :defer 5
  :commands shackle-mode
  :config
  (shackle-mode 1))

(use-package shift-number
  :load-path "site-lisp/shift-number"
  :bind (("C-. +" . shift-number-up)
         ("C-. -" . shift-number-down)))

(use-package slime
  :load-path "site-lisp/slime"
  :commands slime
  :init
  ;; (unless (memq major-mode
  ;;               '(emacs-lisp-mode inferior-emacs-lisp-mode ielm-mode))
  ;;   (turn-on-cldoc-mode)
  ;;   ("M-q" . slime-reindent-defun)
  ;;   ("M-l" . slime-selector))

  (setq inferior-lisp-program "sbcl"
        slime-contribs '(slime-fancy)))

(use-package smart-jump
  :disabled t
  :load-path "site-lisp/smart-jump"
  :bind ("M-." . smart-jump-go)
  :config
  (smart-jump-register :modes '(emacs-lisp-mode lisp-interaction-mode)
                       :jump-fn 'elisp-slime-nav-find-elisp-thing-at-point
                       :pop-fn 'pop-tag-mark
                       :should-jump t
                       :heuristic 'error
                       :async nil))

(use-package smart-mode-line
  :load-path "site-lisp/smart-mode-line"
  :defer 10
  :config
  (sml/setup)
  (sml/apply-theme 'light)
  (remove-hook 'display-time-hook 'sml/propertize-time-string))

(use-package smart-newline
  :load-path "site-lisp/smart-newline"
  :diminish
  :commands smart-newline-mode)

(use-package smart-region
  :disabled t
  :load-path "site-lisp/smart-region"
  :bind ("S-SPC" . smart-region))

(use-package smartparens-config
  :load-path "site-lisp/smartparens"
  :commands smartparens-mode)

(use-package smartscan
  :load-path "site-lisp/smart-scan"
  :defer 5
  :bind (:map smartscan-map
              ("C->" . smartscan-symbol-go-forward)
              ("C-<" . smartscan-symbol-go-backward)))

(use-package smedl-mode
  :load-path "~/bae/xhtml-deliverable/xhtml/mon/smedl/emacs"
  :mode "\\.\\(a4\\)?smedl\\'")

(use-package smerge-mode
  :commands smerge-mode)

(use-package smex
  :load-path "site-lisp/smex"
  :defer 5
  :commands smex)

(use-package sort-words
  :load-path "site-lisp/sort-words"
  :commands sort-words)

(use-package sos
  :load-path "site-lisp/sos"
  :commands sos)

(use-package sql-indent
  :load-path "site-lisp/sql-indent"
  :commands sqlind-minor-mode)

(use-package stopwatch
  :load-path "site-lisp/stopwatch"
  :bind ("<f8>" . stopwatch))

(use-package string-edit
  :load-path "site-lisp/string-edit"
  :bind ("C-c C-'" . string-edit-at-point))

(use-package string-inflection
  :load-path "site-lisp/string-inflection"
  :bind ("C-c C-u" . string-inflection-all-cycle))

(use-package sunrise-commander
  :load-path "site-lisp/sunrise-commander"
  :bind (("C-c j" . my-activate-sunrise)
         ("C-c C-j" . sunrise-cd))
  :bind (:map sr-mode-map
              ("/"     . sr-sticky-isearch-forward)
              ("q"     . sr-history-prev)
              ("z"     . sr-quit)
              ("C-e")
              ("C-x t" . sr-toggle-truncate-lines)
              ("<backspace>" . sr-scroll-quick-view-down))
  :bind (:map sr-tabs-mode-map
              ("C-p")
              ("C-n")
              ("M-[" . sr-tabs-prev)
              ("M-]" . sr-tabs-next))
  :bind (:map sr-term-line-minor-mode-map
              ("M-<backspace>"))
  :commands sunrise
  :preface
  (defun my-activate-sunrise ()
    (interactive)
    (let ((sunrise-exists
           (loop for buf in (buffer-list)
                 when (string-match " (Sunrise)$" (buffer-name buf))
                 return buf)))
      (if sunrise-exists
          (call-interactively 'sunrise)
        (sunrise "~/dl/" "~/Archives/"))))

  :config
  (require 'sunrise-x-modeline)
  (require 'sunrise-x-tree)
  (require 'sunrise-x-tabs)

  (defun sr-browse-file (&optional file)
    "Display the selected file with the default appication."
    (interactive)
    (setq file (or file (dired-get-filename)))
    (save-selected-window
      (sr-select-viewer-window)
      (let ((buff (current-buffer))
            (fname (if (file-directory-p file)
                       file
                     (file-name-nondirectory file)))
            (app (cond
                  ((eq system-type 'darwin)       "open %s")
                  ((eq system-type 'windows-nt)   "open %s")
                  (t                              "xdg-open %s"))))
        (start-process-shell-command "open" nil (format app file))
        (unless (eq buff (current-buffer))
          (sr-scrollable-viewer (current-buffer)))
        (message "Opening \"%s\" ..." fname)))))

(use-package super-save
  :load-path "site-lisp/super-save"
  :diminish
  :commands super-save-mode
  :config
  (setq super-save-auto-save-when-idle t))

(use-package swiper
  :load-path "site-lisp/swiper"
  :after ivy
  :bind (("C-. C-s" . swiper)
         ("C-. C-r" . swiper))
  :bind (:map swiper-map
              ("M-y" . yank)
              ("M-%" . swiper-query-replace)
              ("M-h" . swiper-avy)
              ("M-c" . swiper-mc))
  :commands swiper-from-isearch
  :init
  (bind-keys :map isearch-mode-map ("C-." . swiper-from-isearch)))

(use-package tablegen-mode
  :mode "\\.td\\'")

(use-package tagedit
  :load-path "site-lisp/tagedit"
  :commands tagedit-mode)

(use-package texinfo
  :mode ("\\.texi\\'" . texinfo-mode)
  :config
  (defun my-texinfo-mode-hook ()
    (dolist (mapping '((?b . "emph")
                       (?c . "code")
                       (?s . "samp")
                       (?d . "dfn")
                       (?o . "option")
                       (?x . "pxref")))
      (local-set-key (vector (list 'alt (car mapping)))
                     `(lambda () (interactive)
                        (TeX-insert-macro ,(cdr mapping))))))

  (add-hook 'texinfo-mode-hook 'my-texinfo-mode-hook)

  (defun texinfo-outline-level ()
    ;; Calculate level of current texinfo outline heading.
    (require 'texinfo)
    (save-excursion
      (if (bobp)
          0
        (forward-char 1)
        (let* ((word (buffer-substring-no-properties
                      (point) (progn (forward-word 1) (point))))
               (entry (assoc word texinfo-section-list)))
          (if entry
              (nth 1 entry)
            5))))))

(use-package tidy
  :commands (tidy-buffer
             tidy-parse-config-file
             tidy-save-settings
             tidy-describe-options))

(use-package tramp-sh
  :defer t
  :config
  (add-to-list 'tramp-remote-path "/run/current-system/sw/bin"))

(use-package transpose-mark
  :load-path "site-lisp/transpose-mark"
  :commands (transpose-mark
             transpose-mark-line
             transpose-mark-region))

(use-package treemacs
  :load-path "site-lisp/treemacs"
  :commands treemacs)

(use-package tuareg
  :load-path "site-lisp/tuareg"
  :mode (("\\.ml[4ip]?\\'" . tuareg-mode)
         ("\\.eliomi?\\'"  . tuareg-mode)))

(use-package typo
  :load-path "site-lisp/typo"
  :commands typo-mode)

(use-package undo-tree
  ;; jww (2017-12-10): This package often breaks the ability to "undo in
  ;; region". Also, its backup files often get corrupted, so this sub-feature
  ;; is disabled in settings.el.
  :disabled t
  :load-path "site-lisp/undo-tree"
  :demand t
  :bind ("C-M-/" . undo-tree-redo)
  :config
  (global-undo-tree-mode))

(use-package vdiff
  :load-path "site-lisp/vdiff"
  :commands (vdiff-files
             vdiff-files3
             vdiff-buffers
             vdiff-buffers3))

(use-package vimish-fold
  :load-path "site-lisp/vimish-fold"
  :bind (("C-. f f" . vimish-fold)
         ("C-. f d" . vimish-fold-delete)
         ("C-. f D" . vimish-fold-delete-all)))

(use-package visual-fill-column
  :load-path "site-lisp/visual-fill-column"
  :commands visual-fill-column-mode)

(use-package visual-regexp
  :load-path "site-lisp/visual-regexp"
  :bind (("C-c r"   . vr/replace)
         ("C-c %"   . vr/query-replace)
         ("C-c C->" . vr/mc-mark)))

(use-package visual-regexp-steroids
  ;; jww (2017-12-10): I prefer to use Emacs regexps within Emacs.
  :disabled t
  :load-path "site-lisp/visual-regexp-steroids"
  :after visual-regexp)

(use-package vlf
  :disabled t
  :load-path "site-lisp/vlfi"
  :defer 5
  :init
  (setq-default vlf-tune-max (* 512 1024)))

(use-package vline
  :commands vline-mode)

(use-package w3m
  :load-path "site-lisp/w3m"
  :commands w3m-browse-url)

(use-package web-mode
  :load-path "site-lisp/web-mode"
  :commands web-mode)

(use-package wgrep
  :load-path "site-lisp/wgrep"
  :defer 5)

(use-package which-func
  :hook (c-mode-common . which-function-mode))

(use-package which-key
  :load-path "site-lisp/which-key"
  :defer 5
  :diminish
  :commands which-key-mode
  :config
  (which-key-mode))

(use-package whitespace
  :diminish (global-whitespace-mode
             whitespace-mode
             whitespace-newline-mode)
  :commands (whitespace-buffer
             whitespace-cleanup
             whitespace-mode
             whitespace-turn-off)
  :preface
  (defun normalize-file ()
    (interactive)
    (save-excursion
      (goto-char (point-min))
      (whitespace-cleanup)
      (delete-trailing-whitespace)
      (goto-char (point-max))
      (delete-blank-lines)
      (set-buffer-file-coding-system 'unix)
      (goto-char (point-min))
      (while (re-search-forward "\r$" nil t)
        (replace-match ""))
      (set-buffer-file-coding-system 'utf-8)
      (let ((require-final-newline t))
        (save-buffer))))

  (defun maybe-turn-on-whitespace ()
    "depending on the file, maybe clean up whitespace."
    (when (and (not (or (memq major-mode '(markdown-mode))
                        (and buffer-file-name
                             (string-match "\\(\\.texi\\|commit_editmsg\\)\\'"
                                           buffer-file-name))))
               (locate-dominating-file default-directory ".clean")
               (not (locate-dominating-file default-directory ".noclean")))
      (add-hook 'write-contents-hooks
                #'(lambda () (ignore (whitespace-cleanup))) nil t)
      (whitespace-cleanup)))

  :init
  (add-hook 'find-file-hooks 'maybe-turn-on-whitespace t)

  :config
  (remove-hook 'find-file-hooks 'whitespace-buffer)
  (remove-hook 'kill-buffer-hook 'whitespace-buffer)

  ;; For some reason, having these in settings.el gets ignored if whitespace
  ;; loads lazily.
  (setq whitespace-auto-cleanup t
        whitespace-line-column 110
        whitespace-rescan-timer-time nil
        whitespace-silent t
        whitespace-style '(face trailing lines space-before-tab empty)))

(use-package whitespace-cleanup-mode
  :load-path "site-lisp/whitespace-cleanup-mode"
  :defer 5
  :diminish
  :commands whitespace-cleanup-mode
  :config
  (global-whitespace-cleanup-mode 1))

(use-package whole-line-or-region
  :unless (or noninteractive
              running-alternate-emacs)
  :load-path "site-lisp/whole-line-or-region"
  :defer 5
  :diminish whole-line-or-region-local-mode
  :config
  (whole-line-or-region-global-mode 1))

(use-package window-purpose
  :load-path "site-lisp/purpose"
  :commands purpose-mode)

(use-package winner
  :unless noninteractive
  :defer 5
  :bind (("M-N" . winner-redo)
         ("M-P" . winner-undo))
  :config
  (winner-mode 1))

(use-package word-count
  :load-path "site-lisp/word-count-mode"
  :bind ("C-. W" . word-count-mode))

(use-package ws-butler
  :disabled t
  :load-path "site-lisp/ws-butler"
  :diminish
  :hook (prog-mode . ws-butler-mode))

(use-package xray
  :bind (("C-c x b" . xray-buffer)
         ("C-c x f" . xray-faces)
         ("C-c x F" . xray-features)
         ("C-c x R" . xray-frame)
         ("C-c x h" . xray-hooks)
         ("C-c x m" . xray-marker)
         ("C-c x o" . xray-overlay)
         ("C-c x p" . xray-position)
         ("C-c x S" . xray-screen)
         ("C-c x s" . xray-symbol)
         ("C-c x w" . xray-window)))

(use-package yaml-mode
  :load-path "site-lisp/yaml-mode"
  :mode "\\.ya?ml\\'")

(use-package yaoddmuse
  :bind (("C-c w f" . yaoddmuse-browse-page-default)
         ("C-c w e" . yaoddmuse-edit-default)
         ("C-c w p" . yaoddmuse-post-library-default)))

(use-package yari
  :load-path "site-lisp/yari-with-buttons"
  :commands yari)

(use-package yasnippet
  :load-path "site-lisp/yasnippet"
  :after prog-mode
  :defer 10
  :diminish yas-minor-mode
  :bind (("C-c y d" . yas-load-directory)
         ("C-c y i" . yas-insert-snippet)
         ("C-c y f" . yas-visit-snippet-file)
         ("C-c y n" . yas-new-snippet)
         ("C-c y t" . yas-tryout-snippet)
         ("C-c y l" . yas-describe-tables)
         ("C-c y g" . yas/global-mode)
         ("C-c y m" . yas/minor-mode)
         ("C-c y a" . yas-reload-all)
         ("C-c y x" . yas-expand))
  :bind (:map yas-keymap
              ("C-i" . yas-next-field-or-maybe-expand))
  :mode ("/\\.emacs\\.d/snippets/" . snippet-mode)
  :config
  (yas-load-directory (emacs-path "snippets"))
  (yas-global-mode 1))

(use-package z3-mode
  :load-path "site-lisp/z3-mode"
  :mode "\\.rs\\'")

(use-package zencoding-mode
  :load-path "site-lisp/zencoding-mode"
  :hook (nxml-mode html-mode)
  :bind (:map zencoding-mode-keymap
              ("C-c C-c" . zencoding-expand-line))
  :preface
  (defvar zencoding-mode-keymap (make-sparse-keymap)))

(use-package zoom
  :load-path "site-lisp/zoom"
  :bind ("C-x +" . zoom)
  :preface
  (defun size-callback ()
    (cond ((> (frame-pixel-width) 1280) '(90 . 0.75))
          (t '(0.5 . 0.5)))))

(use-package ztree-diff
  :load-path "site-lisp/ztree"
  :commands ztree-diff)

;;; Layout

(defconst display-name
  (let ((width (display-pixel-width)))
    (cond ((>= width 2560) 'retina-imac)
          ((= width 1920) 'macbook-pro-vga)
          ((= width 1680) 'macbook-pro)
          ((= width 1440) 'retina-macbook-pro))))

(defconst emacs-min-top 23)

(defconst emacs-min-left
  (cond (running-alternate-emacs 5)
        ;; ((eq display-name 'retina-imac) 975)
        ((eq display-name 'retina-imac) 746)
        ((eq display-name 'macbook-pro-vga) 837)
        (t 521)))

(defconst emacs-min-height
  (cond (running-alternate-emacs 57)
        ((eq display-name 'retina-imac) 57)
        ((eq display-name 'macbook-pro-vga) 54)
        ((eq display-name 'macbook-pro) 47)
        (t 44)))

(defconst emacs-min-width
  (cond (running-alternate-emacs 80)
        ;; ((eq display-name 'retina-imac) 100)
        ((eq display-name 'retina-imac) 162)
        (t 100)))

(defconst emacs-min-font
  (cond
   ((eq display-name 'retina-imac)
    (if running-alternate-emacs
        "-*-Myriad Pro-normal-normal-normal-*-20-*-*-*-p-0-iso10646-1"
      ;; "-*-Source Code Pro-normal-normal-normal-*-20-*-*-*-m-0-iso10646-1"
      "-*-Hack-normal-normal-normal-*-18-*-*-*-m-0-iso10646-1"
      ))
   ((eq display-name 'macbook-pro)
    (if running-alternate-emacs
        "-*-Myriad Pro-normal-normal-normal-*-20-*-*-*-p-0-iso10646-1"
      ;; "-*-Source Code Pro-normal-normal-normal-*-20-*-*-*-m-0-iso10646-1"
      "-*-Hack-normal-normal-normal-*-16-*-*-*-m-0-iso10646-1"
      ))
   ((eq display-name 'macbook-pro-vga)
    (if running-alternate-emacs
        "-*-Myriad Pro-normal-normal-normal-*-20-*-*-*-p-0-iso10646-1"
      ;; "-*-Source Code Pro-normal-normal-normal-*-20-*-*-*-m-0-iso10646-1"
      "-*-Hack-normal-normal-normal-*-16-*-*-*-m-0-iso10646-1"
      ))
   ((string= (system-name) "ubuntu")
    ;; "-*-Source Code Pro-normal-normal-normal-*-20-*-*-*-m-0-iso10646-1"
    "-*-Hack-normal-normal-normal-*-14-*-*-*-m-0-iso10646-1"
    )
   (t
    (if running-alternate-emacs
        "-*-Myriad Pro-normal-normal-normal-*-17-*-*-*-p-0-iso10646-1"
      ;; "-*-Source Code Pro-normal-normal-normal-*-15-*-*-*-m-0-iso10646-1"
      "-*-Hack-normal-normal-normal-*-14-*-*-*-m-0-iso10646-1"))))

(defun emacs-min ()
  (interactive)
  (set-frame-parameter (selected-frame) 'fullscreen nil)
  (set-frame-parameter (selected-frame) 'vertical-scroll-bars nil)
  (set-frame-parameter (selected-frame) 'horizontal-scroll-bars nil)
  (set-frame-font emacs-min-font)
  (set-frame-parameter (selected-frame) 'top emacs-min-top)
  (set-frame-parameter (selected-frame) 'left emacs-min-left)
  (set-frame-height (selected-frame) emacs-min-height)
  (set-frame-width (selected-frame) emacs-min-width))

(defun emacs-max ()
  (interactive)
  (set-frame-parameter (selected-frame) 'fullscreen 'fullboth)
  (set-frame-parameter (selected-frame) 'vertical-scroll-bars nil)
  (set-frame-parameter (selected-frame) 'horizontal-scroll-bars nil)
  (set-frame-font emacs-min-font))

(defun emacs-toggle-size ()
  (interactive)
  (if (> (cdr (assq 'width (frame-parameters))) 200)
      (emacs-min)
    (emacs-max)))

(add-hook 'after-init-hook #'emacs-min t)

;;; Finalization

(let ((elapsed (float-time (time-subtract (current-time)
                                          emacs-start-time))))
  (message "Loading %s...done (%.3fs)" load-file-name elapsed))

(add-hook 'after-init-hook
          `(lambda ()
             (let ((elapsed
                    (float-time
                     (time-subtract (current-time) emacs-start-time))))
               (message "Loading %s...done (%.3fs) [after-init]"
                        ,load-file-name elapsed))) t)

;;; init.el ends here
