;;;Ikarus Scheme -- A compiler for R6RS Scheme.
;;;Copyright (C) 2006,2007,2008  Abdulaziz Ghuloum
;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under  the terms of  the GNU General  Public License version  3 as
;;;published by the Free Software Foundation.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should have received a copy of the GNU General Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.


(module (introduce-tags)
  ;;This compiler pass  analyses the type of values returned  by expressions with the
  ;;purpose of tranforming FUNCALL recordised forms:
  ;;
  ;;   (funcall ?rator (?rand ...))
  ;;
  ;;into:
  ;;
  ;;   (funcall (known ?rator ?rator-type) ((known ?rand ?rand-type) ...))
  ;;
  ;;where: ?RATOR-TYPE  is the type  specification of  the value returned  by ?RATOR;
  ;;each  ?RAND-TYPE  is  the  type  specification  of  the  value  returned  by  the
  ;;corresponding  ?RAND.  The  type  specifications are  records  wrapping an  exact
  ;;integer which encodes in its bits the type informations.
  ;;
  ;;The  structs of  type  KNOWN  are annotation  "tags"  consumed  by the  functions
  ;;generating  the implementation  of the  core primitive  operations; for  example,
  ;;given the recordised code:
  ;;
  ;;   (funcall (primref vector-length) (?rand))
  ;;
  ;;which makes use  of the primitive operation VECTOR-LENGTH:
  ;;
  ;;*  If no  type tag  is  assigned to  ?RAND: the  implementation of  VECTOR-LENGTH
  ;;   integrated at  the call  site must  include a  validation of  ?RAND as  vector
  ;;  object.
  ;;
  ;;* If the tag "T:vector" is introduced for the operand:
  ;;
  ;;     (funcall (primref vector-length) ((known ?rand (T:vector))))
  ;;
  ;;  the  implementation of  VECTOR-LENGTH integrated  at the  call site  does *not*
  ;;  include a validation of ?RAND as vector object.
  ;;
  ;;Accept as input a nested hierarchy of the following structs:
  ;;
  ;;   constant		prelex		primref
  ;;   bind		fix		conditional
  ;;   seq		clambda
  ;;   forcall		funcall
  ;;
  ;;NOTE Every PRELEX struct in the  input expression must represent a proper lexical
  ;;binding defined by a BIND or FIX struct.
  ;;
  (import SCHEME-OBJECTS-ONTOLOGY)

  (define-fluid-override __who__
    (identifier-syntax 'introduce-tags))

  (define (introduce-tags x)
    (receive (x env t)
	(V x EMPTY-ENV)
      x))


(module (V)

  (define (V x env)
    (struct-case x
      ((constant k)
       (values x env (%determine-constant-type k)))

      ((prelex)
       ;;We search  the PRELEX in  the environment collected  so far to  retrieve its
       ;;type tag  (previously determined when  processing the RHS expression  of the
       ;;binding struct that defined the PRELEX's binding).
       (values x env (%determine-prelex-type x env)))

      ((primref op)
       ;;This PRIMREF is standalone, it is not the operator of a FUNCALL; so it is an
       ;;error if it references a core primitive operation that is not also a lexical
       ;;core primitive function.
       (values x env T:procedure))

      ((seq e0 e1)
       (receive (e0^ env^ t)
	   (V e0 env)
	 (if (eq? (T:object? t) 'no)
	     ;;Evaluating E0 will  result in a raise exception, so  there is no point
	     ;;in including E1.
	     (if (option.strict-r6rs)
		 (values e0 env t)
	       (compiler-internal-error __who__
		 "invalid tag annotation from expression analysis"
		 (unparse-recordized-code e0) t))
	   (receive (e1^ env^^ t)
	       (V e1 env^)
	     (values (make-seq e0^ e1^) env^^ t)))))

      ((conditional x.test x.conseq x.altern)
       (receive (x.test env t)
	   (V x.test env)
	 (cond ((eq? (T:object? t) 'no)
		(values x.test env t))
	       ((eq? (T:false? t) 'yes)
		;;We know the test is false, so do the transformation:
		;;
		;;   (conditional ?test ?conseq ?altern)
		;;   ==> (seq ?test ?conseq)
		;;
		;;we conserve ?TEST for its side effects.
		(receive (x.altern env t)
		    (V x.altern env)
		  (values (make-seq x.test x.altern) env t)))
	       ((eq? (T:false? t) 'no)
		;;We know the test is true, so do the transformation:
		;;
		;;   (conditional ?test ?conseq ?altern)
		;;   ==> (seq ?test ?altern)
		;;
		;;we conserve ?TEST for its side effects.
		(receive (x.conseq env t)
		    (V x.conseq env)
		  (values (make-seq x.test x.conseq) env t)))
	       (else
		(let-values
		    (((x.conseq env1 t1) (V x.conseq env))
		     ((x.altern env2 t2) (V x.altern env)))
		  (values (make-conditional x.test x.conseq x.altern)
			  (or-envs env1 env2)
			  (T:or t1 t2)))))))

      ((bind lhs* rhs* body)
       (let-values (((rhs* env t*) (V* rhs* env)))
	 (for-each number! lhs*)
	 (let ((env (extend-env* lhs* t* env)))
	   (let-values (((body env t) (V body env)))
	     (values (make-bind lhs* rhs* body) env t)))))

      ((fix lhs* rhs* body)
       (for-each number! lhs*)
       (let-values (((rhs* env t*) (V* rhs* env)))
	 (let ((env (extend-env* lhs* t* env)))
	   (let-values (((body env t) (V body env)))
	     (values (make-fix lhs* rhs* body) env t)))))

      ((clambda label cls* cp free name)
       (values (make-clambda label
			     (map (lambda (x)
				    (struct-case x
				      ((clambda-case info body)
				       (for-each number! (case-info-args info))
				       (let-values (((body env t) (V body env)))
					 ;;dropped env and t
					 (make-clambda-case info body)))))
			       cls*)
			     cp free name)
	       env
	       T:procedure))

      ((funcall rator rand*)
       (let-values (((rator rator-env rator-val) (V  rator env))
		    ((rand* rand*-env rand*-val) (V* rand* env)))
	 (%apply-funcall rator     rand*
			 rator-val rand*-val
			 rator-env rand*-env)))

      ((forcall rator rand*)
       (let-values (((rand* rand*-env rand*-val) (V* rand* env)))
	 (values (make-forcall rator rand*) rand*-env T:object)))

      (else
       (error __who__ "invalid expression" (unparse-recordized-code x)))))

;;; --------------------------------------------------------------------

  (define (V* x* env)
    (if (null? x*)
	(values '() env '())
      (let-values (((x  env1 t)  (V  ($car x*) env))
		   ((x* env2 t*) (V* ($cdr x*) env)))
	(values (cons x x*)
		(and-envs env1 env2)
		(cons t t*)))))

  (define number!
    (let ((i 0))
      (lambda (x)
	(set-prelex-operand! x i)
	(set! i (+ i 1)))))

  (define (%determine-prelex-type x env)
    (cond ((eq? env 'bottom)
	   #f)
	  ((assq (prelex-operand x) env)
	   => cdr)
	  (else
	   T:object)))

  (define (%apply-funcall rator rand* rator-val rand*-val rator-env rand*-env)
    (let ((env   (and-envs rator-env rand*-env))
	  (rand* (map %annotate rand* rand*-val)))
      (struct-case rator
	((primref op)
	 (apply-primcall op rand* env))
	(else
	 (values (make-funcall (%annotate rator rator-val) rand*)
		 env
		 T:object)))))

  (define (%annotate x t)
    (if (T=? t T:object)
  	x
      (make-known x t)))

  #| end of module: V |# )


(module (%determine-constant-type)

  (define (%determine-constant-type x)
    (cond ((number?     x)   (%determine-numeric-constant-type x))
	  ((boolean?    x)   (if x T:true T:false))
	  ((null?       x)   T:null)
	  ((char?       x)   T:char)
	  ((string?     x)   T:string)
	  ((vector?     x)   T:vector)
	  ((pair?       x)   T:pair)
	  ((bytevector? x)   T:bytevector)
	  ((eq? x (void))    T:void)
	  (else              T:object)))

  (define (%determine-numeric-constant-type x)
    (cond ((fixnum? x)
	   (%sign x T:fixnum))
	  ((flonum? x)
	   (%sign x T:flonum))
	  ((or (bignum? x)
	       (ratnum? x))
	   (%sign x (T:and T:exact T:other-number)))
	  (else
	   T:number)))

  (define (%sign x t)
    (T:and t (cond ((< x 0) T:negative)
		   ((> x 0) T:positive)
		   ((= x 0) T:zero)
		   (else    t))))

  #| end of module: %DETERMINE-CONSTANT-TYPE |# )


(module (apply-primcall)

  (define (apply-primcall op rand* env)
    (define (return t)
      (values (make-funcall (mk-primref op) rand*) env t))
    (define-syntax %inject
      (syntax-rules ()
	((_ . ?args)
	 (inject op rand* env . ?args))))
    (define-syntax %inject*
      (syntax-rules ()
	((_ . ?args)
	 (inject* op rand* env . ?args))))
    (case op
      ((cons)
       (return T:pair))

      (($car cdr
	    caar cadr cdar cddr
	    caaar caadr cadar caddr cdaar cdadr cddar cdddr
	    caaaar caaadr caadar caaddr cadaar cadadr caddar cadddr
	    cdaaar cdaadr cdadar cdaddr cddaar cddadr cdddar cddddr)
       (%inject T:object T:pair))

      ((set-car! set-cdr!)
       (%inject T:void T:pair T:object))

      ((vector make-vector list->vector)
       (return T:vector))

      ((string make-string list->string)
       (return T:string))

      ((string-length)
       (%inject T:fixnum T:string))

      ((vector-length)
       (%inject T:fixnum T:vector))

      ((string-ref)
       (%inject T:char T:string T:fixnum))

      ((string-set!)
       (%inject T:void T:string T:fixnum T:char))

      ((vector-ref)
       (%inject T:object T:vector T:fixnum))

      ((vector-set!)
       (%inject T:void T:vector T:fixnum T:object))

      ((length)
       (%inject T:fixnum (T:or T:null T:pair)))

      ((bytevector-length)
       (%inject T:fixnum T:bytevector))

      ((integer->char)
       (%inject T:char T:fixnum))

      ((char->integer)
       (%inject T:fixnum T:char))

      ((bytevector-u8-ref bytevector-s8-ref bytevector-u16-native-ref bytevector-s16-native-ref)
       (%inject T:fixnum T:bytevector T:fixnum))

      ((bytevector-u16-ref bytevector-s16-ref)
       (%inject T:fixnum T:bytevector T:fixnum T:symbol))

      ((bytevector-u8-set! bytevector-s8-set! bytevector-u16-native-set! bytevector-s16-native-set!)
       (%inject T:void T:bytevector T:fixnum T:fixnum))

      ((bytevector-u16-set! bytevector-s16-set!)
       (%inject T:void T:bytevector T:fixnum T:fixnum T:symbol))

      ((fx+         fx-         fx*         fxadd1      fxsub1
		    fxquotient  fxremainder fxmodulo    fxsll       fxsra
		    fxand       fxdiv       fxdiv0      fxif        fxior
		    fxlength    fxmax       fxmin       fxmod       fxmod0
		    fxnot       fxxor       fxlogand    fxlogor     fxlognot
		    fxlogxor)
       (%inject* T:fixnum T:fixnum))

      ((fx= fx< fx<= fx> fx>= fx=? fx<? fx<=? fx>? fx>=?
	    fxeven? fxodd? fxnegative? fxpositive? fxzero?
	    fxbit-set?)
       (%inject* T:boolean T:fixnum))

      ((fl=? fl<? fl<=? fl>? fl>=?
	     fleven? flodd? flzero? flpositive? flnegative?
	     flfinite? flinfinite? flinteger? flnan?)
       (%inject* T:boolean T:flonum))

      ((char=? char<? char<=? char>? char>=?
	       char-ci=? char-ci<? char-ci<=? char-ci>? char-ci>=?)
       (%inject* T:boolean T:char))

      ((string=? string<? string<=? string>? string>=?
		 string-ci=? string-ci<? string-ci<=? string-ci>?
		 string-ci>=?)
       (%inject* T:boolean T:string))

      ((make-parameter
	   record-constructor record-accessor record-constructor record-predicate
	   condition-accessor condition-predicate
	   enum-set-constructor enum-set-indexer
	   make-guardian)
       (return T:procedure))

      ((fixnum-width greatest-fixnum least-fixnum)
       (return T:fixnum))

      (else
       (return T:object)))) ;;end of APPLY-PRIMCALL

;;; --------------------------------------------------------------------

  (module (inject)

    (define (inject op rand* env ret-t . rand-t*)
      (values (make-funcall (mk-primref op) rand*)
	      (if (= (length rand-t*)
		     (length rand*))
		  (%extend* rand* rand-t* env)
		;;Incorrect number of args.
		env)
	      ret-t))

    (define (%extend* x* t* env)
      (if (null? x*)
	  env
	(%extend ($car x*) ($car t*)
		 (%extend* ($cdr x*) ($cdr t*) env))))

    (define (%extend x t env)
      (struct-case x
	((known expr t0)
	 (%extend expr (T:and t t0) env))
	((prelex)
	 (extend-env x t env))
	(else
	 env)))

    #| end of module: inject |# )

;;; --------------------------------------------------------------------

  (module (inject*)

    (define (inject* op rand* env ret-t arg-t)
      (values (make-funcall (mk-primref op) rand*)
	      (%extend* rand* env arg-t)
	      ret-t))

    (define (%extend* x* env arg-t)
      (if (null? x*)
	  env
	(%extend ($car x*) arg-t
		 (%extend* ($cdr x*) env arg-t))))

    (define (%extend x t env)
      (struct-case x
	((known expr t0)
	 (%extend expr (T:and t t0) env))
	((prelex)
	 (extend-env x t env))
	(else
	 env)))

    #| end of module: inject* |# )

  #| end of module: apply-primcall |# )


;;;; env functions

(define-inline-constant EMPTY-ENV
  '())

(define (extend-env* x* v* env)
  (if (pair? x*)
      (extend-env* ($cdr x*) ($cdr v*)
		   (extend-env ($car x*) ($car v*) env))
    env))

(define (extend-env x t env)
  (if (T=? t T:object)
      env
    (let ((x (prelex-operand x)))
      (let recur ((env env))
	(if (or (null? env)
		(< x (caar env)))
	    (cons (cons x t) env)
	  (cons ($car env) (recur ($cdr env))))))))

;;; --------------------------------------------------------------------

(module (or-envs)

  (define-syntax-rule (or-envs env1 env2)
    (%merge-envs env1 env2))

  (define (%merge-envs env1 env2)
    (cond ((eq? env1 env2)
	   env1)
	  ((pair? env1)
	   (if (pair? env2)
	       (%merge-envs2 ($car env1) ($cdr env1)
			     ($car env2) ($cdr env2))
	     EMPTY-ENV))
	  (else
	   EMPTY-ENV)))

  (define (%merge-envs2 a1 env1 a2 env2)
    (let ((x1 ($car a1))
	  (x2 ($car a2)))
      (cond ((eq? x1 x2)
	     (cons-env x1 (T:or ($cdr a1) ($cdr a2))
		       (%merge-envs env1 env2)))
	    ((< x2 x1)
	     (%merge-envs1 a1 env1 env2))
	    (else
	     #;(assert (>= x2 x1))
	     (%merge-envs1 a2 env2 env1)))))

  (define (%merge-envs1 a1 env1 env2)
    (if (pair? env2)
	(%merge-envs2 a1 env1 ($car env2) ($cdr env2))
      EMPTY-ENV))

  (define (cons-env x v env)
    (if (T=? v T:object)
  	env
      (cons (cons x v) env)))

  #| end of module: or-envs |# )

;;; --------------------------------------------------------------------

(module (and-envs)

  (define-syntax-rule (and-envs env1 env2)
    (%merge-envs env1 env2))

  (define (%merge-envs env1 env2)
    (cond ((eq? env1 env2)
	   env1)
	  ((pair? env1)
	   (if (pair? env2)
	       (%merge-envs2 ($car env1) ($cdr env1)
			     ($car env2) ($cdr env2))
	     env1))
	  (else
	   env2)))

  (define (%merge-envs2 a1 env1 a2 env2)
    (let ((x1 ($car a1))
	  (x2 ($car a2)))
      (cond ((eq? x1 x2)
	     (cons-env x1 (T:and ($cdr a1) ($cdr a2))
		       (%merge-envs env1 env2)))
	    ((< x2 x1)
	     (cons a2 (%merge-envs1 a1 env1 env2)))
	    (else
	     (cons a1 (%merge-envs1 a2 env2 env1))))))

  (define (%merge-envs1 a1 env1 env2)
    (if (pair? env2)
	(%merge-envs2 a1 env1 ($car env2) ($cdr env2))
      env1))

  (define (cons-env x v env)
    (if (T=? v T:object)
  	env
      (cons (cons x v) env)))

  #| end of module: and-envs |# )


;;;; miscellaneous stuff

;;Commented out by Abdulaziz Ghuloum.
;;
;; (define primitive-return-types
;;   '((=                     boolean)
;;     (<                     boolean)
;;     (<=                    boolean)
;;     (>                     boolean)
;;     (>=                    boolean)
;;     (even?                 boolean)
;;     (odd?                  boolean)
;;     (rational?             boolean)
;;     (rational-valued?      boolean)
;;     (real?                 boolean)
;;     (real-valued?          boolean)
;;     (bignum?               boolean)
;;     (ratnum?               boolean)
;;     (flonum?               boolean)
;;     (fixnum?               boolean)
;;     (integer?              boolean)
;;     (exact?                boolean)
;;     (finite?               boolean)
;;     (inexact?              boolean)
;;     (infinite?             boolean)
;;     (positive?             boolean)
;;     (negative?             boolean)
;;     (nan?                  boolean)
;;     (number?               boolean)
;;     (compnum?              boolean)
;;     (cflonum?              boolean)
;;     (complex?              boolean)
;;     (list?                 boolean)
;;     (eq?                   boolean)
;;     (eqv?                  boolean)
;;     (equal?                boolean)
;;     (gensym?               boolean)
;;     (symbol-bound?         boolean)
;;     (code?                 boolean)
;;     (immediate?            boolean)
;;     (pair?                 boolean)
;;     (procedure?            boolean)
;;     (symbol?               boolean)
;;     (symbol=?              boolean)
;;     (boolean?              boolean)
;;     (boolean=?             boolean)
;;     (vector?               boolean)
;;     (bitwise-bit-set?      boolean)
;;     (bytevector?           boolean)
;;     (bytevector=?          boolean)
;;     (enum-set=?            boolean)
;;     (binary-port?          boolean)
;;     (textual-port?         boolean)
;;     (input-port?           boolean)
;;     (output-port?          boolean)
;;     (port?                 boolean)
;;     (port-eof?             boolean)
;;     (port-closed?          boolean)
;;     (eof-object?           boolean)
;;     (hashtable?            boolean)
;;     (hashtable-mutable?    boolean)
;;     (file-exists?          boolean)
;;     (file-readable?        boolean)
;;     (file-writable?        boolean)
;;     (file-executable?      boolean)
;;     (file-symbolic-link?   boolean)
;;     (record?               boolean)
;;     (record-field-mutable? boolean)
;;     (record-type-generative? boolean)
;;     (record-type-sealed?   boolean)
;;     (record-type-descriptor boolean)
;;     (free-identifier=?     boolean)
;;     (bound-identifier=?    boolean)
;;     (identifier?           boolean)
;;     (char-lower-case?      boolean)
;;     (char-upper-case?      boolean)
;;     (char-title-case?      boolean)
;;     (char-whitespace?      boolean)
;;     (char-numeric?         boolean)
;;     (char-alphabetic?      boolean)
;;     ))


;;;; done

#| end of module: introduce-tags |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; End:
