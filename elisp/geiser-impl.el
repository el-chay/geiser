;; geiser-impl.el -- generic support for scheme implementations

;; Copyright (C) 2009 Jose Antonio Ortega Ruiz

;; Author: Jose Antonio Ortega Ruiz <jao@gnu.org>
;; Start date: Sat Mar 07, 2009 23:32

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Comentary:

;; Functions to handle setup of Scheme implementations supported by
;; Geiser.

;;; Code:

(require 'geiser-eval)
(require 'geiser-base)


;;; Customization:

(defgroup geiser-impl nil
  "Generic support for multiple Scheme implementations."
  :group 'geiser)

(defcustom geiser-impl-default-implementation 'guile
  "Symbol naming the default Scheme implementation."
  :type 'symbol
  :group 'geiser-impl)


;;; Registering implementations:

(defvar geiser-impl--impls nil)

(defun geiser-impl--register (impl)
  (add-to-list 'geiser-impl--impls impl))

(defun geiser-impl--unregister (impl)
  (setq geiser-impl--impls (remove impl geiser-impl--impls)))

(defvar geiser-impl--default-implementation
  geiser-impl-default-implementation)

(defun geiser-impl--default-implementation (&optional new)
  (when new (setq geiser-impl--default-implementation new))
  (or geiser-impl--default-implementation
      geiser-impl-default-implementation
      (car geiser-impl--impls)))


;;; Installing Scheme implementations:

(make-local-variable
 (defvar geiser-impl--implementation nil))

(defsubst geiser-impl--impl-feature (impl)
  (intern (format "geiser-%s" impl)))

(defun geiser-impl--set-buffer-implementation (&optional impl)
  (let ((impl (or impl
                  (geiser-impl--guess)
                  (intern (read-string "Scheme implementation: ")))))
    (require (geiser-impl--impl-feature impl))
    (setq geiser-impl--implementation impl)
    (geiser-impl--install-eval impl)
    (geiser-impl--register impl)))


(defsubst geiser-impl--sym (imp name)
  (intern (format "geiser-%s-%s" imp name)))

(defsubst geiser-impl--boundp (imp name)
  (boundp (geiser-impl--sym imp name)))

(defsubst geiser-impl--fboundp (imp name)
  (fboundp (geiser-impl--sym imp name)))

(defun geiser-impl--value (imp name &optional fun)
  (let ((sym (geiser-impl--sym imp name)))
    (unless (or (and (not fun) (boundp sym))
                (and fun (fboundp sym)))
      (error "Unbound %s '%s' in Geiser Scheme implementation %s"
             (if fun "function" "variable") sym imp))
    (if fun (symbol-function sym) (symbol-value sym))))

(defsubst geiser-impl--call-if-bound (imp name &rest args)
  (when (geiser-impl--fboundp imp name)
    (apply (geiser-impl--value imp name t) args)))

(defsubst geiser-impl--module-function (impl)
  (geiser-impl--sym impl "get-module"))

(defsubst geiser-impl--geiser-procedure-function (impl)
  (geiser-impl--sym imp "geiser-procedure"))

(defun geiser-impl--install-eval (impl)
  (setq geiser-eval--get-module-function (geiser-impl--module-function impl))
  (setq geiser-eval--geiser-procedure-function
        (geiser-impl--geiser-procedure-function impl)))


;;; Evaluating Elisp in a given implementation context:

(defun with--geiser-implementation (imp thunk)
  (let ((geiser-impl--implementation imp)
        (geiser-eval--get-module-function (geiser-impl--module-function imp))
        (geiser-eval--geiser-procedure-function
         (geiser-impl--geiser-procedure-function imp)))
    (funcall thunk)))

(put 'with--geiser-implementation 'lisp-indent-function 1)


;;; Default evaluation environment:

(defun geiser-impl-module (&optional module)
  (geiser-impl--call-if-bound (geiser-impl--default-implementation)
                              "get-module"
                              module))
(set-default 'geiser-eval--get-module-function 'geiser-impl-module)

(defun geiser-impl-geiser-procedure (proc)
  (geiser-impl--call-if-bound (geiser-impl--default-implementation)
                              "geiser-procedure"
                              proc))
(set-default 'geiser-eval--geiser-procedure-function 'geiser-impl-geiser-procedure)


;;; Access to implementation specific execution parameters:

(defsubst geiser-impl--binary (impl)
  (or (geiser-impl--call-if-bound impl "binary")
      (geiser-impl--value impl "binary")))

(defsubst geiser-impl--parameters (impl)
  (or (geiser-impl--call-if-bound impl "parameters")
      (ignore-errors (geiser-impl--value impl "parameters"))))

(defsubst geiser-impl--prompt-regexp (impl)
  (or (geiser-impl--call-if-bound impl "prompt-regexp")
      (geiser-impl--value impl "prompt-regexp")))


;;; Access to implementation guessing function:

(defun geiser-impl--guess ()
  (catch 'impl
    (dolist (impl geiser-impl--impls)
      (when (geiser-impl--call-if-bound impl "guess")
        (throw 'impl impl)))
    (geiser-impl--default-implementation)))


;;; Unload support

(defun geiser-impl-unload-function ()
  (dolist (imp (mapcar 'geiser-impl--impl-feature geiser-impl--impls))
    (when (featurep imp) (unload-feature imp)))
  t)

(defun geiser-impl--reload-implementations (impls)
  (dolist (impl impls)
    (load-library (format "geiser-%s" impl))))


(provide 'geiser-impl)
;;; geiser-impl.el ends here