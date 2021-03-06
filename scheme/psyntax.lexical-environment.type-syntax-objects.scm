;;; -*- coding: utf-8-unix -*-
;;;
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


(module PSYNTAX-TYPE-SYNTAX-OBJECTS
  (syntax-object.typed-argument?			syntax-object.parse-typed-argument
   syntax-object.parse-standard-formals			syntax-object.parse-typed-formals
   syntax-object.parse-standard-list-of-bindings	syntax-object.parse-standard-list-of-bindings/let-star
   syntax-object.parse-typed-list-of-bindings		syntax-object.parse-typed-list-of-bindings/let-star

   syntax-object.parse-standard-clambda-clause-formals
   syntax-object.parse-standard-clambda-multi-clauses-formals

   syntax-object.parse-typed-clambda-clause-formals
   syntax-object.parse-typed-clambda-multi-clauses-formals

   syntax-object.standard-clambda-clause-formals?
   syntax-object.typed-clambda-clause-formals?

   typed-formals-syntax->args-list

   #| end of exports |# )


;;;; tagged binding parsing: standalone identifiers

(case-define syntax-object.typed-argument?
  ;;Return true if STX is a syntax object representing a typed or untyped identifier;
  ;;otherwise return false.
  ;;
  ((stx)
   (syntax-object.typed-argument? stx (current-inferior-lexenv)))
  ((stx lexenv)
   (guard (E (else #f))
     (receive (id type)
	 (syntax-object.parse-typed-argument stx lexenv)
       #t))))

(case-define* syntax-object.parse-typed-argument
  ;;If  STX  is a  typed  or  untyped identifier,  return  2  values: the  identifier
  ;;representing  the syntactic  binding name  and the  "<object-type-spec>" instance
  ;;representing the type; otherwise raise an exception.
  ;;
  ;;When no type annotation  is present in STX: the type  defaults to UNTYPED.OTS, or
  ;;"<top>" when  UNTYPED.OTS is  not used.   We use  "<untyped>" only  if explicitly
  ;;requested by the caller.
  ;;
  ((stx)
   (syntax-object.parse-typed-argument stx (current-inferior-lexenv) (<top>-ots)))
  ((stx lexenv)
   (syntax-object.parse-typed-argument stx lexenv                    (<top>-ots)))
  ((stx lexenv untyped.ots)
   (syntax-match stx (brace)
     ((brace ?id ?type)
      (values ?id (type-annotation->object-type-spec ?type lexenv)))
     (?id
      (identifier? ?id)
      (values ?id (<untyped>-ots))))))


;;;; standard binding parsing: proper lists of bindings left-hand sides

(define* (syntax-object.parse-standard-list-of-bindings lhs*)
  ;;Parser function  for lists of standard  syntactic bindings.  It is  used to parse
  ;;bindings from  LET, DO  and similar  syntaxes.  For  example, when  expanding the
  ;;syntax:
  ;;
  ;;   (let ((a 1)
  ;;         (b "b")
  ;;         (c #t))
  ;;     . ?body)
  ;;
  ;;the argument LHS* is:
  ;;
  ;;   (#'a #'b #'c)
  ;;
  ;;and the return value is:
  ;;
  ;;   (#'a #'b #'c)
  ;;
  ;;Assume LHS*  is a syntax  object representing a  proper list of  standard binding
  ;;identifiers;  parse the  list as  list  of identifiers  representing the  binding
  ;;identifiers.  The  identifiers must be  distinct.  The returned syntax  object is
  ;;fully unwrapped.
  ;;
  (receive-and-return (unwrapped-lhs*)
      (syntax-object.parse-standard-list-of-bindings/let-star lhs*)
    (cond ((duplicate-bound-formals? unwrapped-lhs*)
	   => (lambda (duplicate-id)
		(syntax-violation __who__
		  "duplicate identifiers among syntactic binding names"
		  duplicate-id))))))

(define* (syntax-object.parse-standard-list-of-bindings/let-star lhs*)
  ;;Parser function  for lists of standard  syntactic bindings.  It is  used to parse
  ;;bindings  from LET*,  DO* and  similar syntaxes;  remember that  LET* allows  for
  ;;duplicate identifiers.  For example, when expanding the syntax:
  ;;
  ;;   (let* ((a 1)
  ;;          (b "b")
  ;;          (c #t))
  ;;     . ?body)
  ;;
  ;;the argument LHS* is:
  ;;
  ;;   (#'a #'b #'c)
  ;;
  ;;and the return value is:
  ;;
  ;;   (#'a #'b #'c)
  ;;
  ;;Assume LHS*  is a syntax  object representing a  proper list of  standard binding
  ;;identifiers;  parse the  list as  list  of identifiers  representing the  binding
  ;;identifiers.  The  identifiers must be  distinct.  The returned syntax  object is
  ;;fully unwrapped.
  ;;
  (syntax-match lhs* ()
    ((?car . ?cdr)
     (if (identifier? ?car)
	 (cons ?car (syntax-object.parse-standard-list-of-bindings/let-star ?cdr))
       (syntax-violation __who__
	 "expected identifier as syntactic binding name" ?car)))
    (()
     '())
    (?thing
     (syntax-violation __who__
       "expected identifier as syntactic binding name" ?thing))))


;;;; tagged binding parsing: proper lists of bindings left-hand sides

(case-define* syntax-object.parse-typed-list-of-bindings
  ((lhs*)
   ;;By default we use "<top>" for the untyped syntactic binding.  We use "<untyped>"
   ;;only if explicitly requested by the caller.
   (syntax-object.parse-typed-list-of-bindings lhs* (<top>-ots)))
  ((lhs* untyped.ots)
   ;;Parser function  for lists  of typed  syntactic bindings.  It  is used  to parse
   ;;bindings from  LET, DO and  similar syntaxes.   For example, when  expanding the
   ;;syntax:
   ;;
   ;;   (let (({a <fixnum>} 1)
   ;;         ({b <string>} "b")
   ;;         (c            #t))
   ;;     . ?body)
   ;;
   ;;the argument LHS* is:
   ;;
   ;;   (#'(brace a <fixnum>) #'(brace b <string>) #'c)
   ;;
   ;;and the return values are:
   ;;
   ;;   (#'a #'b #'c) (#'<fixnum> #'<string> #'<untyped>)
   ;;
   ;;Assume LHS*  is a  syntax object  representing a proper  list of  possibly typed
   ;;binding identifiers.  Parse the list and return the following values:
   ;;
   ;;1. A list of syntactic identifiers representing the syntactic binding names.
   ;;
   ;;2. A list  of instances of type "<object-type-spec>"  representing the syntactic
   ;;   bindings' types.  UNTYPED.OTS is used when the binding is untyped.
   ;;
   (receive-and-return (lhs*.id lhs*.ots)
       (syntax-object.parse-typed-list-of-bindings/let-star lhs* untyped.ots)
     (cond ((duplicate-bound-formals? lhs*.id)
	    => (lambda (duplicate-id)
		 (syntax-violation __who__
		   "duplicate identifiers among syntactic binding names"
		   duplicate-id)))))))

(case-define* syntax-object.parse-typed-list-of-bindings/let-star
  ((lhs*)
   ;;By default we use "<top>" for the untyped syntactic binding.  We use "<untyped>"
   ;;only if explicitly requested by the caller.
   (syntax-object.parse-typed-list-of-bindings/let-star lhs* (<top>-ots)))
  ((lhs* untyped.ots)
   ;;Parser function  for lists  of typed  syntactic bindings.  It  is used  to parse
   ;;bindings from LET* and similar syntaxes; remember that LET* allows for duplicate
   ;;identifiers.  For example, when expanding the syntax:
   ;;
   ;;   (let* (({a <fixnum>} 1)
   ;;          ({b <string>} "b")
   ;;          (c            #t))
   ;;     . ?body)
   ;;
   ;;the argument LHS* is:
   ;;
   ;;   (#'(brace a <fixnum>) #'(brace b <string>) #'c)
   ;;
   ;;and the return values are:
   ;;
   ;;   (#'a #'b #'c) (#'<fixnum> #'<string> #'<untyped>)
   ;;
   ;;Assume LHS*  is a  syntax object  representing a proper  list of  possibly typed
   ;;binding identifiers.  Parse the list and return the following values:
   ;;
   ;;1. A list of syntactic identifiers representing the syntactic binding names.
   ;;
   ;;2. A list  of instances of type "<object-type-spec>"  representing the syntactic
   ;;   bindings' types.  UNTYPED.OTS is used when the binding is untyped.
   ;;
   (define lexenv
     (current-inferior-lexenv))
   (let recur ((stx lhs*))
     (with-who syntax-object.parse-typed-list-of-bindings/let-star
       (syntax-match stx (brace)
	 (()
	  (values '() '()))
	 (((brace ?id ?type) . ?other-lhs*)
	  (receive (lhs*.id lhs*.ots)
	      (recur ?other-lhs*)
	    (values (cons (if (identifier? ?id)
			      ?id
			    (syntax-violation __who__
			      "expected identifier as syntactic binding name" ?id))
			  lhs*.id)
		    (cons (with-exception-handler
			      (lambda (E)
				(raise (condition (make-who-condition __who__)
						  (make-message-condition "invalid typed binding")
						  E)))
			    (lambda ()
			      (type-annotation->object-type-spec ?type lexenv ?type)))
			  lhs*.ots))))
	 ((?id . ?other-lhs*)
	  (identifier? ?id)
	  (receive (lhs*.id lhs*.ots)
	      (recur ?other-lhs*)
	    (values (cons ?id lhs*.id)
		    (cons untyped.ots lhs*.ots))))
	 (?thing
	  (syntax-violation __who__
	    "expected optionally typed identifier as syntactic binding name" ?thing)))))))


;;;; standard binding parsing: standard LAMBDA formals

(module (syntax-object.parse-standard-formals)
  ;;Parse the  given syntax  object as standard  (untyped) LET-VALUES  formals (these
  ;;formals are  equal to the ones  of standard lambda clauses).   Test for duplicate
  ;;bindings.  If the syntax is invalid: raise an exception.
  ;;
  ;;When successful return the following values:
  ;;
  ;;1. A  proper or improper list  of identifiers representing the  standard formals.
  ;;   It is the argument FORMALS.STX itself, but fully unwrapped.
  ;;
  ;;2. An instance of "<type-signature>" representing the types of the formals.
  ;;
  ;;NOTE We return two values (including FORMALS.STX  itself) to make the API of this
  ;;function equal to  the one of SYNTAX-OBJECT.PARSE-TYPED-FORMALS, so  that the two
  ;;can be used as:
  ;;
  ;;   (if (options::typed-language-enabled?)
  ;;       (syntax-object.parse-typed-formals formals.stx)
  ;;     (syntax-object.parse-standard-formals formals.stx))
  ;;
  ;;it makes the code simpler to read.  (Marco Maggi; Wed Feb  3, 2016)
  ;;
  (define-module-who syntax-object.parse-standard-formals)

  (define (syntax-object.parse-standard-formals input-formals.stx)
    (receive (standard-formals.stx formals.ots)
	(%parse-standard-formals input-formals.stx)
      (values standard-formals.stx (make-type-signature formals.ots))))

  (define* (%parse-standard-formals input-formals.stx)
    (define-synner %synner __module_who__ input-formals.stx)
    (syntax-match input-formals.stx (brace)
      (?args-id
       (identifier? ?args-id)
       (values ?args-id (<list>-ots)))

      (()
       (values '() '()))

      ((?arg0 ?arg* ...)
       (let ((standard-formals.stx	(cons ?arg0 ?arg*)))
	 (%validate-standard-formals standard-formals.stx %synner)
	 (values standard-formals.stx (%one-untyped-for-each standard-formals.stx))))

      ((?arg0 ?arg* ... . ?rest-id)
       (let* ((arg*.stx			(cons ?arg0 ?arg*))
	      (standard-formals.stx	(append arg*.stx ?rest-id)))
	 (%validate-standard-formals standard-formals.stx %synner)
	 ;;This APPEND application returns an improper list.
	 (values standard-formals.stx (append (%one-untyped-for-each arg*.stx) (<list>-ots)))))

      (_
       (%synner "invalid standard formals syntax"))))

  (define (%validate-standard-formals standard-formals.stx synner)
    ;;We expect STANDARD-FORMALS.STX to be fully unwrapped.
    ;;
    (let loop ((stx standard-formals.stx))
      (cond ((pair? stx)
	     (if (identifier? (car stx))
		 (loop (cdr stx))
	       (synner "expected identifier as formals component" (car stx))))
	    ((or (null?       stx)
		 (identifier? stx)))
	    (else
	     (synner "expected identifier as formals component" stx))))
    (cond ((duplicate-bound-formals? standard-formals.stx)
	   => (lambda (duplicate-id)
		(synner "duplicate identifiers in formals syntax" duplicate-id)))))

  (define (%one-untyped-for-each item*)
    ;;Here we use "<top>" for the  untyped syntactic binding, because this subject of
    ;;the parsing is a formals syntax object: we do not want "<untyped>" OTSs lurking
    ;;in there.
    (map (lambda (x) (<top>-ots)) item*))

  #| end of module: SYNTAX-OBJECT.PARSE-STANDARD-FORMALS |# )


;;;; tagged binding parsing: typed LAMBDA formals

(module (syntax-object.parse-typed-formals)
  ;;Parse a  syntax object as  possibly typed  LET-VALUES formals (these  formals are
  ;;different from  the one  of LAMBDA  clauses because they  have no  return values'
  ;;types).   Test for  duplicate  bindings.   If the  syntax  is  invalid: raise  an
  ;;exception.
  ;;
  ;;When successful return the following values:
  ;;
  ;;1. A  proper or improper list  of identifiers representing the  standard formals.
  ;;This list is fully unwrapped.
  ;;
  ;;2. An instance of "<type-signature>" representing the types of the formals.
  ;;
  (define-module-who syntax-object.parse-typed-formals)

  (case-define syntax-object.parse-typed-formals
    ((input-formals.stx)
     ;;By  default  we  use  "<top>"  for the  untyped  syntactic  binding.   We  use
     ;;"<untyped>" only if explicitly requested by the caller.
     (syntax-object.parse-typed-formals input-formals.stx (<top>-ots)))
    ((input-formals.stx untyped.ots)
     (receive (standard-formals.stx formals.ots)
	 (%parse-typed-formals input-formals.stx untyped.ots)
       (values standard-formals.stx (make-type-signature formals.ots)))))

  (define (%parse-typed-formals input-formals.stx untyped.ots)
    (define-synner %synner __module_who__ input-formals.stx)
    (define lexenv (current-inferior-lexenv))
    (syntax-match input-formals.stx (brace)

      ;;Non-standard formals: typed args, as in: (lambda (brace args <list>) ---)
      ((brace ?args-id ?args-type)
       (identifier? ?args-id)
       (values ?args-id (try
			    (tail-type-annotation->object-type-spec ?args-type lexenv ?args-type)
			  (catch E
			    (else
			     (%synner "invalid type annotation for return values" ?args-type))))))

      ;;Standard formals, UNtyped args as in: (lambda args ---)
      (?args-id
       (identifier? ?args-id)
       (values ?args-id (<list>-ots)))

      ;;Non-standard formals: possibly typed arguments with typed rest argument.
      ((?arg0 ?arg* ... . (brace ?rest-id ?rest-type))
       (receive-and-return (standard-formals.stx formals.ots)
	   (let process-next-arg ((arg*.stx (cons ?arg0 ?arg*)))
	     (cond ((pair? arg*.stx)
		    (%process-arg* arg*.stx untyped.ots lexenv process-next-arg %synner))
		   ((identifier? ?rest-id)
		    (values ?rest-id (try
					 (tail-type-annotation->object-type-spec ?rest-type lexenv ?rest-type)
				       (catch E
					 (else
					  (%synner "invalid type annotation for rest argument" ?rest-type))))))
		   (else
		    (%synner "invalid rest argument syntax" (list (brace-id) ?rest-id ?rest-type)))))
	 (%validate-standard-formals standard-formals.stx %synner)))

      ;;Standard formals: UNtyped identifiers without rest argument.
      ((?arg* ...)
       (for-all identifier? ?arg*)
       (receive-and-return (standard-formals.stx formals.ots)
	   (values ?arg* (%one-untyped-for-each ?arg* untyped.ots))
	 (%validate-standard-formals standard-formals.stx %synner)))

      ;;Standard formals: UNtyped identifiers with UNtyped rest argument.
      ((?arg0 ?arg* ... . ?rest-id)
       (and (for-all identifier? (cons ?arg0 ?arg*))
	    (identifier? ?rest-id))
       (let ((arg*.stx (cons ?arg0 ?arg*)))
	 (receive-and-return (standard-formals.stx formals.ots)
	     (values (append arg*.stx ?rest-id)
		     (append (%one-untyped-for-each arg*.stx untyped.ots) (<list>-ots)))
	   (%validate-standard-formals standard-formals.stx %synner))))

      ;;Non-standard formals: possibly typed identifiers with UNtyped rest argument.
      ((?arg0 ?arg* ... . ?rest-id)
       (identifier? ?rest-id)
       (receive-and-return (standard-formals.stx formals.ots)
	   (let process-next-arg ((arg*.stx (cons ?arg0 ?arg*)))
	     (cond ((pair? arg*.stx)
		    (%process-arg* arg*.stx untyped.ots lexenv process-next-arg %synner))
		   ((identifier? ?rest-id)
		    (values ?rest-id (<list>-ots)))
		   (else
		    (%synner "invalid rest argument syntax" ?rest-id))))
	 (%validate-standard-formals standard-formals.stx %synner)))

      ;;Non-standard formals: possibly typed identifiers without rest argument.
      ;;
      ((?arg* ...)
       (receive-and-return (standard-formals.stx formals.ots)
	   (let process-next-arg ((arg*.stx ?arg*))
	     (if (pair? arg*.stx)
		 (%process-arg* arg*.stx untyped.ots lexenv process-next-arg %synner)
	       (values '() '())))
	 (%validate-standard-formals standard-formals.stx %synner)))

      (_
       (%synner "invalid formals syntax"))))

  (define (%process-arg* arg*.stx untyped.ots lexenv process-next-arg synner)
    (receive (standard-formals.stx formals.ots)
	(process-next-arg (cdr arg*.stx))
      (let ((arg.stx (car arg*.stx)))
	(syntax-match arg.stx (brace)
	  ;;Untyped argument.
	  (?id
	   (identifier? ?id)
	   (values (cons ?id standard-formals.stx) (cons untyped.ots formals.ots)))
	  ;;Typed argument.
	  ((brace ?id ?type)
	   (identifier? ?id)
	   (values (cons ?id standard-formals.stx)
		   (cons (try
			     (type-annotation->object-type-spec ?type lexenv)
			   (catch E
			     (else
			      (synner "invalid type annotation for argument" ?type))))
			 formals.ots)))
	  (else
	   (synner "invalid argument in formals syntax" arg.stx))))))

  (define (%validate-standard-formals standard-formals.stx synner)
    (cond ((duplicate-bound-formals? standard-formals.stx)
	   => (lambda (duplicate-id)
		(synner "duplicate identifiers in formals syntax" duplicate-id)))))

  (define (%one-untyped-for-each item* untyped.ots)
    (map (lambda (x) untyped.ots) item*))

  #| end of module: SYNTAX-OBJECT.PARSE-TYPED-FORMALS |# )


;;;; type syntax objects: standard formals parsing

(define* (syntax-object.parse-standard-clambda-clause-formals input-formals.stx)
  ;;Given a syntax object parse it as  standard lambda formals; do test for duplicate
  ;;bindings.  Return the following values:
  ;;
  ;;1. The argument INPUT-FORMALS.STX fully unwrapped.
  ;;
  ;;2. An instance of "<lambda-signature>".
  ;;
  ;;As usage example, when the syntax use:
  ;;
  ;;   (lambda/std ?formals . ?body)
  ;;
  ;;is parsed, this function is called as:
  ;;
  ;;   (syntax-object.parse-standard-clambda-clause-formals #'?formals)
  ;;
  (receive (standard-formals.stx argvals.sig)
      (syntax-object.parse-standard-formals input-formals.stx)
    (let ((retvals.sig (make-type-signature/fully-unspecified)))
      (values standard-formals.stx (make-lambda-signature retvals.sig argvals.sig)))))

(define (syntax-object.parse-standard-clambda-multi-clauses-formals input-formals*.stx)
  ;;Given a list of syntax objects  INPUT-FORMALS*.STX: parse them as clambda clauses
  ;;standard formals; do test for duplicate bindings.  Return the following values:
  ;;
  ;;1. The argument INPUT-FORMALS*.STX fully unwrapped.
  ;;
  ;;2. A list of "<lambda-signature>" instances.
  ;;
  ;;As usage example, when the syntax use:
  ;;
  ;;   (case-lambda/std (?formals . ?body) ...)
  ;;
  ;;is parsed, this function is called as:
  ;;
  ;;   (syntax-object.parse-standard-clambda-multi-clauses-formals (#'?formals ...))
  ;;
  (let recur ((input-formals*.stx input-formals*.stx))
    (if (pair? input-formals*.stx)
	(receive (standard-formals.stx clause-signature)
	    (syntax-object.parse-standard-clambda-clause-formals (car input-formals*.stx))
	  (receive (standard-formals*.stx clause-signature*)
	      (recur (cdr input-formals*.stx))
	    (values (cons standard-formals.stx standard-formals*.stx)
		    (cons clause-signature     clause-signature*))))
      (values '() '()))))

(define* (syntax-object.standard-clambda-clause-formals? input-formals.stx)
  ;;Return true if  INPUT-FORMALS.STX is a syntax object  representing valid standard
  ;;formals for a LAMBDA or LET-VALUES syntax.
  ;;
  (guard (E ((syntax-violation? E)
	     #f))
    (syntax-object.parse-standard-formals input-formals.stx)
    #t))


;;;; type syntax objects: tagged binding parsing, callable signature

(case-define* syntax-object.parse-typed-clambda-clause-formals
  ((input-formals.stx)
   ;;By default we use "<top>" for the untyped syntactic binding.  We use "<untyped>"
   ;;only if explicitly requested by the caller.
   (syntax-object.parse-typed-clambda-clause-formals input-formals.stx (<top>-ots)))
  ((input-formals.stx untyped.ots)
   ;;Given a  syntax object representing  a typed  callable spec: split  the standard
   ;;formals  from the  type signature;  do test  for duplicate  bindings.  Return  2
   ;;values:
   ;;
   ;;1. A proper or improper list of identifiers representing the standard formals.
   ;;
   ;;2. An instance of "<lambda-signature>".
   ;;
   ;;This function *does* enforce the  constraint: the identifiers in type identifier
   ;;positions must actually  be type identifiers (with  syntactic binding descriptor
   ;;already added to the LEXENV).
   ;;
   ;;As usage example, when the syntax use:
   ;;
   ;;   (lambda/typed ?formals . ?body)
   ;;
   ;;is parsed, this function is called as:
   ;;
   ;;   (syntax-object.parse-typed-clambda-clause-formals #'?formals)
   ;;
   (syntax-match input-formals.stx (brace)
     ;;With return values tagging.
     (((brace ?who . ?rv-types) . ?arg-formals)
      (underscore-id? ?who)
      (receive (standard-formals.stx argvals.sig)
	  (syntax-object.parse-typed-formals ?arg-formals untyped.ots)
	(values standard-formals.stx
		(let* ((synner		(lambda (message subform)
					  (syntax-violation __who__ message input-formals.stx subform)))
		       (retvals.sig	(make-type-signature
					 (syntax-object->type-signature-specs ?rv-types (current-inferior-lexenv) synner))))
		  (make-lambda-signature retvals.sig argvals.sig)))))
     ;;Without return values tagging.
     (?arg-formals
      (receive (standard-formals.stx argvals.sig)
	  (syntax-object.parse-typed-formals ?arg-formals untyped.ots)
	(values standard-formals.stx
		(make-lambda-signature (make-type-signature/fully-unspecified) argvals.sig)))))))

(case-define* syntax-object.parse-typed-clambda-multi-clauses-formals
  ((input-formals*.stx)
   ;;By default we use "<top>" for the untyped syntactic binding.  We use "<untyped>"
   ;;only if explicitly requested by the caller.
   (syntax-object.parse-typed-clambda-multi-clauses-formals input-formals*.stx (<top>-ots)))
  ((input-formals*.stx untyped.ots)
   ;;Given a list of syntax objects INPUT-FORMALS*.STX: parse them as clambda clauses
   ;;typed formals; do test for duplicate bindings.  Return the following values:
   ;;
   ;;1. A list of syntax objects representing the standard formals of each clause.
   ;;
   ;;2. A list of "<lambda-signature>" instances.
   ;;
   ;;As usage example, when the syntax use:
   ;;
   ;;   (case-lambda/typed (?formals . ?body) ...)
   ;;
   ;;is parsed, this function is called as:
   ;;
   ;;   (syntax-object.parse-typed-clambda-multi-clauses-formals (#'?formals ...))
   ;;
   (let recur ((input-formals*.stx input-formals*.stx))
     (if (pair? input-formals*.stx)
	 (receive (standard-formals.stx clause-signature)
	     (syntax-object.parse-typed-clambda-clause-formals (car input-formals*.stx) untyped.ots)
	   (receive (standard-formals*.stx clause-signature*)
	       (recur (cdr input-formals*.stx))
	     (values (cons standard-formals.stx standard-formals*.stx)
		     (cons clause-signature     clause-signature*))))
       (values '() '())))))

(define* (syntax-object.typed-clambda-clause-formals? input-formals.stx)
  ;;Return true  if INPUT-FORMALS.STX  is a syntax  object representing  valid tagged
  ;;formals for a LAMBDA syntax.
  ;;
  (guard (E ((syntax-violation? E)
	     #f))
    (receive (standard-formals signature-tags)
	(syntax-object.parse-typed-clambda-clause-formals input-formals.stx)
      #t)))


;;;; type syntax objects: tagged binding parsing

(define* (typed-formals-syntax->args-list input-formals.stx)
  ;;Examples:
  ;;
  ;;   (typed-formals-syntax->args-list #'args)
  ;;   => #'(args) #t
  ;;
  ;;   (typed-formals-syntax->args-list #'(brace args <fixnum>))
  ;;   => #'(args) #t
  ;;
  ;;   (typed-formals-syntax->args-list #'(a b))
  ;;   => #'(a b) #f
  ;;
  ;;   (typed-formals-syntax->args-list #'((brace a <fixnum>) (brace b <string>)))
  ;;   => #'(a b) #f
  ;;
  ;;   (typed-formals-syntax->args-list #'(a b . rest))
  ;;   => #'(a b rest) #t
  ;;
  ;;   (typed-formals-syntax->args-list #'((brace a <fixnum>) (brace b <string>) . rest))
  ;;   => #'(a b rest) #t
  ;;
  (define who __who__)
  (define-synner %synner who input-formals.stx)

  (syntax-match input-formals.stx (brace)
    ;;Non-standard formals: typed args, as in: (lambda (brace args <list>) ---)
    ((brace ?args-id ?args-type)
     (identifier? ?args-id)
     (values (list ?args-id) #t))

    ;;Standard formals, UNtyped args as in: (lambda args ---)
    (?args-id
     (identifier? ?args-id)
     (values (list ?args-id) #t))

    ;;Non-standard formals: possibly typed arguments with typed rest argument.
    ((?arg0 ?arg* ... . (brace ?rest-id ?rest-type))
     (values (append (map (lambda (arg.stx)
			    (syntax-match arg.stx (brace)
			      (?id
			       (identifier? ?id)
			       ?id)
			      ((brace ?id ?type)
			       ?id)
			      (_
			       (%synner "invalid argument syntax" arg.stx))))
		       (cons ?arg0 ?arg*))
		     (list ?rest-id))
	     #t))

    ;;Standard formals: UNtyped identifiers without rest argument.
    ((?arg* ...)
     (for-all identifier? ?arg*)
     (values ?arg* #f))

    ;;Standard formals: UNtyped identifiers with UNtyped rest argument.
    ((?arg0 ?arg* ... . ?rest-id)
     (and (for-all identifier? (cons ?arg0 ?arg*))
	  (identifier? ?rest-id))
     (values (append (cons ?arg0 ?arg*)
		     (list ?rest-id))
	     #t))

    ;;Non-standard formals: possibly typed identifiers with UNtyped rest argument.
    ((?arg0 ?arg* ... . ?rest-id)
     (identifier? ?rest-id)
     (values (append (map (lambda (arg.stx)
			    (syntax-match arg.stx (brace)
			      (?id
			       (identifier? ?id)
			       ?id)
			      ((brace ?id ?type)
			       ?id)
			      (_
			       (%synner "invalid argument syntax" arg.stx))))
		       (cons ?arg0 ?arg*))
		     (list ?rest-id))
	     #t))

    ;;Non-standard formals: possibly typed identifiers without rest argument.
    ((?arg* ...)
     (values (map (lambda (arg.stx)
		    (syntax-match arg.stx (brace)
		      (?id
		       (identifier? ?id)
		       ?id)
		      ((brace ?id ?type)
		       ?id)
		      (_
		       (%synner "invalid argument syntax" arg.stx))))
	       ?arg*)
	     #f))

    (_
     (%synner "invalid formals syntax"))))


;;;; done

#| end of module |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; End:
