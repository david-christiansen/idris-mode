;;; idris-metavariable-list.el --- List Idris metavariables in a buffer -*- lexical-binding: t -*-

;; Copyright (C) 2014 David Raymond Christiansen

;; Author: David Raymond Christiansen <david@davidchristiansen.dk>

;; License:
;; Inspiration is taken from SLIME/DIME (http://common-lisp.net/project/slime/) (https://github.com/dylan-lang/dylan-mode)
;; Therefore license is GPL

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

(require 'idris-core)
(require 'idris-warnings-tree)
(require 'cl-lib)

(defvar idris-metavariable-list-buffer-name (idris-buffer-name :metavariables)
  "The name of the buffer containing Idris metavariables")

(defun idris-metavariable-list-quit ()
  "Quit the Idris metavariable list"
  (interactive)
  (idris-kill-buffer idris-metavariable-list-buffer-name))

(defvar idris-metavariable-list-mode-map
  (let ((map (make-keymap)))
    (suppress-keymap map)
    (define-key map (kbd "q") 'idris-metavariable-list-quit)
    (define-key map (kbd "C-c C-t") 'idris-type-at-point)
    (define-key map (kbd "C-c C-d") 'idris-docs-at-point)
    (define-key map (kbd "RET") 'idris-compiler-notes-default-action-or-show-details)
    (define-key map (kbd "<mouse-2>") 'idris-compiler-notes-default-action-or-show-details/mouse)
    map))

(easy-menu-define idris-metavariable-list-mode-menu idris-metavariable-list-mode-map
  "Menu for the Idris metavariable list buffer"
  `("Idris Metavars"
    ["Close metavariable list buffer" idris-metavariable-list-quit t]))

(define-derived-mode idris-metavariable-list-mode fundamental-mode "Idris Metavars"
  "Major mode used for transient Idris metavariable list buffers
   \\{idris-metavariable-list-mode-map}
Invoces `idris-metavariable-list-mode-hook'.")

(defun idris-metavariable-list-buffer ()
  "Return the Idris metavariable buffer, creating one if there is not one"
  (get-buffer-create idris-metavariable-list-buffer-name))

(defun idris-metavariable-list-buffer-visible-p ()
  (if (get-buffer-window idris-metavariable-list-buffer-name 'visible) t nil))

(defun idris-metavariable-list-show (metavar-info)
  (if (null metavar-info)
      (progn (message "No metavariables found!")
             (idris-metavariable-list-quit))
    (with-current-buffer (idris-metavariable-list-buffer)
      (setq buffer-read-only nil)
      (erase-buffer)
      (idris-metavariable-list-mode)
      (insert "Metavariables:\n")
      (dolist (tree (mapcar #'idris-tree-for-metavariable metavar-info))
        (idris-tree-insert tree "")
        (insert "\n\n"))
      (insert "\n")
      (message "Press q to close")
      (setq buffer-read-only t)
      (goto-char (point-min))))
    (display-buffer (idris-metavariable-list-buffer)))

(defun idris-tree-for-metavariable (metavar)
  (cl-destructuring-bind (name premises conclusion) metavar
    (make-idris-tree :item name
                     :highlighting `((0 ,(length name) ((:decor :metavar))))
                     :collapsed-p (not idris-metavariable-list-show-expanded) ; from customize
                     :kids (list (idris-tree-for-metavariable-details name premises conclusion)))))

(defun idris-tree-for-metavariable-details (name premises conclusion)
  (let* ((name-width (1+ (apply #'max 0 (length name)
                                (mapcar #'(lambda (h) (length (car h)))
                                        premises))))
         (divider-marker nil)
         (contents (with-temp-buffer
                     (dolist (h premises)
                       (cl-destructuring-bind (name type formatting) h
                         (cl-dotimes (_ (- name-width (length name))) (insert " "))
                         (idris-propertize-spans (idris-repl-semantic-text-props
                                                  `((0 ,(length name) ((:decor :bound)))))
                           (insert name))
                         (insert " : ")
                         (idris-propertize-spans (idris-repl-semantic-text-props formatting)
                           (insert type))
                         (insert "\n")))
                     (setq divider-marker (point-marker))
                     (cl-destructuring-bind (type formatting) conclusion
                       (when premises
                         (insert " ")
                         (idris-propertize-spans (idris-repl-semantic-text-props
                                                  `((0 ,(length name) ((:decor :metavar)))))
                           (insert name))
                         (insert " : "))
                       (idris-propertize-spans (idris-repl-semantic-text-props formatting)
                         (insert type)))
                     (when premises
                       (let ((width (apply #'max 0
                                           (mapcar #'length
                                                   (split-string (buffer-string) "\n")))))
                         (goto-char (marker-position divider-marker))
                         (dotimes (_ (1+ width)) (insert "-"))
                         (insert "\n")))
                     (buffer-string))))
    (make-idris-tree :item contents
                     :active-p nil
                     :highlighting '())))


(provide 'idris-metavariable-list)
