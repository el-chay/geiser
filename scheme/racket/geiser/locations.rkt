;;; locations.rkt -- locating symbols

;; Copyright (C) 2009, 2010 Jose Antonio Ortega Ruiz

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the Modified BSD License. You should
;; have received a copy of the license along with this program. If
;; not, see <http://www.xfree86.org/3.3.6/COPYRIGHT2.html#5>.

;; Start date: Sun Apr 26, 2009 19:43

#lang racket

(provide symbol-location
         symbol-location*
         module-location
         symbol-module-name
         symbol-module-path-name)

(require geiser/utils geiser/modules)

(define (symbol-location* sym)
  (let* ([id (namespace-symbol->identifier sym)]
         [binding (and id (identifier-binding id))])
    (if (list? binding)
        (cons
         (cadr binding)
         (resolved-module-path-name
          (module-path-index-resolve (car binding))))
        (cons sym #f))))

(define (make-location name path line)
  (list (cons 'name name)
        (cons 'file (if (path? path) (path->string path) '()))
        (cons 'line (or line '()))))

(define (symbol-location sym)
  (let* ([loc (symbol-location* sym)]
         [name (car loc)]
         [path (cdr loc)])
    (if path
        (make-location name path #f)
        (module-location sym))))

(define symbol-module-path-name (compose cdr symbol-location*))

(define symbol-module-name
  (compose module-path-name->name symbol-module-path-name))

(define (module-location sym)
  (make-location sym (module-spec->path-name sym) 1))


;;; locations.rkt ends here