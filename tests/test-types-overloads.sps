;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for overloaded functions
;;;Date: Sun May 29, 2016
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2016 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software: you can  redistribute it and/or modify it under the
;;;terms  of  the GNU  General  Public  License as  published  by  the Free  Software
;;;Foundation,  either version  3  of the  License,  or (at  your  option) any  later
;;;version.
;;;
;;;This program is  distributed in the hope  that it will be useful,  but WITHOUT ANY
;;;WARRANTY; without  even the implied warranty  of MERCHANTABILITY or FITNESS  FOR A
;;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;;
;;;You should have received a copy of  the GNU General Public License along with this
;;;program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!vicare
(program (test-types-overloads)
  (options typed-language)
  (import (vicare)
    (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare libraries: tests for overloaded functions\n")


(parametrise ((check-test-name	'base))

  (check
      (internal-body
	(define/overload (fun {O <fixnum>})
	  (list 'fixnum O))

	(define/overload (fun {O <string>})
	  (list 'string O))

	(define/overload (fun {A <vector>} {B <vector>})
	  (list 'vectors (vector-append A B)))

	(values (fun 123)
		(fun "ciao")
		(fun '#(1) '#(2))))
    => '(fixnum 123) '(string "ciao") '(vectors #(1 2)))

  ;;No arguments.
  ;;
  (check
      (internal-body
	(define/overload (fun)
	  1)

	(define/overload (fun {A <fixnum>})
	  A)

	(values (fun) (fun 2)))
    => 1 2)

  ;;Specialisations ranking.
  ;;
  (check
      (internal-body
	(define/overload (fun {O <number>})
	  `(number ,O))

	(define/overload (fun {O <real>})
	  `(real ,O))

	(define/overload (fun {O <fixnum>})
	  `(fixnum ,O))

	(values (fun (cast-signature (<number>) 123))
		(fun (cast-signature (<real>)   123))
		(fun (cast-signature (<fixnum>) 123))))
    => '(number 123) '(real 123) '(fixnum 123))

  ;;Specialisations ranking.
  ;;
  (check
      (internal-body
	(define/overload (fun {O <number>})
	  `(number ,O))

	(define/overload (fun {O <real>})
	  `(real ,O))

	(define/overload (fun {O <fixnum>})
	  `(fixnum ,O))

	(values (fun 1+2i)
		(fun 3.4)
		(fun 5)))
    => '(number 1+2i) '(real 3.4) '(fixnum 5))

  #t)


(parametrise ((check-test-name	'records))

;;; no parent

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method/overload (get-a O)
	    (alpha-a O))
	  (method/overload (get-b O)
	    (alpha-b O)))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (method-call get-a O)
		(method-call get-b O))
	(values 1 2))
    => 1 2)

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method/overload (get-a O)
	    (alpha-a O))
	  (method/overload (get-b O)
	    (alpha-b O))
	  (method/overload (set-a O v)
	    (alpha-a-set! O v))
	  (method/overload (set-b O v)
	    (alpha-b-set! O v)))

	(define {O alpha}
	  (make-alpha 1 2))

	(method-call set-a O 10)
	(method-call set-b O 20)
	(values (method-call get-a O)
		(method-call get-b O)))
    => 10 20)

;;; --------------------------------------------------------------------
;;; calling parent's method/overloads

  ;;Record-type with parent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields one two)
	  (method/overload (sum-them O)
	    (+ (duo-one O)
	       (duo-two O))))

	(define-record-type trio
	  (parent duo)
	  (fields three)
	  (method/overload (mul-them O)
	    (* (duo-one O)
	       (duo-two O)
	       (trio-three O))))

	(define {O trio}
	  (make-trio 3 5 7))

	(values (method-call sum-them O)
		(method-call mul-them O)))
    => (+ 3 5) (* 3 5 7))

  ;;Record-type with parent and grandparent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields one two)
	  (method/overload (sum-them O)
	    (+ (duo-one O)
	       (duo-two O))))

	(define-record-type trio
	  (parent duo)
	  (fields three)
	  (method/overload (mul-them O)
	    (* (duo-one O)
	       (duo-two O)
	       (trio-three O))))

	(define-record-type quater
	  (parent trio)
	  (fields four)
	  (method/overload (list-them O)
	    (list (duo-one O)
		  (duo-two O)
		  (trio-three O)
		  (quater-four O))))

	(define {O quater}
	  (make-quater 3 5 7 11))

	(values (method-call sum-them O)
		(method-call mul-them O)
		(method-call list-them O)))
    => (+ 3 5) (* 3 5 7) (list 3 5 7 11))

;;; --------------------------------------------------------------------
;;; dot notation

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method/overload (get-a O)
	    (alpha-a O))
	  (method/overload (get-b O)
	    (alpha-b O)))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (.get-a O)
		(.get-b O)))
    => 1 2)

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method/overload (get-a O)
	    (alpha-a O))
	  (method/overload (get-b O)
	    (alpha-b O))
	  (method/overload (set-a O v)
	    (alpha-a-set! O v))
	  (method/overload (set-b O v)
	    (alpha-b-set! O v)))

	(define {O alpha}
	  (make-alpha 1 2))

	(.set-a O 10)
	(.set-b O 20)
	(values (.get-a O)
		(.get-b O)))
    => 10 20)

;;; --------------------------------------------------------------------
;;; actual overloadgin with multiple implementations

  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (method/overload (doit {O alpha} {A <fixnum>})
	    (list (.a O) (.b O) 'fixnum A))
	  (method/overload (doit {O alpha} {A <symbol>})
	    (list (.a O) (.b O) 'symbol A))
	  (method/overload (doit {O alpha} {A <number>} {B <number>})
	    (list (.a O) (.b O) 'numbers A B)))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (.doit O 123)
		(.doit O 'ciao)
		(.doit O 3 4)))
    => '(1 2 fixnum 123) '(1 2 symbol ciao) '(1 2 numbers 3 4))

  (check
      (internal-body
	(define-record-type <duo>
	  (fields one two)
	  (method/overload (doit {O <duo>})
	    (+ (.one O) (.two O)))
	  (method/overload (doit {O <duo>} {C <number>})
	    (* C (+ (.one O) (.two O)))))

	(define O
	  (new <duo> 1 2))

	(values (.doit O)
		(.doit O 3)))
    => 3 9)

  #t)


(parametrise ((check-test-name	'late-binding-demo))

  (import (prefix (only (vicare system type-descriptors)
			closure-type-descr?
			closure-type-descr.signature
			case-lambda-descriptors.match-super-and-sub
			case-lambda-descriptors.match-formals-against-operands
			make-descriptors-signature
			type-descriptor-of)
		  td::))

  (define-struct overloaded-function-descriptor
    (table
		;An alist  having an  instance of <closure-type-descr>  as key  and a
		;procedure as value.
     ))

  (define* (overloaded-function-descriptor-register! {over.des		overloaded-function-descriptor?}
						     {closure.des	td::closure-type-descr?}
						     {implementation	procedure?})
    (set-overloaded-function-descriptor-table! over.des
					       (cons (cons closure.des implementation)
						     (overloaded-function-descriptor-table over.des))))

  (define* (overloaded-function-descriptor-select-matching-entry {over.des overloaded-function-descriptor?} operand*)
    (let ((rands.sig (td::make-descriptors-signature (map td::type-descriptor-of operand*))))
      (fold-left
	  (lambda (selected-entry entry)
	    ;;ENTRY is  a pair having  an instance of  <closure-type-descr> as
	    ;;car and a  procedure as cdr.  SELECTED-ENTRY is false  or a pair
	    ;;with the same format of ENTRY.
	    (let ((clambda.des (td::closure-type-descr.signature (car entry))))
	      (if (eq? 'exact-match (td::case-lambda-descriptors.match-formals-against-operands clambda.des rands.sig))
		  (if selected-entry
		      (if (eq? 'exact-match (td::case-lambda-descriptors.match-super-and-sub
					     (td::closure-type-descr.signature (car selected-entry))
					     clambda.des))
			  entry
			selected-entry)
		    entry)
		selected-entry)))
	#f (overloaded-function-descriptor-table over.des))))

  (define* (overloaded-function-late-binding {over.des overloaded-function-descriptor?} . operand*)
    (cond ((overloaded-function-descriptor-select-matching-entry over.des operand*)
	   => (lambda (entry)
		(apply (cdr entry) operand*)))
	  (else
	   (assertion-violation __who__
	     "no function matching the operands in overloaded function application"
	     over.des operand*))))

;;; --------------------------------------------------------------------

  (define (doit-string {O <string>})
    (list 'string O))

  (define (doit-fixnum {O <fixnum>})
    (list 'fixnum O))

  (define doit-string.des
    (type-descriptor (lambda (<string>) => (<list>))))

  (define doit-fixnum.des
    (type-descriptor (lambda (<fixnum>) => (<list>))))

  (define ofd
    (receive-and-return (ofd)
	(make-overloaded-function-descriptor (list (cons doit-string.des doit-string)))
      (overloaded-function-descriptor-register! ofd doit-fixnum.des doit-fixnum)))

;;; --------------------------------------------------------------------

  (check
      (overloaded-function-late-binding ofd "ciao")
    => '(string "ciao"))

  (check
      (overloaded-function-late-binding ofd 123)
    => '(fixnum 123))

  #| end of PARAMETRISE |# )


(parametrise ((check-test-name	'late-binding-raw))

  (import (only (vicare system type-descriptors)
		make-overloaded-function-descriptor
		overloaded-function-descriptor.register!
		overloaded-function-late-binding))

  (define (doit-string {O <string>})
    (list 'string O))

  (define (doit-fixnum {O <fixnum>})
    (list 'fixnum O))

  (define doit-string.des
    (type-descriptor (lambda (<string>) => (<list>))))

  (define doit-fixnum.des
    (type-descriptor (lambda (<fixnum>) => (<list>))))

  (define ofd
    (receive-and-return (ofd)
	(make-overloaded-function-descriptor (list (cons doit-string.des doit-string)))
      (overloaded-function-descriptor.register! ofd doit-fixnum.des doit-fixnum)))

;;; --------------------------------------------------------------------

  (check
      (overloaded-function-late-binding ofd "ciao")
    => '(string "ciao"))

  (check
      (overloaded-function-late-binding ofd 123)
    => '(fixnum 123))

  #| end of PARAMETRISE |# )


(parametrise ((check-test-name	'late-binding-syntax))

  (check
      (internal-body
	(define/overload (doit {O <string>})
	  (list 'string O))

	(define/overload (doit {O <fixnum>})
	  (list 'fixnum O))

	(values (doit (cast-signature (<top>) "ciao"))
		(doit (cast-signature (<top>) 123))))
    => '(string "ciao") '(fixnum 123))

  (check
      (internal-body
	(define/overload (doit {O <string>})
	  (list 'string O))

	(define/overload (doit {O <fixnum>})
	  (list 'fixnum O))

	(define (call-it {obj <top>})
	  (doit obj))

	(values (call-it "ciao")
		(call-it 123)))
    => '(string "ciao") '(fixnum 123))

;;; --------------------------------------------------------------------

  (check-for-true
   (internal-body
     (define/overload (doit {O <string>})
       (list 'string O))

     (define/overload (doit {O <fixnum>})
       (list 'fixnum O))

     (try
	 (doit 'hello)
       (catch E
	 ((&overloaded-function-late-binding-error)
	  (when #f
	    (debug-print (condition-message E)))
	  #t)
	 (else E)))))

  #| end of PARAMETRISE |# )


;;;; done

(check-report)

#| end of program |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; coding: utf-8
;; End: