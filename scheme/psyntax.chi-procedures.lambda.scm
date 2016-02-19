;;;Copyright (c) 2010-2016 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;Copyright (c) 2006, 2007 Abdulaziz Ghuloum and Kent Dybvig
;;;
;;;Permission is hereby  granted, free of charge,  to any person obtaining  a copy of
;;;this software and associated documentation files  (the "Software"), to deal in the
;;;Software  without restriction,  including without  limitation the  rights to  use,
;;;copy, modify,  merge, publish, distribute,  sublicense, and/or sell copies  of the
;;;Software,  and to  permit persons  to whom  the Software  is furnished  to do  so,
;;;subject to the following conditions:
;;;
;;;The above  copyright notice and  this permission notice  shall be included  in all
;;;copies or substantial portions of the Software.
;;;
;;;THE  SOFTWARE IS  PROVIDED  "AS IS",  WITHOUT  WARRANTY OF  ANY  KIND, EXPRESS  OR
;;;IMPLIED, INCLUDING BUT  NOT LIMITED TO THE WARRANTIES  OF MERCHANTABILITY, FITNESS
;;;FOR A  PARTICULAR PURPOSE AND NONINFRINGEMENT.   IN NO EVENT SHALL  THE AUTHORS OR
;;;COPYRIGHT HOLDERS BE LIABLE FOR ANY  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
;;;AN ACTION OF  CONTRACT, TORT OR OTHERWISE,  ARISING FROM, OUT OF  OR IN CONNECTION
;;;WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(module (chi-lambda/standard
	 chi-lambda/typed
	 chi-named-lambda/standard
	 chi-named-lambda/typed
	 ;;
	 chi-case-lambda/standard
	 chi-case-lambda/typed
	 chi-named-case-lambda/standard
	 chi-named-case-lambda/typed
	 ;;
	 chi-defun/standard
	 chi-defun/typed
	 chi-case-defun/standard
	 chi-case-defun/typed)


;;;; lambda clause attributes

(define (attributes.safe-formals? attributes.sexp)
  (or (memq 'safe         attributes.sexp)
      (memq 'safe-formals attributes.sexp)))

(define (attributes.safe-retvals? attributes.sexp)
  (or (memq 'safe         attributes.sexp)
      (memq 'safe-retvals attributes.sexp)))


;;;; helpers

(define-syntax (define-synner stx)
  ;;Expand to the definition of a synner function bound to "__synner__".  It is to be
  ;;used as follows:
  ;;
  ;;   (define (fun arg)
  ;;     (define-synner)
  ;;     (do-something __synner__))
  ;;
  (sys::syntax-case stx ()
    ((?kwd)
     (sys::with-syntax
	 ((SYNNER		(sys::datum->syntax (sys::syntax ?kwd) '__synner__))
	  (INPUT-FORM.STX	(sys::datum->syntax (sys::syntax ?kwd) 'input-form.stx)))
       (sys::syntax
	(begin
	  (define func-who __who__)
	  (case-define SYNNER
	    ((message)
	     (SYNNER message #f))
	    ((message subform)
	     (syntax-violation func-who message INPUT-FORM.STX subform)))))))
    ))

(define (build-formals-validation-form* input-form.stx lexenv.run lexenv.expand
					caller-who arg* tag* rest-arg rest-tag)
  ;;When expanding a typed LAMBDA form like:
  ;;
  ;;   (lambda/typed ({a <fixnum>} {b <string>} . {rest <fixnum*>})
  ;;     ?body)
  ;;
  ;;we want to transform it into an equivalent of:
  ;;
  ;;   (lambda/standard (a b)
  ;;     (unless (internal-run-time-arg? a <fixnum>)
  ;;       (procedure-signature-argument-violation __who__
  ;;         "invalid object type" 1 '(is-a? _ <fixnum>) a)
  ;;
  ;;     (unless (internal-run-time-arg? b <string>)
  ;;       (procedure-signature-argument-violation __who__
  ;;         "invalid object type" 2 '(is-a? _ <string>) b)
  ;;
  ;;     (fold-left
  ;;         (lambda/standard (idx obj)
  ;;           (unless (internal-run-time-is-a? obj <fixnum>)
  ;;             (procedure-signature-argument-violation __who__
  ;;               "invalid object type" idx '(is-a? _ <fixnum>) obj))
  ;;           (fxadd1 idx))
  ;;       3 rest)
  ;;
  ;;     ?body)
  ;;
  ;;This  function  builds  and  returns   a  list  of  syntax  objects  representing
  ;;expressions that validate  (at run-time) the arguments (excluding  the formals in
  ;;which the  tag is "<top>",  whose arguments are always  valid).  If there  are no
  ;;arguments: return null.
  ;;
  ;;Since we want run-time validation: using  IS-A?  will not do, because IS-A?  also
  ;;performs expand-time  type checking; this is  why INTERNAL-RUN-TIME-IS-A?  exists
  ;;and is used here.
  ;;
  ;;The argument  CALLER-WHO is a symbol  representing the name of  the function that
  ;;called this function.
  ;;
  ;;The arguments  ARG* and TAG* are  lists of identifiers: the  formers representing
  ;;the name  of the mandatory  formal arguments,  the latters representing  the type
  ;;identifiers of each value in mandatory formal arguments.
  ;;
  ;;The arguments REST-ARG and REST-TAG  must be identifiers: the former representing
  ;;the  name  of  the rest  or  args  argument,  the  latter representing  the  type
  ;;identifier of  each value in the  rest or args  argument.  When there is  no rest
  ;;argument: REST-ARG and REST-TAG must be #f.
  ;;
  (define-constant MESSAGE "invalid object type")
  (let recur ((arg* arg*)
	      (tag* tag*)
	      (idx  1))
    (cond ((pair? arg*)
	   (let ((following-validations (recur (cdr arg*) (cdr tag*) (fxadd1 idx))))
	     (let ((arg (car arg*))
		   (tag (car tag*)))
	       (cond ((top-type-id? tag)
		      ;;Insert no validation for an argument typed "<top>".
		      following-validations)
		     (else
		      (cons (bless
			     `(unless (internal-run-time-is-a? ,arg ,tag)
				(procedure-signature-argument-violation __who__
				  ,MESSAGE ,idx '(is-a? _ ,tag) ,arg)))
			    following-validations))))))

	  ((or (not             rest-tag)
	       (list-type-id?    rest-tag)
	       (top-type-id?     rest-tag))
	   ;;There is  no rest argument  or it is tagged  as "<top>" or  or "<list>";
	   ;;insert no validation.
	   '())

	  ((type-identifier-is-list-sub-type? rest-tag)
	   ;;Build a validation form for the objects in the rest argument.
	   (let ((ots (id->object-type-specification caller-who input-form.stx rest-tag lexenv.run)))
	     (if (list-type-spec? ots)
		 ;;The REST-TAG is  some sub-type of "<list>" defined  as instance of
		 ;;"<list-type-spec>".   We  generate  a validating  expression  that
		 ;;accepts both null and a list of objects of the specified type.
		 (let ((item-type-id	(list-type-spec.type-id ots))
		       (obj.sym	(gensym "obj"))
		       (idx.sym	(gensym "idx")))
		   (bless
		    `((fold-left (lambda (,idx.sym ,obj.sym)
				   (unless (internal-run-time-is-a? ,obj.sym ,item-type-id)
				     (procedure-signature-argument-violation __who__
				       ,MESSAGE ,idx.sym '(is-a? _ ,item-type-id) ,obj.sym))
				   (fxadd1 ,idx.sym))
			,idx ,rest-arg))))
	       ;;The REST-TAG is some sub-type  of "<list>" not defined as instance
	       ;;of "<list-type-spec>".  Just rely on the type's own predicate.
	       (bless
		`(unless (internal-run-time-is-a? ,rest-arg ,rest-tag)
		   (procedure-signature-argument-violation __who__
		     ,MESSAGE #f '(is-a? _ ,rest-tag) ,rest-arg))))))

	  (else
	   (syntax-violation caller-who
	     "invalid type for rest argument, it must be  \"<list>\" or its sub-type"
	     input-form.stx rest-tag)))))

(define* (insert-retvals-validation-form retvals-signature.tags body-form*.stx)
  ;;When expanding a typed LAMBDA form like:
  ;;
  ;;   (lambda ({_ <symbol>} a b)
  ;;     ?body ... ?last-body)
  ;;
  ;;we want to transform it into an equivalent of:
  ;;
  ;;   (lambda (a b)
  ;;     ?body ...
  ;;     (assert-signature-and-return (<symbol>) ?last-body))
  ;;
  ;;Add the return values  validation to the last form in the body;  return a list of
  ;;body forms.
  ;;
  (bless
   (if (syntax-object.type-signature.fully-untyped? retvals-signature.tags)
       ;;The number and type of return values is unknown.
       body-form*.stx
     (receive (head*.stx last.stx)
	 (proper-list->head-and-last body-form*.stx)
       `(,@head*.stx
	 (assert-signature-and-return ,retvals-signature.tags ,last.stx))))))


;;;; chi procedures: standard and typed single-clause function definition

(module (chi-defun/standard chi-defun/typed)

  (define (chi-defun/standard qdef lexenv.run lexenv.expand)
    ;;Expand a qualified RHS (QDEF) representing a DEFINE/STANDARD syntax use for the
    ;;case of function definition; the original input form is something like:
    ;;
    ;;   (define/standard (?lhs . ?formals) . ?body)
    ;;
    ;;Return a  PSI object holding a  lambda core language expression.   The returned
    ;;expression will be coupled (by the caller) with an already generated lex gensym
    ;;serving as lexical variable name; for this  reason we return a lambda core form
    ;;rather than a define core form.
    ;;
    ;;NOTE This  function assumes that:  the left-hand side (LHS)  variable syntactic
    ;;binding has already been added to LEXENV.
    ;;
    (%chi-defun #t qdef lexenv.run lexenv.expand))

  (define (chi-defun/typed qdef lexenv.run lexenv.expand)
    ;;Expand a  qualified RHS (QDEF) representing  a DEFINE/TYPED syntax use  for the
    ;;case of function definition; the original input form is something like:
    ;;
    ;;   (define/typed (?lhs . ?formals) . ?body)
    ;;   (define/typed ((brace ?lhs ?rv-type ... . ?rv-type-rest) . ?formals) . ?body)
    ;;
    ;;Return a  PSI object holding a  lambda core language expression.   The returned
    ;;expression will be coupled (by the caller) with an already generated lex gensym
    ;;serving as lexical variable name; for this  reason we return a lambda core form
    ;;rather than a define core form.
    ;;
    ;;NOTE This  function assumes that:  the left-hand side (LHS)  variable syntactic
    ;;binding has already been added to LEXENV.
    ;;
    (%chi-defun #f qdef lexenv.run lexenv.expand))

  (define (%chi-defun standard? qdef lexenv.run lexenv.expand)
    (define-constant input-form.stx (qdef.input-form qdef))
    (parametrise ((current-run-lexenv (lambda () lexenv.run)))
      (receive (standard-formals.lex body.psi)
	  (if standard?
	      (chi-lambda-clause/standard input-form.stx lexenv.run lexenv.expand
					  (qdef-defun.standard-formals qdef)
					  (car (clambda-signature.clause-signature* (qdef-defun.signature qdef)))
					  (qdef-defun.body* qdef))
	    (receive (lexenv.run lexenv.expand)
		;;We  establish   the  syntactic   binding  for   "__who__"  before
		;;processing the body.  So the formals may shadow this binding.
		(fluid-syntax-push-who-on-lexenvs input-form.stx lexenv.run lexenv.expand __who__ (qdef.lhs qdef))

	      (chi-lambda-clause/typed input-form.stx lexenv.run lexenv.expand
				       (qdef-defun.standard-formals qdef)
				       (car (clambda-signature.clause-signature* (qdef-defun.signature qdef)))
				       (qdef-defun.body* qdef))))
	(make-psi input-form.stx
		  (build-lambda (identifier->symbol (qdef.lhs qdef))
		      standard-formals.lex
		    (psi.core-expr body.psi))
		  (make-type-signature/single-value (qdef.type-id qdef))))))

  #| end of module |# )


;;;; chi procedures: standard and typed multi-clause function definition

(module (chi-case-defun/standard chi-case-defun/typed)

  (define (chi-case-defun/standard qdef lexenv.run lexenv.expand)
    ;;Expand a  qualified RHS (QDEF)  representing a CASE-DEFINE/STANDARD  syntax use
    ;;for the case of function definition; the original input form is something like:
    ;;
    ;;   (case-define/standard ?lhs (?formals0 . ?body0) (?formals . ?body) ...)
    ;;
    ;;Return a  PSI object holding a  lambda core language expression.   The returned
    ;;expression will be coupled (by the caller) with an already generated lex gensym
    ;;serving as lexical variable name; for this  reason we return a lambda core form
    ;;rather than a define core form.
    ;;
    ;;NOTE This  function assumes that:  the left-hand side (LHS)  variable syntactic
    ;;binding has already been added to LEXENV.
    ;;
    (%chi-case-defun #t qdef lexenv.run lexenv.expand))

  (define (chi-case-defun/typed qdef lexenv.run lexenv.expand)
    ;;Expand a qualified  RHS (QDEF) representing a CASE-DEFINE/TYPED  syntax use for
    ;;the case of function definition; the original input form is something like:
    ;;
    ;;   (case-define/typed ?lhs (?formals0 . ?body0) (?formals . ?body) ...)
    ;;
    ;;Return a  PSI object holding a  lambda core language expression.   The returned
    ;;expression will be coupled (by the caller) with an already generated lex gensym
    ;;serving as lexical variable name; for this  reason we return a lambda core form
    ;;rather than a define core form.
    ;;
    ;;NOTE This  function assumes that:  the left-hand side (LHS)  variable syntactic
    ;;binding has already been added to LEXENV.
    ;;
    (%chi-case-defun #f qdef lexenv.run lexenv.expand))

  (define (%chi-case-defun standard? qdef lexenv.run lexenv.expand)
    (define-constant input-form.stx		(qdef.input-form qdef))
    (define-constant standard-formals*.stx	(qdef-case-defun.standard-formals* qdef))
    (define-constant body**.stx			(qdef-case-defun.body** qdef))
    (define-constant clause-signature*		(clambda-signature.clause-signature* (qdef-case-defun.signature qdef)))
    (receive (lexenv.run lexenv.expand)
	;;We  establish the  syntactic binding  for "__who__"  before processing  the
	;;body.  So the formals may shadow this binding.
	(fluid-syntax-push-who-on-lexenvs input-form.stx lexenv.run lexenv.expand __who__ (qdef.lhs qdef))
      (parametrise ((current-run-lexenv (lambda () lexenv.run)))
	(receive (formals*.lex body*.psi)
	    (if standard?
		(chi-case-lambda-clause*/standard input-form.stx lexenv.run lexenv.expand
						  standard-formals*.stx clause-signature* body**.stx)
	      (chi-case-lambda-clause*/typed input-form.stx lexenv.run lexenv.expand
					     standard-formals*.stx clause-signature* body**.stx))
	  (make-psi input-form.stx
		    (build-case-lambda (syntax-annotation input-form.stx)
			formals*.lex
		      (map psi.core-expr body*.psi))
		    (make-type-signature/single-value (qdef.type-id qdef)))))))

  #| end of module |# )


;;;; standard LAMBDA expansion and variants

(define* (chi-lambda/standard input-form.stx lexenv.run lexenv.expand
			      input-formals.stx body*.stx)
  ;;Expand the contents of a LAMBDA/STANDARD syntax use and return a PSI object.
  ;;
  ;;The argument INPUT-FORM.STX  is a syntax object representing  the original LAMBDA
  ;;expression.  The argument  INPUT-FORMALS.STX is a syntax  object representing the
  ;;formals of the LAMBDA syntax.  The argument BODY*.STX is a list of syntax objects
  ;;representing the body expressions in the LAMBDA syntax.
  ;;
  (receive (standard-formals.stx clause-signature)
      (syntax-object.parse-standard-clambda-clause-formals input-formals.stx input-form.stx)
    ;;CLAUSE-SIGNATURE is an instance of "<clambda-clause-signature>".
    (receive (standard-formals.lex body.psi)
	(chi-lambda-clause/standard input-form.stx lexenv.run lexenv.expand
				    standard-formals.stx clause-signature body*.stx)
      ;;STANDARD-FORMALS.LEX is a  proper or improper list of  lex gensyms representing
      ;;the lambda clause formals.
      (make-psi input-form.stx
		(build-lambda (syntax-annotation input-form.stx)
		    standard-formals.lex
		  (psi.core-expr body.psi))
		(make-type-signature/single-value
		 (fabricate-closure-type-identifier '_ (make-clambda-signature (list clause-signature))))))))

(define* (chi-named-lambda/standard input-form.stx lexenv.run lexenv.expand
				    who.id standard-formals.stx body*.stx)
  ;;Expand  the contents  of  a NAMED-LAMBDA/STANDARD  syntax use  and  return a  PSI
  ;;object.
  ;;
  (receive (lexenv.run lexenv.expand)
      ;;We  establish  the syntactic  binding  for  "__who__" before  processing  the
      ;;formals and the body.  So the formals may shadow this binding.
      (fluid-syntax-push-who-on-lexenvs input-form.stx lexenv.run lexenv.expand __who__ who.id)
    (chi-lambda/standard input-form.stx lexenv.run lexenv.expand
			 standard-formals.stx body*.stx)))


;;;; standard CASE-LAMBDA expansion and variants

(module (chi-case-lambda/standard
	 chi-named-case-lambda/standard)

  (define* (chi-case-lambda/standard input-form.stx lexenv.run lexenv.expand
				     input-formals*.stx body**.stx)
    ;;Expand  the contents  of a  CASE-LAMBDA/STANDARD syntax  use and  return a  psi
    ;;object.
    ;;
    ;;The  argument  INPUT-FORM.STX is  a  syntax  object representing  the  original
    ;;CASE-LAMBDA/STANDARD expression.  The argument  INPUT-FORMALS*.STX is a list of
    ;;syntax objects  whose items are  the formals  of the CASE-LAMBDA  clauses.  The
    ;;argument BODY**.STX is a  list of syntax objects whose items  are the bodies of
    ;;the CASE-LAMBDA clauses.
    ;;
    ;;Example, for the input form:
    ;;
    ;;   (case-lambda/standard
    ;;     ((a b c) body1)
    ;;     ((d e f) body2))
    ;;
    ;;this function is invoked as:
    ;;
    ;;   (chi-case-lambda/standard
    ;;      #'(case-lambda/standard
    ;;          ((a b c) body1)
    ;;          ((d e f) body2))
    ;;      lexenv.run lexenv.expand
    ;;      (list #'(a b c) #'(d e f))
    ;;      (list #'(body1) #'(body2)))
    ;;
    (%chi-clambda input-form.stx lexenv.run lexenv.expand '_ input-formals*.stx body**.stx))

  (define* (chi-named-case-lambda/standard input-form.stx lexenv.run lexenv.expand
					   who.id input-formals*.stx body**.stx)
    ;;Expand the contents of a NAMED-CASE-LAMBDA/STANDARD syntax use and return a psi
    ;;object.
    ;;
    (receive (lexenv.run lexenv.expand)
	;;We  establish the  syntactic binding  for "__who__"  before processing  the
	;;formals and the body.  So the formals may shadow this binding.
	(fluid-syntax-push-who-on-lexenvs input-form.stx lexenv.run lexenv.expand __who__ who.id)
      (%chi-clambda input-form.stx lexenv.run lexenv.expand
		    (identifier->symbol who.id) input-formals*.stx body**.stx)))

  (define (%chi-clambda input-form.stx lexenv.run lexenv.expand who.sym input-formals*.stx body**.stx)
    (receive (standard-formals*.stx clause-signature*)
	(syntax-object.parse-standard-clambda-multi-clauses-formals input-formals*.stx input-form.stx)
      (receive (formals*.lex body*.psi)
	  (chi-case-lambda-clause*/standard input-form.stx lexenv.run lexenv.expand
					    standard-formals*.stx clause-signature* body**.stx)
	(make-psi input-form.stx
		  (build-case-lambda (syntax-annotation input-form.stx)
		      formals*.lex
		    (map psi.core-expr body*.psi))
		  (make-type-signature/single-value
		   (fabricate-closure-type-identifier who.sym (make-clambda-signature clause-signature*)))))))

  #| end of module |# )


;;;; typed LAMBDA expansion

(module (chi-lambda/typed
	 chi-named-lambda/typed)

  (define* (chi-lambda/typed input-form.stx lexenv.run lexenv.expand
			     input-formals.stx body*.stx)
    ;;Expand the contents of a LAMBDA/TYPED syntax use and return a psi object.
    ;;
    ;;The argument INPUT-FORM.STX is a syntax object representing the original LAMBDA
    ;;expression.  The argument INPUT-FORMALS.STX is a syntax object representing the
    ;;formals  of the  LAMBDA syntax.   The argument  BODY*.STX is  a list  of syntax
    ;;objects representing the body expressions.
    ;;
    (%chi-lambda input-form.stx lexenv.run lexenv.expand (underscore-id) '_ input-formals.stx body*.stx))

  (define* (chi-named-lambda/typed input-form.stx lexenv.run lexenv.expand
				   who.id input-formals.stx body*.stx)
    ;;Expand the contents of a NAMED-LAMBDA/TYPED syntax use and return a psi object.
    ;;
    (%chi-lambda input-form.stx lexenv.run lexenv.expand who.id (identifier->symbol who.id) input-formals.stx body*.stx))

  (define (%chi-lambda input-form.stx lexenv.run lexenv.expand who.id who.sym input-formals.stx body*.stx)
    (receive (standard-formals.stx clause-signature)
	;;STANDARD-FORMALS.STX is  a syntax object representing  the formal arguments
	;;of the lambda clause as required  by R6RS.  CLAUSE-SIGNATURE is an instance
	;;of  "<clambda-clause-signature>"  representing  the types  of  formals  and
	;;retvals.
	(syntax-object.parse-typed-clambda-clause-formals input-formals.stx input-form.stx)
      (receive (lexenv.run lexenv.expand)
	  ;;We establish  the syntactic binding  for "__who__" before  processing the
	  ;;formals and the body.  So the formals may shadow this binding.
	  (fluid-syntax-push-who-on-lexenvs input-form.stx lexenv.run lexenv.expand __who__ who.id)
	(receive (standard-formals.lex body.psi)
	    (chi-lambda-clause/typed input-form.stx lexenv.run lexenv.expand
				     standard-formals.stx clause-signature body*.stx)
	  (make-psi input-form.stx
		    (build-lambda (syntax-annotation input-form.stx)
			standard-formals.lex
		      (psi.core-expr body.psi))
		    (make-type-signature/single-value
		     (fabricate-closure-type-identifier who.sym (make-clambda-signature (list clause-signature)))))))))

  #| end of module |# )


;;;; typed CASE-LAMBDA and variants

(module (chi-case-lambda/typed
	 chi-named-case-lambda/typed)

  (define* (chi-case-lambda/typed input-form.stx lexenv.run lexenv.expand
				  input-formals*.stx body**.stx)
    ;;Expand the clauses of a CASE-LAMBDA/TYPED syntax use and return a psi object.
    ;;
    ;;The  argument  INPUT-FORM.STX is  a  syntax  object representing  the  original
    ;;CASE-LAMBDA/TYPED  expression.  The  argument INPUT-FORMALS*.STX  is a  list of
    ;;syntax objects  whose items are  the formals of the  CASE-LAMBDA/TYPED clauses.
    ;;The argument BODY**.STX is a list of  syntax objects whose items are the bodies
    ;;of the CASE-LAMBDA/TYPED clauses.
    ;;
    ;;Example, for the input form:
    ;;
    ;;   (case-lambda/typed
    ;;     ((a b c) body1)
    ;;     ((d e f) body2))
    ;;
    ;;this function is invoked as:
    ;;
    ;;   (chi-case-lambda/typed
    ;;     #'(case-lambda/typed
    ;;         ((a b c) body1)
    ;;         ((d e f) body2))
    ;;     lexenv.run lexenv.expand
    ;;     (list #'(a b c) #'(d e f))
    ;;     (list #'(body1) #'(body2)))
    ;;
    (%chi-clambda input-form.stx lexenv.run lexenv.expand
		  (underscore-id) '_
		  input-formals*.stx body**.stx))

  (define* (chi-named-case-lambda/typed input-form.stx lexenv.run lexenv.expand
					who.id input-formals*.stx body**.stx)
    ;;Expand the  clauses of a  NAMED-CASE-LAMBDA/TYPED syntax  use and return  a psi
    ;;object.
    ;;
    (%chi-clambda input-form.stx lexenv.run lexenv.expand
		  who.id (identifier->symbol who.id)
		  input-formals*.stx body**.stx))

  (define (%chi-clambda input-form.stx lexenv.run lexenv.expand who.id who.sym input-formals*.stx body**.stx)
    (receive (standard-formals*.stx clause-signature*)
	(syntax-object.parse-typed-clambda-multi-clauses-formals input-formals*.stx input-form.stx)
      (receive (lexenv.run lexenv.expand)
	  ;;We establish  the syntactic binding  for "__who__" before  processing the
	  ;;formals and the body.  So the formals may shadow this binding.
	  (fluid-syntax-push-who-on-lexenvs input-form.stx lexenv.run lexenv.expand __who__ who.id)
	(receive (formals*.lex body*.psi)
	    (chi-case-lambda-clause*/typed input-form.stx lexenv.run lexenv.expand
					   standard-formals*.stx clause-signature* body**.stx)
	  (make-psi input-form.stx
		    (build-case-lambda (syntax-annotation input-form.stx)
			formals*.lex
		      (map psi.core-expr body*.psi))
		    ;;If  we fabricate  a type  identifier  for this  closure: it  is
		    ;;possible to leak  the type identifier out of  the local lexical
		    ;;context where it is defined.
		    (make-type-signature/single-value
		     (fabricate-closure-type-identifier who.sym (make-clambda-signature clause-signature*))))))))

  #| end of module |# )


;;;; case-lambda clauses expander: standard and typed CASE-LAMBDA

(define (chi-case-lambda-clause*/standard input-form.stx lexenv.run lexenv.expand
					  standard-formals*.stx clause-signature* body**.stx)
  ;;Recursive function.  Expand a clause from a CASE-LAMBDA/STANDARD syntax use.
  ;;
  ;;The argument INPUT-FORM.STX is the syntax object holding the original input form.
  ;;The argument  STANDARD-FORMALS*.STX is a list  of syntax objects, each  holding a
  ;;proper or improper list of formal arguments.  The argument CLAUSE-SIGNATURE* is a
  ;;list of "<clambda-clause-signature>" objects.  The  argument BODY**.STX is a list
  ;;of syntax objects each holding the body forms.
  ;;
  ;;Return the following values:
  ;;
  ;;1.  A  list of subslists,  each sublist  being a proper  or improper list  of lex
  ;;gensyms representing the formals.
  ;;
  ;;2.  A list of PSI objects each containing a core language expression representing
  ;;the body of a clause.
  ;;
  (if (pair? standard-formals*.stx)
      (receive (standard-formals.lex body.psi)
	  (chi-lambda-clause/standard input-form.stx lexenv.run lexenv.expand
				      (car standard-formals*.stx) (car clause-signature*) (car body**.stx))
	(receive (standard-formals*.lex body*.psi)
	    (chi-case-lambda-clause*/standard input-form.stx lexenv.run lexenv.expand
					      (cdr standard-formals*.stx) (cdr clause-signature*) (cdr body**.stx))
	  (values (cons standard-formals.lex standard-formals*.lex)
		  (cons body.psi body*.psi))))
    (values '() '())))

(define* (chi-case-lambda-clause*/typed input-form.stx lexenv.run lexenv.expand
					standard-formals*.stx clause-signature* body-form**.stx)
  ;;Recursive function.  Expand all the clauses of a CASE-LAMBDA/TYPED syntax.
  ;;
  ;;The argument INPUT-FORM.STX is the syntax object holding the original input form.
  ;;The argument  STANDARD-FORMALS*.STX is a list  of syntax objects, each  holding a
  ;;proper or improper list of formal arguments.  The argument CLAUSE-SIGNATURE* is a
  ;;list of "<clambda-clause-signature>" objects.  The  argument BODY**.STX is a list
  ;;of syntax objects each holding the body forms.
  ;;
  ;;Return the following values:
  ;;
  ;;1.  A  list of subslists,  each sublist  being a proper  or improper list  of lex
  ;;gensyms representing the formals.
  ;;
  ;;2.  A list of PSI objects each containing a core language expression representing
  ;;the body of a clause.
  ;;
  (if (pair? standard-formals*.stx)
      (receive (standard-formals.lex body.psi)
	  (chi-lambda-clause/typed input-form.stx lexenv.run lexenv.expand
				   (car standard-formals*.stx) (car clause-signature*) (car body-form**.stx))
	(receive (standard-formals*.lex body*.psi)
	    (chi-case-lambda-clause*/typed input-form.stx lexenv.run lexenv.expand
					   (cdr standard-formals*.stx) (cdr clause-signature*) (cdr body-form**.stx))
	  (values (cons standard-formals.lex standard-formals*.lex)
		  (cons body.psi body*.psi))))
    (values '() '())))


(module LAMBDA-CLAUSE-EXPANSION-HELPERS
  (%expand-guts-with-proper-list-formals
   %expand-guts-with-improper-list-formals)

  (define (%expand-guts-with-proper-list-formals input-form.stx lexenv.run lexenv.expand
						 standard-formals.stx clause-signature body*.stx)
    ;;Expand  the guts  of a  lambda  clause for  the  case of  formals without  rest
    ;;argument.  Here  we know that  STANDARD-FORMALS.STX and the  corresponding type
    ;;signature are proper lists with equal length.
    (receive (rib lexenv.run standard-formals*.lex)
	(%process-typed-syntactic-bindings-lhs* standard-formals.stx (clambda-clause-signature.argvals.tags clause-signature) lexenv.run)
      (%expand-body input-form.stx lexenv.run lexenv.expand standard-formals*.lex body*.stx rib)))

  (define (%expand-guts-with-improper-list-formals input-form.stx lexenv.run lexenv.expand
						   standard-formals.stx clause-signature body*.stx)
    ;;Expand the guts of a lambda clause  for the case of formals with rest argument.
    ;;Here we know that STANDARD-FORMALS.STX and the corresponding type signature are
    ;;improper lists with equal length.
    (let*-values
	(((arg*.id  rest.id)
	  (improper-list->list-and-rest standard-formals.stx))
	 ((arg*.tag rest.tag)
	  (improper-list->list-and-rest (clambda-clause-signature.argvals.tags clause-signature)))
	 ((rib lexenv.run standard-formals.lex)
	  (receive (rib lexenv.run all*.lex)
	      (%process-typed-syntactic-bindings-lhs* (cons rest.id arg*.id) (cons rest.tag arg*.tag) lexenv.run)
	    ;;Yes, this call to APPEND builds an improper list.
	    (values rib lexenv.run (append (cdr all*.lex) (car all*.lex))))))
      (%expand-body input-form.stx lexenv.run lexenv.expand standard-formals.lex body*.stx rib)))

  (define (%expand-body input-form.stx lexenv.run lexenv.expand standard-formals.lex body*.stx rib)
    (let* ((body*.stx (push-lexical-contour rib body*.stx))
	   (body.psi  (chi-internal-body input-form.stx lexenv.run lexenv.expand body*.stx)))
      (values standard-formals.lex body.psi)))

  #| end of module: LAMBDA-CLAUSE-EXPANSION-HELPERS |# )


;;;; lambda clause expander: standard lambda clause

(define (chi-lambda-clause/standard input-form.stx lexenv.run lexenv.expand
				    standard-formals.stx clause-signature body*.stx)
  ;;Expand the clause of a LAMBDA/STANDARD  or DEFINE/STANDARD syntax use or a single
  ;;clause of a CASE-LAMBDA/STANDARD or CASE-DEFINE/STANDARD syntax use.
  ;;
  ;;The argument INPUT-FORM.STX is the syntax object holding the original input form.
  ;;The argument STANDARD-FORMALS.STX is a syntax object holding a proper or improper
  ;;list of standard formal arguments.   The argument CLAUSE-SIGNATURE is an instance
  ;;of  "<clambda-clause-signature>".  The  argument BODY*.STX  is a  list of  syntax
  ;;objects holding the body forms.
  ;;
  ;;Return the following values:
  ;;
  ;;1. STANDARD-FORMALS.LEX,  a proper or  improper list of lex  gensyms representing
  ;;the lambda clause formals.
  ;;
  ;;2. BODY.PSI, a PSI object representing the expanded body.
  ;;
  ;;This  function creates  a  new rib  object to  represent  the formals'  syntactic
  ;;bindings, then pushes the rib on the body forms before expanding them.
  ;;
  (import LAMBDA-CLAUSE-EXPANSION-HELPERS)
  (cond
   ((list? standard-formals.stx)
    (%expand-guts-with-proper-list-formals   input-form.stx lexenv.run lexenv.expand
					     standard-formals.stx clause-signature body*.stx))
   (else
    (%expand-guts-with-improper-list-formals input-form.stx lexenv.run lexenv.expand
					     standard-formals.stx clause-signature body*.stx))))


;;;; lambda clause expander: typed lambda clause

(define* (chi-lambda-clause/typed input-form.stx lexenv.run lexenv.expand
				  standard-formals.stx clause-signature body*.stx)
  ;;Expand the clause of a LAMBDA/TYPED or DEFINE/TYPED syntax use or a single clause
  ;;of a CASE-LAMBDA/TYPED or CASE-DEFINE/TYPED syntax use.
  ;;
  ;;The argument INPUT-FORM.STX is the syntax object holding the original input form.
  ;;The argument STANDARD-FORMALS.STX is a syntax object holding a proper or improper
  ;;list of standard formal arguments.   The argument CLAUSE-SIGNATURE is an instance
  ;;of  "<clambda-clause-signature>".  The  argument BODY*.STX  is a  list of  syntax
  ;;objects holding the body forms.
  ;;
  ;;Return the following values:
  ;;
  ;;1. STANDARD-FORMALS.LEX,  a proper or  improper list of lex  gensyms representing
  ;;the lambda clause formals.
  ;;
  ;;2. BODY.PSI, a PSI object representing the expanded body.
  ;;
  ;;NOTE The expander  for the internal body will create  yet another lexical contour
  ;;to hold the body's internal definitions.
  ;;
  (import LAMBDA-CLAUSE-EXPANSION-HELPERS)
  (define argvals-signature.tags
    (clambda-clause-signature.argvals.tags clause-signature))
  (define retvals-signature.tags
    (clambda-clause-signature.retvals.tags clause-signature))
  (cond
   ((list? standard-formals.stx)
    ;;Without  rest  argument.   Here  we know  that  both  STANDARD-FORMALS.STX  and
    ;;ARGVALS-SIGNATURE.TAGS are proper lists with equal length.
    (let ((formals-validation-form*.stx (build-formals-validation-form* input-form.stx lexenv.run lexenv.expand
									__who__ standard-formals.stx argvals-signature.tags #f #f)))
      (let* ((body*.stx (insert-retvals-validation-form retvals-signature.tags body*.stx))
	     (body*.stx (if (pair? formals-validation-form*.stx)
			    (append formals-validation-form*.stx
				    ;;We  introduce an  internal  body  to allow  the
				    ;;correct  expansion of  internal definitions  in
				    ;;BODY*.STX.
				    `((,(core-prim-id 'internal-body) . ,body*.stx)))
			  body*.stx)))
	(%expand-guts-with-proper-list-formals input-form.stx lexenv.run lexenv.expand
					       standard-formals.stx clause-signature body*.stx))))

   (else
    ;;With  rest  argument.    Here  we  know  that   both  STANDARD-FORMALS.STX  and
    ;;ARGVALS-SIGNATURE.TAGS are improper lists with equal length.
    (let ((formals-validation-form*.stx (let-values
					    (((arg*.id  rest.id)  (improper-list->list-and-rest standard-formals.stx))
					     ((arg*.tag rest.tag) (improper-list->list-and-rest argvals-signature.tags)))
					  (build-formals-validation-form* input-form.stx lexenv.run lexenv.expand
									  __who__ arg*.id arg*.tag rest.id rest.tag))))
      (let* ((body*.stx (insert-retvals-validation-form retvals-signature.tags body*.stx))
	     (body*.stx (if (pair? formals-validation-form*.stx)
			    (append formals-validation-form*.stx
				    ;;We  introduce an  internal  body  to allow  the
				    ;;correct  expansion of  internal definitions  in
				    ;;BODY*.STX.
				    `((,(core-prim-id 'internal-body) . ,body*.stx)))
			  body*.stx)))
	(%expand-guts-with-improper-list-formals input-form.stx lexenv.run lexenv.expand
						 standard-formals.stx clause-signature body*.stx))))))


;;;; done

#| end of module |# )

;;; end of file
;;Local Variables:
;;mode: vicare
;;End:
