#!../src/vicare -b vicare.boot --r6rs-script
;;;Ikarus Scheme -- A compiler for R6RS Scheme.
;;;Copyright (C) 2006,2007,2008  Abdulaziz Ghuloum
;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;Abstract
;;;
;;;	This  file  is  an  R6RS-compliant Scheme  program,  using  some
;;;	Vicare's  extension.   When  run  in the  appropriate  operating
;;;	system   environment:    it   rebuilds   Vicare's    boot   file
;;;	"vicare.boot".
;;;
;;;	This  program works hand-in-hand  with the  expander, especially
;;;	the    library   (psyntax    library-manager)   in    the   file
;;;	"psyntax.library-manager.sls".
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
;;;You should  have received  a copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;


;;;; adding a primitive operation to an existing system library
;;
;;*NOTE* This  description is a work  in progress (Marco  Maggi; Nov 30,
;;2011).
;;
;;Primitive operations are defined by the macro DEFINE-PRIMOPS; examples
;;are: $CAR, $CDR, $FX+ and $VECTOR-LENGTH but also FIXNUM? and STRING?.
;;
;;Here we want to examine the process of adding a primitive operation to
;;an  existing system library;  we will  not discuss  how to  define the
;;operation using the macro DEFINE-PRIMOPS.
;;
;;What is a primitive operation?  We can think of it as a macro embedded
;;in  the compiler,  which,  when used,  expands  inline the  elementary
;;instructions  to be  converted  to machine  language.  The  elementary
;;instructions are  expressed in Vicare's  high-level assembly language.
;;When building a new boot image we can use in Vicare's source code only
;;the primitive operations compiled in an existing boot image.
;;
;;Let's say  we want to generate  a new boot image  having the operation
;;$SWIRL-PAIR embedded in it and exported by the system library:
;;
;;   (ikarus system $pairs)
;;
;;which  already exists,  and making  use of  the operation  in Vicare's
;;source code; this is the scenario:
;;
;;1. The image BOOT-0 already exists.
;;
;;2. We  generate a  new temporary image,  BOOT-1, having  the operation
;;$SWIRL-PAIR embedded in it, but not using it anywhere.
;;
;;3.  We  generate another new  image, BOOT-2, which  offers $SWIRL-PAIR
;;and also uses it in the source code.
;;
;;Let's go.
;;
;;First  we define  the  $SWIRL-PAIR operation  adding  to the  compiler
;;library (in the appropriate place) a form like:
;;
;;  (define-primop $swirl-pair unsafe ---)
;;
;;this form alone is enough to  make the compiler aware of the existence
;;of the  operation.  Then,  in this  makefile, we add  an entry  to the
;;table IDENTIFIER->LIBRARY-MAP as follows:
;;
;;   (define identifier->library-map
;;     '(($swirl-pair		$pairs)
;;       ---))
;;
;;the order in which the entries appear in this table is not important.
;;
;;With no other changes we use  the image BOOT-0 to build an image which
;;will be BOOT-1.   Now we can use $SWIRL-PAIR  in Vicare's source code,
;;then we use BOOT-1 to compile a new image which will be BOOT-2.
;;


;;;; adding a new system library
;;
;;*NOTE* This  description is a work  in progress (Marco  Maggi; Nov 30,
;;2011).
;;
;;By convention system libraries have names like:
;;
;;   (ikarus system <ID>)
;;
;;where  <ID> is prefixed  with a  $ character;  for good  style, system
;;libraries should export only primitive operations.
;;
;;Let's say we want to add to a boot image the library:
;;
;;  (ikarus system $spiffy)
;;
;;exporting the single primitive operation $SWIRL, this is the scenario:
;;
;;1. The image BOOT-0 already exists.
;;
;;2. We  generate a temporary new  image, BOOT-1, having  the new system
;;library in it but not in a correctly usable state.
;;
;;3. We  generate the another new  image, BOOT-2, having  the new system
;;library in a correct state.
;;
;;Let's go.
;;
;;First we  define the $SWIRL  operation adding to the  compiler library
;;(in the appropriate place) a form like:
;;
;;  (define-primop $swirl unsafe ---)
;;
;;this form alone is enough to  make the compiler aware of the existence
;;of the operation.  Then, in this  makefile, we add an entry at the end
;;of the table LIBRARY-LEGEND as follows:
;;
;;   (define library-legend
;;     '(---
;;       ($spiffy  (ikarus system $spiffy)  #t	#f))
;;
;;marking the library as visible but not required.  Then we add an entry
;;to the table IDENTIFIER->LIBRARY-MAP as follows:
;;
;;   (define identifier->library-map
;;     '(($swirl $spiffy)
;;       ---))
;;
;;the order in which the entries appear in this table is not important.
;;
;;Now we use the image BOOT-0  to build a new boot image, BOOT-1, having
;;the new library in it.  Then  we change the library entry in the table
;;LIBRARY-LEGEND as follows:
;;
;;       ($spiffy  (ikarus system $spiffy)  #t	#t)
;;
;;making it both visible and required.   Then we use the image BOOT-1 to
;;generate a new boot image which will be BOOT-2.
;;


(import (only (ikarus) import))
(import (except (ikarus)
		current-letrec-pass
		current-core-eval
		assembler-output optimize-cp optimize-level
		cp0-size-limit cp0-effort-limit expand/optimize
		expand/scc-letrec expand
		optimizer-output tag-analysis-output perform-tag-analysis))
(import (ikarus.compiler))
(import (except (psyntax system $bootstrap)
                eval-core
                current-primitive-locations
                compile-core-expr-to-port))
#;(import (only (ikarus.posix)
	      getenv))
(import (ikarus.compiler)) ; just for fun

(optimize-level 2)
(perform-tag-analysis #t)
(pretty-width 160)
((pretty-format 'fix)
 ((pretty-format 'letrec)))
(strip-source-info #t)
(current-letrec-pass 'scc)

;;(set-port-buffer-mode! (current-output-port) (buffer-mode none))


;;;; helpers

(define boot-file-name
  "vicare.boot")

(define src-dir
  (or (getenv "VICARE_SRC_DIR") "."))

(define verbose-output? #t)

(define-syntax each-for
  (syntax-rules ()
    ((_ ?list ?lambda)
     (for-each ?lambda ?list))))

(define (make-collection)
  ;;Return a  closure to handle lists of  elements called "collections".
  ;;When  the closure  is  invoked  with no  arguments:  it returns  the
  ;;collection.   When  the closure  is  invoked  with  an argument:  it
  ;;prepends  the  argument  to  the  collection  without  checking  for
  ;;duplicates.
  ;;
  (let ((set '()))
    (case-lambda
     (()  set)
     ((x)
      (set! set (cons x set))))))

(define debug-printf
  (if verbose-output?
      (lambda args
	(let ((port (console-error-port)))
	  (apply fprintf port args)
	  (flush-output-port port)))
    (case-lambda
     ((str)
      (let ((port (console-error-port)))
	(fprintf port str)
	(flush-output-port port)))
     ((str . args)
      (let ((port (console-error-port)))
	(fprintf port ".")
	(flush-output-port port))))))

(define (pretty-print/stderr thing)
  (let ((port (console-error-port)))
    (pretty-print thing port)
    (flush-output-port port)))


(define scheme-library-files
  ;;Listed in the order in which they're loaded.
  ;;
  ;;Loading of the boot file may  segfault if a library is loaded before
  ;;its dependencies are loaded first.
  ;;
  ;;The  reason  is that  the  base libraries  are  not  a hierarchy  of
  ;;dependencies but rather an eco system in which every part depends on
  ;;the other.
  ;;
  ;;For  example,  the printer  may  call error  if  it  finds an  error
  ;;(e.g. "not an output port"),  while the error procedure may call the
  ;;printer to  display the message.  This  works fine as  long as error
  ;;does  not itself  cause an  error (which  may lead  to  the infamous
  ;;Error: Error: Error: Error: Error: Error: Error: Error: Error: ...).
  ;;
  '("ikarus.singular-objects.sls"
    "ikarus.handlers.sls"
    "ikarus.multiple-values.sls"
    "ikarus.control.sls"
    "ikarus.exceptions.sls"
    "ikarus.collect.sls"
    "ikarus.apply.sls"
    "ikarus.predicates.sls"
    "ikarus.equal.sls"
    "ikarus.pairs.sls"
    "ikarus.lists.sls"
    "ikarus.fixnums.sls"
    "ikarus.chars.sls"
    "ikarus.structs.sls"
    "ikarus.records.procedural.sls"
    "ikarus.strings.sls"
    "ikarus.unicode-conversion.sls"
    "ikarus.date-string.sls"
    "ikarus.symbols.sls"
    "ikarus.vectors.sls"
    "ikarus.unicode.sls"
    "ikarus.string-to-number.sls"
    "ikarus.numerics.sls"
    "ikarus.conditions.sls"
    "ikarus.guardians.sls"
    "ikarus.symbol-table.sls"
    "ikarus.codecs.sls"
    "ikarus.bytevectors.sls"
    "ikarus.pointers.sls"
    "ikarus.posix.sls"
    "ikarus.io.sls"
    "ikarus.hash-tables.sls"
    "ikarus.pretty-formats.sls"
    "ikarus.writer.sls"
    "ikarus.foreign-libraries.sls"
    "ikarus.reader.sls"
    "ikarus.code-objects.sls"
    "ikarus.intel-assembler.sls"
    "ikarus.fasl.write.sls"
    "ikarus.fasl.read.sls"
    "ikarus.compiler.sls"
    "psyntax.compat.sls"
    "psyntax.library-manager.sls"
    "psyntax.internal.sls"
    "psyntax.config.sls"
    "psyntax.builders.sls"
    "psyntax.expander.sls"
    "ikarus.apropos.sls"
    "ikarus.load.sls"
    "ikarus.pretty-print.sls"
    "ikarus.readline.sls"
    "ikarus.cafe.sls"
    "ikarus.timer.sls"
    "ikarus.time-and-date.sls"
    "ikarus.sort.sls"
    "ikarus.promises.sls"
    "ikarus.enumerations.sls"
    "ikarus.command-line.sls"
;;; "ikarus.trace.sls"
    "ikarus.debugger.sls"
    "ikarus.main.sls"
    ))


(define ikarus-system-macros
  '((define				(define))
    (define-syntax			(define-syntax))
    (define-fluid-syntax		(define-fluid-syntax))
    (module				(module))
    (library				(library))
    (begin				(begin))
    (import				(import))
    (export				(export))
    (set!				(set!))
    (let-syntax				(let-syntax))
    (letrec-syntax			(letrec-syntax))
    (stale-when				(stale-when))
    (foreign-call			(core-macro . foreign-call))
    (quote				(core-macro . quote))
    (syntax-case			(core-macro . syntax-case))
    (syntax				(core-macro . syntax))
    (lambda					(core-macro . lambda))
    (case-lambda			(core-macro . case-lambda))
    (type-descriptor			(core-macro . type-descriptor))
    (letrec				(core-macro . letrec))
    (letrec*				(core-macro . letrec*))
    (if					(core-macro . if))
    (fluid-let-syntax			(core-macro . fluid-let-syntax))
    (record-type-descriptor		(core-macro . record-type-descriptor))
    (record-constructor-descriptor	(core-macro . record-constructor-descriptor))
    (let-values				(macro . let-values))
    (let*-values			(macro . let*-values))
    (define-struct			(macro . define-struct))
    (case				(macro . case))
    (syntax-rules			(macro . syntax-rules))
    (quasiquote				(macro . quasiquote))
    (quasisyntax			(macro . quasisyntax))
    (with-syntax			(macro . with-syntax))
    (identifier-syntax			(macro . identifier-syntax))
    (parameterize			(macro . parameterize))
    (parametrise			(macro . parameterize))
    (when				(macro . when))
    (unless				(macro . unless))
    (let				(macro . let))
    (let*				(macro . let*))
    (cond				(macro . cond))
    (do					(macro . do))
    (and				(macro . and))
    (or					(macro . or))
    (time				(macro . time))
    (delay				(macro . delay))
    (endianness				(macro . endianness))
    (assert				(macro . assert))
    (...				(macro . ...))
    (=>					(macro . =>))
    (else				(macro . else))
    (_					(macro . _))
    (unquote				(macro . unquote))
    (unquote-splicing			(macro . unquote-splicing))
    (unsyntax				(macro . unsyntax))
    (unsyntax-splicing			(macro . unsyntax-splicing))
    (trace-lambda			(macro . trace-lambda))
    (trace-let				(macro . trace-let))
    (trace-define			(macro . trace-define))
    (trace-define-syntax		(macro . trace-define-syntax))
    (trace-let-syntax			(macro . trace-let-syntax))
    (trace-letrec-syntax		(macro . trace-letrec-syntax))
    (guard				(macro . guard))
    (eol-style				(macro . eol-style))
    (buffer-mode			(macro . buffer-mode))
    (file-options			(macro . file-options))
    (error-handling-mode		(macro . error-handling-mode))
    (fields				(macro . fields))
    (mutable				(macro . mutable))
    (immutable				(macro . immutable))
    (parent				(macro . parent))
    (protocol				(macro . protocol))
    (sealed				(macro . sealed))
    (opaque				(macro . opaque ))
    (nongenerative			(macro . nongenerative))
    (parent-rtd				(macro . parent-rtd))
    (define-record-type			(macro . define-record-type))
    (define-enumeration			(macro . define-enumeration))
    (define-condition-type		(macro . define-condition-type))
;;;
    (&condition				($core-rtd . (&condition-rtd
						      &condition-rcd)))
    (&message				($core-rtd . (&message-rtd
						      &message-rcd)))
    (&warning				($core-rtd . (&warning-rtd
						      &warning-rcd)))
    (&serious				($core-rtd . (&serious-rtd
						      &serious-rcd)))
    (&error				($core-rtd . (&error-rtd
						      &error-rcd)))
    (&violation				($core-rtd . (&violation-rtd
						      &violation-rcd)))
    (&assertion				($core-rtd . (&assertion-rtd
						      &assertion-rcd)))
    (&irritants				($core-rtd . (&irritants-rtd
						      &irritants-rcd)))
    (&who				($core-rtd . (&who-rtd
						      &who-rcd)))
    (&non-continuable			($core-rtd . (&non-continuable-rtd
						      &non-continuable-rcd)))
    (&implementation-restriction	($core-rtd . (&implementation-restriction-rtd
						      &implementation-restriction-rcd)))
    (&lexical				($core-rtd . (&lexical-rtd
						      &lexical-rcd)))
    (&syntax				($core-rtd . (&syntax-rtd
						      &syntax-rcd)))
    (&undefined				($core-rtd . (&undefined-rtd
						      &undefined-rcd)))
    (&i/o				($core-rtd . (&i/o-rtd
						      &i/o-rcd)))
    (&i/o-read				($core-rtd . (&i/o-read-rtd
						      &i/o-read-rcd)))
    (&i/o-write				($core-rtd . (&i/o-write-rtd
						      &i/o-write-rcd)))
    (&i/o-invalid-position		($core-rtd . (&i/o-invalid-position-rtd
						      &i/o-invalid-position-rcd)))
    (&i/o-filename			($core-rtd . (&i/o-filename-rtd
						      &i/o-filename-rcd)))
    (&i/o-file-protection		($core-rtd . (&i/o-file-protection-rtd
						      &i/o-file-protection-rcd)))
    (&i/o-file-is-read-only		($core-rtd . (&i/o-file-is-read-only-rtd
						      &i/o-file-is-read-only-rcd)))
    (&i/o-file-already-exists		($core-rtd . (&i/o-file-already-exists-rtd
						      &i/o-file-already-exists-rcd)))
    (&i/o-file-does-not-exist		($core-rtd . (&i/o-file-does-not-exist-rtd
						      &i/o-file-does-not-exist-rcd)))
    (&i/o-port				($core-rtd . (&i/o-port-rtd
						      &i/o-port-rcd)))
    (&i/o-decoding			($core-rtd . (&i/o-decoding-rtd
						      &i/o-decoding-rcd)))
    (&i/o-encoding			($core-rtd . (&i/o-encoding-rtd
						      &i/o-encoding-rcd)))
    (&i/o-eagain			($core-rtd . (&i/o-eagain-rtd
    						      &i/o-eagain-rcd)))
    (&errno				($core-rtd . (&errno-rtd
    						      &errno-rcd)))
    (&out-of-memory-error		($core-rtd . (&out-of-memory-error-rtd
    						      &out-of-memory-error-rcd)))
    (&h_errno				($core-rtd . (&h_errno-rtd
    						      &h_errno-rcd)))
    (&no-infinities			($core-rtd . (&no-infinities-rtd
						      &no-infinities-rcd)))
    (&no-nans				($core-rtd . (&no-nans-rtd
						      &no-nans-rcd)))
    (&interrupted			($core-rtd . (&interrupted-rtd
						      &interrupted-rcd)))
    (&source				($core-rtd . (&source-rtd
						      &source-rcd)))
    ))


(define library-legend
  ;;Map full library specifications to nicknames: for example "i" is the
  ;;nickname  of  "(ikarus)".   Additionlly  tag  each  library  with  a
  ;;VISIBLE? and a REQUIRED? boolean.
  ;;
  ;;For each library  marked as REQUIRED?: an associated  record of type
  ;;LIBRARY   is  created   and  included   in  the   starting   set  of
  ;;BOOTSTRAP-COLLECTION.
  ;;
  ;;The libraries marked as VISIBLE? are installed in the boot image.
  ;;
  ;;See BOOTSTRAP-COLLECTION for details on how to add a library to this
  ;;list.
  ;;
  ;; abbr.              name			                visible? required?
  '((i			(ikarus)				#t	#t)
    (v			(vicare)				#t	#f)
    (cm			(chez modules)				#t	#t)
    (symbols		(ikarus symbols)			#t	#t)
    (parameters		(ikarus parameters)			#t	#t)
    (r			(rnrs)					#t	#t)
    (r5			(rnrs r5rs)				#t	#t)
    (ct			(rnrs control)				#t	#t)
    (ev			(rnrs eval)				#t	#t)
    (mp			(rnrs mutable-pairs)			#t	#t)
    (ms			(rnrs mutable-strings)			#t	#t)
    (pr			(rnrs programs)				#t	#t)
    (sc			(rnrs syntax-case)			#t	#t)
    (fi			(rnrs files)				#t	#t)
    (sr			(rnrs sorting)				#t	#t)
    (ba			(rnrs base)				#t	#t)
    (ls			(rnrs lists)				#t	#t)
    (is			(rnrs io simple)			#t	#t)
    (bv			(rnrs bytevectors)			#t	#t)
    (uc			(rnrs unicode)				#t	#t)
    (ex			(rnrs exceptions)			#t	#t)
    (bw			(rnrs arithmetic bitwise)		#t	#t)
    (fx			(rnrs arithmetic fixnums)		#t	#t)
    (fl			(rnrs arithmetic flonums)		#t	#t)
    (ht			(rnrs hashtables)			#t	#t)
    (ip			(rnrs io ports)				#t	#t)
    (en			(rnrs enums)				#t	#t)
    (co			(rnrs conditions)			#t	#t)
    (ri			(rnrs records inspection)		#t	#t)
    (rp			(rnrs records procedural)		#t	#t)
    (rs			(rnrs records syntactic)		#t	#t)
;;;
    ($pairs		(ikarus system $pairs)			#f	#t)
    ($lists		(ikarus system $lists)			#f	#t)
    ($chars		(ikarus system $chars)			#f	#t)
    ($strings		(ikarus system $strings)		#f	#t)
    ($vectors		(ikarus system $vectors)		#f	#t)
    ($flonums		(ikarus system $flonums)		#f	#t)
    ($bignums		(ikarus system $bignums)		#f	#t)
    ($bytes		(ikarus system $bytevectors)		#f	#t)
    ($transc		(ikarus system $transcoders)		#f	#t)
    ($fx		(ikarus system $fx)			#f	#t)
    ($rat		(ikarus system $ratnums)		#f	#t)
    ($comp		(ikarus system $compnums)		#f	#t)
    ($symbols		(ikarus system $symbols)		#f	#t)
    ($structs		(ikarus system $structs)		#f	#t)
    ($pointers		(ikarus system $pointers)		#t	#t)
    ($codes		(ikarus system $codes)			#f	#t)
    ($tcbuckets		(ikarus system $tcbuckets)		#f	#t)
    ($arg-list		(ikarus system $arg-list)		#f	#t)
    ($stack		(ikarus system $stack)			#f	#t)
    ($interrupts	(ikarus system $interrupts)		#f	#t)
    ($io		(ikarus system $io)			#f	#t)
    ($for		(ikarus system $foreign)		#f	#t)
    ($all		(psyntax system $all)			#f	#t)
    ($boot		(psyntax system $bootstrap)		#f	#t)
;;;
    (ne			(psyntax null-environment-5)		#f	#f)
    (se			(psyntax scheme-report-environment-5)	#f	#f)
;;;
    (posix		(vicare $posix)				#t	#t)
    ))


(define identifier->library-map
  ;;Map  all the  identifiers of  exported  bindings (and  more) to  the
  ;;libraries   exporting   them,  using   the   nicknames  defined   by
  ;;LIBRARY-LEGEND.
  ;;
  ;;Notice that  the map includes  LIBRARY, IMPORT and EXPORT  which are
  ;;not bindings.
  ;;
  '((import					i v)
    (export					i v)
    (foreign-call				i v)
    (type-descriptor				i v)
    (parameterize				i v parameters)
    (parametrise				i v parameters)
    (define-struct				i v)
    (stale-when					i v)
    (time					i v)
    (trace-lambda				i v)
    (trace-let					i v)
    (trace-define				i v)
    (trace-define-syntax			i v)
    (trace-let-syntax				i v)
    (trace-letrec-syntax			i v)
    (make-list					i v)
    (last-pair					i v)
    (bwp-object?				i v)
    (weak-cons					i v)
    (weak-pair?					i v)
    (uuid					i v)
    (date-string				i v)
    (andmap					i v)
    (ormap					i v)
    (fx<					i v)
    (fx<=					i v)
    (fx>					i v)
    (fx>=					i v)
    (fx=					i v)
    (fxadd1					i v)
    (fxsub1					i v)
    (fxquotient					i v)
    (fxremainder				i v)
    (fxmodulo					i v)
    (fxsll					i v)
    (fxsra					i v)
    (sra					i v)
    (sll					i v)
    (fxlogand					i v)
    (fxlogxor					i v)
    (fxlogor					i v)
    (fxlognot					i v)
    (fixnum->string				i v)
    (string->flonum				i v)
    (add1					i v)
    (sub1					i v)
    (bignum?					i v)
    (ratnum?					i v)
    (compnum?					i v)
    (cflonum?					i v)
    (flonum-parts				i v)
    (flonum-bytes				i v)
    (quotient+remainder				i v)
    (flonum->string				i v)
    (random					i v)
    (gensym?					i v symbols)
    (getprop					i v symbols)
    (putprop					i v symbols)
    (remprop					i v symbols)
    (property-list				i v symbols)
    (gensym->unique-string			i v symbols)
    (symbol-bound?				i v symbols)
    (top-level-value				i v symbols)
    (reset-symbol-proc!				i v symbols)
    (make-guardian				i v)
    (port-mode					i v)
    (set-port-mode!				i v)
    (with-input-from-string			i v)
    (get-output-string				i v)
    (with-output-to-string			i v)
    (console-input-port				i v)
    (console-error-port				i v)
    (console-output-port			i v)
    (reset-input-port!				i v)
    (reset-output-port!				i v)
    (printf					i v)
    (fprintf					i v)
    (format					i v)
    (print-gensym				i v symbols)
    (print-graph				i v)
    (print-unicode				i v)
    (unicode-printable-char?			i v)
    (gensym-count				i v symbols)
    (gensym-prefix				i v symbols)
    (make-parameter				i v parameters)
    (call/cf					i v)
    (print-error				i v)
    (interrupt-handler				i v)
    (engine-handler				i v)
    (assembler-output				i v)
    (optimizer-output				i v)
    (new-cafe					i v)
    (waiter-prompt-string			i v)
    (readline-enabled?				i v)
    (readline					i v)
    (make-readline-input-port			i v)
    (expand					i v)
    (core-expand				i v)
    (expand/optimize				i v)
    (expand/scc-letrec				i v)
    (environment?				i v)
    (environment-symbols			i v)
    (time-and-gather				i v)
    (stats?					i v)
    (stats-user-secs				i v)
    (stats-user-usecs				i v)
    (stats-sys-secs				i v)
    (stats-sys-usecs				i v)
    (stats-real-secs				i v)
    (stats-real-usecs				i v)
    (stats-collection-id			i v)
    (stats-gc-user-secs				i v)
    (stats-gc-user-usecs			i v)
    (stats-gc-sys-secs				i v)
    (stats-gc-sys-usecs				i v)
    (stats-gc-real-secs				i v)
    (stats-gc-real-usecs			i v)
    (stats-bytes-minor				i v)
    (stats-bytes-major				i v)
    (time-it					i v)
    (verbose-timer				i v)
    (current-time				i v)
    (time?					i v)
    (time-second				i v)
    (time-gmt-offset				i v)
    (time-nanosecond				i v)
    (command-line-arguments			i v)
    (set-rtd-printer!				i v)
    (struct?					i v)
    (make-struct-type				i v)
    (struct-type-name				i v)
    (struct-type-symbol				i v)
    (struct-type-field-names			i v)
    (struct-constructor				i v)
    (struct-predicate				i v)
    (struct-field-accessor			i v)
    (struct-field-mutator			i v)
    (struct-length				i v)
    (struct-ref					i v)
    (struct-set!				i v)
    (struct-printer				i v)
    (struct-name				i v)
    (struct-type-descriptor			i v)
    (code?					i v)
    (immediate?					i v)
    (pointer-value				i v)
;;;
    (apropos					i v)
    (installed-libraries			i v)
    (uninstall-library				i v)
    (library-path				i v)
    (library-extensions				i v)
    (current-primitive-locations		$boot)
    (boot-library-expand			$boot)
    (current-library-collection			$boot)
    (library-name				$boot)
    (find-library-by-name			$boot)
    ($car					$pairs)
    ($cdr					$pairs)
    ($set-car!					$pairs)
    ($set-cdr!					$pairs)
    ($memq					$lists)
    ($memv					$lists)
    ($char?					$chars)
    ($char=					$chars)
    ($char<					$chars)
    ($char>					$chars)
    ($char<=					$chars)
    ($char>=					$chars)
    ($char->fixnum				$chars)
    ($fixnum->char				$chars)
    ($make-string				$strings)
    ($string-ref				$strings)
    ($string-set!				$strings)
    ($string-length				$strings)
    ($make-bytevector				$bytes)
    ($bytevector-length				$bytes)
    ($bytevector-s8-ref				$bytes)
    ($bytevector-u8-ref				$bytes)
    ($bytevector-set!				$bytes)
    ($bytevector-ieee-double-native-ref		$bytes)
    ($bytevector-ieee-double-native-set!	$bytes)
    ($bytevector-ieee-double-nonnative-ref	$bytes)
    ($bytevector-ieee-double-nonnative-set!	$bytes)
    ($bytevector-ieee-single-native-ref		$bytes)
    ($bytevector-ieee-single-native-set!	$bytes)
    ($bytevector-ieee-single-nonnative-ref	$bytes)
    ($bytevector-ieee-single-nonnative-set!	$bytes)
    ($flonum-u8-ref				$flonums)
    ($make-flonum				$flonums)
    ($flonum-set!				$flonums)
    ($flonum-signed-biased-exponent		$flonums)
    ($flonum-rational?				$flonums)
    ($flonum-integer?				$flonums)
    ($fl+					$flonums)
    ($fl-					$flonums)
    ($fl*					$flonums)
    ($fl/					$flonums)
    ($fl=					$flonums)
    ($fl<					$flonums)
    ($fl<=					$flonums)
    ($fl>					$flonums)
    ($fl>=					$flonums)
;;;($flround					$flonums)
    ($fixnum->flonum				$flonums)
    ($flonum-sbe				$flonums)
    ($make-bignum				$bignums)
    ($bignum-positive?				$bignums)
    ($bignum-size				$bignums)
    ($bignum-byte-ref				$bignums)
    ($bignum-byte-set!				$bignums)
    ($make-ratnum				$rat)
    ($ratnum-n					$rat)
    ($ratnum-d					$rat)
    ($make-compnum				$comp)
    ($compnum-real				$comp)
    ($compnum-imag				$comp)
    ($make-cflonum				$comp)
    ($cflonum-real				$comp)
    ($cflonum-imag				$comp)
    ($make-vector				$vectors)
    ($vector-length				$vectors)
    ($vector-ref				$vectors)
    ($vector-set!				$vectors)
    ($fxzero?					$fx)
    ($fxadd1					$fx)
    ($fxsub1					$fx)
    ($fx>=					$fx)
    ($fx<=					$fx)
    ($fx>					$fx)
    ($fx<					$fx)
    ($fx=					$fx)
    ($fxsll					$fx)
    ($fxsra					$fx)
    ($fxquotient				$fx)
    ($fxmodulo					fx)
;;;($fxmodulo					$fx)
    ($int-quotient				$fx)
    ($int-remainder				$fx)
    ($fxlogxor					$fx)
    ($fxlogor					$fx)
    ($fxlognot					$fx)
    ($fxlogand					$fx)
    ($fx+					$fx)
    ($fx*					$fx)
    ($fx-					$fx)
    ($fxinthash					$fx)
    ($make-symbol				$symbols)
    ($symbol-unique-string			$symbols)
    ($symbol-value				$symbols)
    ($symbol-string				$symbols)
    ($symbol-plist				$symbols)
    ($set-symbol-value!				$symbols)
    ($set-symbol-proc!				$symbols)
    ($set-symbol-string!			$symbols)
    ($set-symbol-unique-string!			$symbols)
    ($set-symbol-plist!				$symbols)
    ($unintern-gensym				$symbols)
    ($symbol-table-size				$symbols)
    ($init-symbol-value!)
    ($unbound-object?				$symbols)
    ($log-symbol-table-status			$symbols)
;;;
    (base-rtd					$structs)
    ($struct-set!				$structs)
    ($struct-ref				$structs)
    ($struct-rtd				$structs)
    ($struct					$structs)
    ($make-struct				$structs)
    ($struct?					$structs)
    ($struct/rtd?				$structs)

;;; --------------------------------------------------------------------
;;; (ikarus system $pointers)
    ($pointer?					$pointers)
    ($pointer=					$pointers)

;;;
    ($closure-code				$codes)
    ($code->closure				$codes)
    ($code-reloc-vector				$codes)
    ($code-freevars				$codes)
    ($code-size					$codes)
    ($code-annotation				$codes)
    ($code-ref					$codes)
    ($code-set!					$codes)
    ($set-code-annotation!			$codes)
    (procedure-annotation			i v)
    ($make-annotated-procedure			$codes)
    ($annotated-procedure-annotation		$codes)
    ($make-tcbucket				$tcbuckets)
    ($tcbucket-key				$tcbuckets)
    ($tcbucket-val				$tcbuckets)
    ($tcbucket-next				$tcbuckets)
    ($set-tcbucket-val!				$tcbuckets)
    ($set-tcbucket-next!			$tcbuckets)
    ($set-tcbucket-tconc!			$tcbuckets)
    ($arg-list					$arg-list)
    ($collect-key				$arg-list)
    ($$apply					$stack)
    ($fp-at-base				$stack)
    ($primitive-call/cc				$stack)
    ($frame->continuation			$stack)
    ($current-frame				$stack)
    ($seal-frame-and-call			$stack)
    ($make-call-with-values-procedure		$stack)
    ($make-values-procedure			$stack)
    ($interrupted?				$interrupts)
    ($unset-interrupted!			$interrupts)
    ($swap-engine-counter!			$interrupts)
;;;
    (interrupted-condition?			i v)
    (make-interrupted-condition			i v)
    (source-position-condition?			i v)
    (make-source-position-condition		i v)
    (source-position-port-id			i v)
    (source-position-byte			i v)
    (source-position-character			i v)
    (source-position-line			i v)
    (source-position-column			i v)

    ($apply-nonprocedure-error-handler)
    ($incorrect-args-error-handler)
    ($multiple-values-error)
    ($debug)
    ($underflow-misaligned-error)
    (top-level-value-error)
    (car-error)
    (cdr-error)
    (fxadd1-error)
    (fxsub1-error)
    (cadr-error)
    (fx+-type-error)
    (fx+-types-error)
    (fx+-overflow-error)
    ($do-event)
    (do-overflow)
    (do-overflow-words)
    (do-vararg-overflow)
    (collect					i v)
    (collect-key				i v)
    (post-gc-hooks				i v)
    (do-stack-overflow)
    (make-promise)
    (make-traced-procedure			i v)
    (make-traced-macro				i v)
    (error@fx+)
    (error@fxarithmetic-shift-left)
    (error@fxarithmetic-shift-right)
    (error@fx*)
    (error@fx-)
    (error@add1)
    (error@sub1)
    (error@fxadd1)
    (error@fxsub1)
    (fasl-write					i v)
    (fasl-read					i v)
    (fasl-directory				i v)
    (fasl-path					i v)
    (lambda						i v r ba se ne)
    (and					i v r ba se ne)
    (begin					i v r ba se ne)
    (case					i v r ba se ne)
    (cond					i v r ba se ne)
    (define					i v r ba se ne)
    (define-syntax				i v r ba se ne)
    (define-fluid-syntax			i v)
    (identifier-syntax				i v r ba)
    (if						i v r ba se ne)
    (let					i v r ba se ne)
    (let*					i v r ba se ne)
    (let*-values				i v r ba)
    (let-syntax					i v r ba se ne)
    (let-values					i v r ba)
    (fluid-let-syntax				i v)
    (letrec					i v r ba se ne)
    (letrec*					i v r ba)
    (letrec-syntax				i v r ba se ne)
    (or						i v r ba se ne)
    (quasiquote					i v r ba se ne)
    (quote					i v r ba se ne)
    (set!					i v r ba se ne)
    (syntax-rules				i v r ba se ne)
    (unquote					i v r ba se ne)
    (unquote-splicing				i v r ba se ne)
    (<						i v r ba se)
    (<=						i v r ba se)
    (=						i v r ba se)
    (>						i v r ba se)
    (>=						i v r ba se)
    (+						i v r ba se)
    (-						i v r ba se)
    (*						i v r ba se)
    (/						i v r ba se)
    (abs					i v r ba se)
    (asin					i v r ba se)
    (acos					i v r ba se)
    (atan					i v r ba se)
    (sinh					i v)
    (cosh					i v)
    (tanh					i v)
    (asinh					i v)
    (acosh					i v)
    (atanh					i v)
    (angle					i v r ba se)
    (append					i v r ba se)
    (apply					i v r ba se)
    (assert					i v r ba)
    (assertion-error) ;empty?!?
    (assertion-violation			i v r ba)
    (boolean=?					i v r ba)
    (boolean?					i v r ba se)
    (car					i v r ba se)
    (cdr					i v r ba se)
    (caar					i v r ba se)
    (cadr					i v r ba se)
    (cdar					i v r ba se)
    (cddr					i v r ba se)
    (caaar					i v r ba se)
    (caadr					i v r ba se)
    (cadar					i v r ba se)
    (caddr					i v r ba se)
    (cdaar					i v r ba se)
    (cdadr					i v r ba se)
    (cddar					i v r ba se)
    (cdddr					i v r ba se)
    (caaaar					i v r ba se)
    (caaadr					i v r ba se)
    (caadar					i v r ba se)
    (caaddr					i v r ba se)
    (cadaar					i v r ba se)
    (cadadr					i v r ba se)
    (caddar					i v r ba se)
    (cadddr					i v r ba se)
    (cdaaar					i v r ba se)
    (cdaadr					i v r ba se)
    (cdadar					i v r ba se)
    (cdaddr					i v r ba se)
    (cddaar					i v r ba se)
    (cddadr					i v r ba se)
    (cdddar					i v r ba se)
    (cddddr					i v r ba se)
    (call-with-current-continuation		i v r ba se)
    (call/cc					i v r ba)
    (call-with-values				i v r ba se)
    (ceiling					i v r ba se)
    (char->integer				i v r ba se)
    (char<=?					i v r ba se)
    (char<?					i v r ba se)
    (char=?					i v r ba se)
    (char>=?					i v r ba se)
    (char>?					i v r ba se)
    (char?					i v r ba se)
    (complex?					i v r ba se)
    (cons					i v r ba se)
    (cos					i v r ba se)
    (denominator				i v r ba se)
    (div					i v r ba)
    (mod					i v r ba)
    (div-and-mod				i v r ba)
    (div0					i v r ba)
    (mod0					i v r ba)
    (div0-and-mod0				i v r ba)
    (dynamic-wind				i v r ba se)
    (eq?					i v r ba se)
    (equal?					i v r ba se)
    (eqv?					i v r ba se)
    (error					i v r ba)
    (warning					i v)
    (die					i v)
    (even?					i v r ba se)
    (exact					i v r ba)
    (exact-integer-sqrt				i v r ba)
    (exact?					i v r ba se)
    (exp					i v r ba se)
    (expt					i v r ba se)
    (finite?					i v r ba)
    (floor					i v r ba se)
    (for-each					i v r ba se)
    (gcd					i v r ba se)
    (imag-part					i v r ba se)
    (inexact					i v r ba)
    (inexact?					i v r ba se)
    (infinite?					i v r ba)
    (integer->char				i v r ba se)
    (integer-valued?				i v r ba)
    (integer?					i v r ba se)
    (lcm					i v r ba se)
    (length					i v r ba se)
    (list					i v r ba se)
    (list->string				i v r ba se)
    (list->vector				i v r ba se)
    (list-ref					i v r ba se)
    (list-tail					i v r ba se)
    (list?					i v r ba se)
    (log					i v r ba se)
    (magnitude					i v r ba se)
    (make-polar					i v r ba se)
    (make-rectangular				i v r ba se)
    ($make-rectangular				$comp)
    (make-string				i v r ba se)
    (make-vector				i v r ba se)
    (map					i v r ba se)
    (max					i v r ba se)
    (min					i v r ba se)
    (nan?					i v r ba)
    (negative?					i v r ba se)
    (not					i v r ba se)
    (null?					i v r ba se)
    (number->string				i v r ba se)
    (number?					i v r ba se)
    (numerator					i v r ba se)
    (odd?					i v r ba se)
    (pair?					i v r ba se)
    (positive?					i v r ba se)
    (procedure?					i v r ba se)
    (rational-valued?				i v r ba)
    (rational?					i v r ba se)
    (rationalize				i v r ba se)
    (real-part					i v r ba se)
    (real-valued?				i v r ba)
    (real?					i v r ba se)
    (reverse					i v r ba se)
    (round					i v r ba se)
    (sin					i v r ba se)
    (sqrt					i v r ba se)
    (string					i v r ba se)
    (string->list				i v r ba se)
    (string->number				i v r ba se)
    (string->symbol				i v symbols r ba se)
    (string-append				i v r ba se)
    (string-copy				i v r ba se)
    (string-for-each				i v r ba)
    (string-length				i v r ba se)
    (string-ref					i v r ba se)
    (string<=?					i v r ba se)
    (string<?					i v r ba se)
    (string=?					i v r ba se)
    (string>=?					i v r ba se)
    (string>?					i v r ba se)
    (string?					i v r ba se)
    (substring					i v r ba se)
    (string->latin1				i v)
    (latin1->string				i v)
    (string->ascii				i v)
    (ascii->string				i v)
    (symbol->string				i v symbols r ba se)
    (symbol=?					i v symbols r ba)
    (symbol?					i v symbols r ba se)
    (tan					i v r ba se)
    (truncate					i v r ba se)
    (values					i v r ba se)
    (vector					i v r ba se)
    (vector->list				i v r ba se)
    (vector-fill!				i v r ba se)
    (vector-for-each				i v r ba)
    (vector-length				i v r ba se)
    (vector-map					i v r ba)
    (vector-for-all				i v)
    (vector-exists				i v)
    (vector-ref					i v r ba se)
    (vector-set!				i v r ba se)
    (subvector					i v)
    (vector-append				i v)
    (vector-copy				i v)
    (vector-copy!				i v)
    (vector?					i v r ba se)
    (zero?					i v r ba se)
    (...					i v ne r ba sc se)
    (=>						i v ne r ba ex se)
    (_						i v ne r ba sc)
    (else					i v ne r ba ex se)
    (bitwise-arithmetic-shift			i v r bw)
    (bitwise-arithmetic-shift-left		i v r bw)
    (bitwise-arithmetic-shift-right		i v r bw)
    (bitwise-not				i v r bw)
    (bitwise-and				i v r bw)
    (bitwise-ior				i v r bw)
    (bitwise-xor				i v r bw)
    (bitwise-bit-count				i v r bw)
    (bitwise-bit-field				i v r bw)
    (bitwise-bit-set?				i v r bw)
    (bitwise-copy-bit				i v r bw)
    (bitwise-copy-bit-field			i v r bw)
    (bitwise-first-bit-set			i v r bw)
    (bitwise-if					i v r bw)
    (bitwise-length				i v r bw)
    (bitwise-reverse-bit-field			i v r bw)
    (bitwise-rotate-bit-field			i v r bw)
    (fixnum?					i v r fx)
    (fixnum-width				i v r fx)
    (least-fixnum				i v r fx)
    (greatest-fixnum				i v r fx)
    (fx*					i v r fx)
    (fx*/carry					i v r fx)
    (fx+					i v r fx)
    (fx+/carry					i v r fx)
    (fx-					i v r fx)
    (fx-/carry					i v r fx)
    (fx<=?					i v r fx)
    (fx<?					i v r fx)
    (fx=?					i v r fx)
    (fx>=?					i v r fx)
    (fx>?					i v r fx)
    (fxand					i v r fx)
    (fxarithmetic-shift				i v r fx)
    (fxarithmetic-shift-left			i v r fx)
    (fxarithmetic-shift-right			i v r fx)
    (fxbit-count				i v r fx)
    (fxbit-field				i v r fx)
    (fxbit-set?					i v r fx)
    (fxcopy-bit					i v r fx)
    (fxcopy-bit-field				i v r fx)
    (fxdiv					i v r fx)
    (fxdiv-and-mod				i v r fx)
    (fxdiv0					i v r fx)
    (fxdiv0-and-mod0				i v r fx)
    (fxeven?					i v r fx)
    (fxfirst-bit-set				i v r fx)
    (fxif					i v r fx)
    (fxior					i v r fx)
    (fxlength					i v r fx)
    (fxmax					i v r fx)
    (fxmin					i v r fx)
    (fxmod					i v r fx)
    (fxmod0					i v r fx)
    (fxnegative?				i v r fx)
    (fxnot					i v r fx)
    (fxodd?					i v r fx)
    (fxpositive?				i v r fx)
    (fxreverse-bit-field			i v r fx)
    (fxrotate-bit-field				i v r fx)
    (fxxor					i v r fx)
    (fxzero?					i v r fx)
    (fixnum->flonum				i v r fl)
    (fl*					i v r fl)
    (fl+					i v r fl)
    (fl-					i v r fl)
    (fl/					i v r fl)
    (fl<=?					i v r fl)
    (fl<?					i v r fl)
    (fl=?					i v r fl)
    (fl>=?					i v r fl)
    (fl>?					i v r fl)
    (flabs					i v r fl)
    (flacos					i v r fl)
    (flasin					i v r fl)
    (flatan					i v r fl)
    (flceiling					i v r fl)
    (flcos					i v r fl)
    (fldenominator				i v r fl)
    (fldiv					i v r fl)
    (fldiv-and-mod				i v r fl)
    (fldiv0					i v r fl)
    (fldiv0-and-mod0				i v r fl)
    (fleven?					i v r fl)
    (flexp					i v r fl)
    (flexpm1					i v)
    (flexpt					i v r fl)
    (flfinite?					i v r fl)
    (flfloor					i v r fl)
    (flinfinite?				i v r fl)
    (flinteger?					i v r fl)
    (fllog					i v r fl)
    (fllog1p					i v)
    (flmax					i v r fl)
    (flmin					i v r fl)
    (flmod					i v r fl)
    (flmod0					i v r fl)
    (flnan?					i v r fl)
    (flnegative?				i v r fl)
    (flnumerator				i v r fl)
    (flodd?					i v r fl)
    (flonum?					i v r fl)
    (flpositive?				i v r fl)
    (flround					i v r fl)
    (flsin					i v r fl)
    (flsqrt					i v r fl)
    (fltan					i v r fl)
    (fltruncate					i v r fl)
    (flzero?					i v r fl)
    (real->flonum				i v r fl)
    (make-no-infinities-violation		i v r fl)
    (make-no-nans-violation			i v r fl)
    (&no-infinities				i v r fl)
    (no-infinities-violation?			i v r fl)
    (&no-nans					i v r fl)
    (no-nans-violation?				i v r fl)
    (bytevector->sint-list			i v r bv)
    (bytevector->u8-list			i v r bv)
    (bytevector->s8-list			i v)
    (bytevector->u16l-list			i v)
    (bytevector->u16b-list			i v)
    (bytevector->u16n-list			i v)
    (bytevector->s16l-list			i v)
    (bytevector->s16b-list			i v)
    (bytevector->s16n-list			i v)
    (bytevector->u32l-list			i v)
    (bytevector->u32b-list			i v)
    (bytevector->u32n-list			i v)
    (bytevector->s32l-list			i v)
    (bytevector->s32b-list			i v)
    (bytevector->s32n-list			i v)
    (bytevector->u64l-list			i v)
    (bytevector->u64b-list			i v)
    (bytevector->u64n-list			i v)
    (bytevector->s64l-list			i v)
    (bytevector->s64b-list			i v)
    (bytevector->s64n-list			i v)
    (bytevector->uint-list			i v r bv)
    (bytevector->f4l-list			i v)
    (bytevector->f4b-list			i v)
    (bytevector->f4n-list			i v)
    (bytevector->f8l-list			i v)
    (bytevector->f8b-list			i v)
    (bytevector->f8n-list			i v)
    (bytevector->c4l-list			i v)
    (bytevector->c4b-list			i v)
    (bytevector->c4n-list			i v)
    (bytevector->c8l-list			i v)
    (bytevector->c8b-list			i v)
    (bytevector->c8n-list			i v)
    (bytevector-copy				i v r bv)
    (string-copy!				i v)
    (bytevector-copy!				i v r bv)
    (bytevector-fill!				i v r bv)
    (bytevector-ieee-double-native-ref		i v r bv)
    (bytevector-ieee-double-native-set!		i v r bv)
    (bytevector-ieee-double-ref			i v r bv)
    (bytevector-ieee-double-set!		i v r bv)
    (bytevector-ieee-single-native-ref		i v r bv)
    (bytevector-ieee-single-native-set!		i v r bv)
    (bytevector-ieee-single-ref			i v r bv)
    (bytevector-ieee-single-set!		i v r bv)
    (bytevector-length				i v r bv)
    (bytevector-s16-native-ref			i v r bv)
    (bytevector-s16-native-set!			i v r bv)
    (bytevector-s16-ref				i v r bv)
    (bytevector-s16-set!			i v r bv)
    (bytevector-s32-native-ref			i v r bv)
    (bytevector-s32-native-set!			i v r bv)
    (bytevector-s32-ref				i v r bv)
    (bytevector-s32-set!			i v r bv)
    (bytevector-s64-native-ref			i v r bv)
    (bytevector-s64-native-set!			i v r bv)
    (bytevector-s64-ref				i v r bv)
    (bytevector-s64-set!			i v r bv)
    (bytevector-s8-ref				i v r bv)
    (bytevector-s8-set!				i v r bv)
    (bytevector-sint-ref			i v r bv)
    (bytevector-sint-set!			i v r bv)
    (bytevector-u16-native-ref			i v r bv)
    (bytevector-u16-native-set!			i v r bv)
    (bytevector-u16-ref				i v r bv)
    (bytevector-u16-set!			i v r bv)
    (bytevector-u32-native-ref			i v r bv)
    (bytevector-u32-native-set!			i v r bv)
    (bytevector-u32-ref				i v r bv)
    (bytevector-u32-set!			i v r bv)
    (bytevector-u64-native-ref			i v r bv)
    (bytevector-u64-native-set!			i v r bv)
    (bytevector-u64-ref				i v r bv)
    (bytevector-u64-set!			i v r bv)
    (bytevector-u8-ref				i v r bv)
    (bytevector-u8-set!				i v r bv)
    (bytevector-uint-ref			i v r bv)
    (bytevector-uint-set!			i v r bv)
    (f4l-list->bytevector			i v)
    (f4b-list->bytevector			i v)
    (f4n-list->bytevector			i v)
    (f8l-list->bytevector			i v)
    (f8b-list->bytevector			i v)
    (f8n-list->bytevector			i v)
    (c4l-list->bytevector			i v)
    (c4b-list->bytevector			i v)
    (c4n-list->bytevector			i v)
    (c8l-list->bytevector			i v)
    (c8b-list->bytevector			i v)
    (c8n-list->bytevector			i v)
    (bytevector=?				i v r bv)
    (bytevector?				i v r bv)
    (subbytevector-u8				i v)
    (subbytevector-u8/count			i v)
    (subbytevector-s8				i v)
    (subbytevector-s8/count			i v)
    (bytevector-append				i v)
    (endianness					i v r bv)
    (native-endianness				i v r bv)
    (sint-list->bytevector			i v r bv)
    (string->utf16				i v r bv)
    (string->utf32				i v r bv)
    (string->utf8				i v r bv)
    (string->utf16le				i v)
    (string->utf16be				i v)
    (string->utf16n				i v)
    (u8-list->bytevector			i v r bv)
    (s8-list->bytevector			i v)
    (u16l-list->bytevector			i v)
    (u16b-list->bytevector			i v)
    (u16n-list->bytevector			i v)
    (s16l-list->bytevector			i v)
    (s16b-list->bytevector			i v)
    (s16n-list->bytevector			i v)
    (u32l-list->bytevector			i v)
    (u32b-list->bytevector			i v)
    (u32n-list->bytevector			i v)
    (s32l-list->bytevector			i v)
    (s32b-list->bytevector			i v)
    (s32n-list->bytevector			i v)
    (u64l-list->bytevector			i v)
    (u64b-list->bytevector			i v)
    (u64n-list->bytevector			i v)
    (s64l-list->bytevector			i v)
    (s64b-list->bytevector			i v)
    (s64n-list->bytevector			i v)
    (uint-list->bytevector			i v r bv)
    (utf8->string				i v r bv)
    (utf16->string				i v r bv)
    (utf16le->string				i v)
    (utf16n->string				i v)
    (utf16be->string				i v)
    (utf32->string				i v r bv)
    (print-condition				i v)
    (condition?					i v r co)
    (&assertion					i v r co)
    (assertion-violation?			i v r co)
    (&condition					i v r co)
    (condition					i v r co)
    (condition-accessor				i v r co)
    (condition-irritants			i v r co)
    (condition-message				i v r co)
    (condition-predicate			i v r co)
    (condition-who				i v r co)
    (define-condition-type			i v r co)
    (&error					i v r co)
    (error?					i v r co)
    (&implementation-restriction		i v r co)
    (implementation-restriction-violation?	i v r co)
    (&irritants					i v r co)
    (irritants-condition?			i v r co)
    (&lexical					i v r co)
    (lexical-violation?				i v r co)
    (make-assertion-violation			i v r co)
    (make-error					i v r co)
    (make-implementation-restriction-violation	i v r co)
    (make-irritants-condition			i v r co)
    (make-lexical-violation			i v r co)
    (make-message-condition			i v r co)
    (make-non-continuable-violation		i v r co)
    (make-serious-condition			i v r co)
    (make-syntax-violation			i v r co)
    (make-undefined-violation			i v r co)
    (make-violation				i v r co)
    (make-warning				i v r co)
    (make-who-condition				i v r co)
    (&message					i v r co)
    (message-condition?				i v r co)
    (&non-continuable				i v r co)
    (non-continuable-violation?			i v r co)
    (&serious					i v r co)
    (serious-condition?				i v r co)
    (simple-conditions				i v r co)
    (&syntax					i v r co)
    (syntax-violation-form			i v r co)
    (syntax-violation-subform			i v r co)
    (syntax-violation?				i v r co)
    (&undefined					i v r co)
    (undefined-violation?			i v r co)
    (&violation					i v r co)
    (violation?					i v r co)
    (&warning					i v r co)
    (warning?					i v r co)
    (&who					i v r co)
    (who-condition?				i v r co)
    (case-lambda				i v r ct)
    (do						i v r ct se ne)
    (unless					i v r ct)
    (when					i v r ct)
    (define-enumeration				i v r en)
    (enum-set->list				i v r en)
    (enum-set-complement			i v r en)
    (enum-set-constructor			i v r en)
    (enum-set-difference			i v r en)
    (enum-set-indexer				i v r en)
    (enum-set-intersection			i v r en)
    (enum-set-member?				i v r en)
    (enum-set-projection			i v r en)
    (enum-set-subset?				i v r en)
    (enum-set-union				i v r en)
    (enum-set-universe				i v r en)
    (enum-set=?					i v r en)
    (make-enumeration				i v r en)
    (enum-set?					i v)
    (environment				i v ev)
    (eval					i v ev se)
    (raise					i v r ex)
    (raise-continuable				i v r ex)
    (with-exception-handler			i v r ex)
    (guard					i v r ex)
    (binary-port?				i v r ip)
    (buffer-mode				i v r ip)
    (buffer-mode?				i v r ip)
    (bytevector->string				i v r ip)
    (call-with-bytevector-output-port		i v r ip)
    (call-with-port				i v r ip)
    (call-with-string-output-port		i v r ip)
    (assoc					i v r ls se)
    (assp					i v r ls)
    (assq					i v r ls se)
    (assv					i v r ls se)
    (cons*					i v r ls)
    (filter					i v r ls)
    (find					i v r ls)
    (fold-left					i v r ls)
    (fold-right					i v r ls)
    (for-all					i v r ls)
    (exists					i v r ls)
    (member					i v r ls se)
    (memp					i v r ls)
    (memq					i v r ls se)
    (memv					i v r ls se)
    (partition					i v r ls)
    (remq					i v r ls)
    (remp					i v r ls)
    (remv					i v r ls)
    (remove					i v r ls)
    (set-car!					i v mp se)
    (set-cdr!					i v mp se)
    (string-set!				i v ms se)
    (string-fill!				i v ms se)
    (command-line				i v r pr)
    (exit					i v r pr)
    (delay					i v r5 se ne)
    (exact->inexact				i v r5 se)
    (force					i v r5 se)
    (inexact->exact				i v r5 se)
    (modulo					i v r5 se)
    (remainder					i v r5 se)
    (null-environment				i v r5 se)
    (quotient					i v r5 se)
    (scheme-report-environment			i v r5 se)
    (interaction-environment			i v)
    (new-interaction-environment		i v)
    (close-port					i v r ip)
    (eol-style					i v r ip)
    (error-handling-mode			i v r ip)
    (file-options				i v r ip)
    (flush-output-port				i v r ip)
    (get-bytevector-all				i v r ip)
    (get-bytevector-n				i v r ip)
    (get-bytevector-n!				i v r ip)
    (get-bytevector-some			i v r ip)
    (get-char					i v r ip)
    (get-datum					i v r ip)
    (get-line					i v r ip)
    (read-line					i v)
    (get-string-all				i v r ip)
    (get-string-n				i v r ip)
    (get-string-n!				i v r ip)
    (get-u8					i v r ip)
    (&i/o					i v r ip is fi)
    (&i/o-decoding				i v r ip)
    (i/o-decoding-error?			i v r ip)
    (&i/o-encoding				i v r ip)
    (i/o-encoding-error-char			i v r ip)
    (i/o-encoding-error?			i v r ip)
    (i/o-error-filename				i v r ip is fi)
    (i/o-error-port				i v r ip is fi)
    (i/o-error-position				i v r ip is fi)
    (i/o-error?					i v r ip is fi)
    (&i/o-file-already-exists			i v r ip is fi)
    (i/o-file-already-exists-error?		i v r ip is fi)
    (&i/o-file-does-not-exist			i v r ip is fi)
    (i/o-file-does-not-exist-error?		i v r ip is fi)
    (&i/o-file-is-read-only			i v r ip is fi)
    (i/o-file-is-read-only-error?		i v r ip is fi)
    (&i/o-file-protection			i v r ip is fi)
    (i/o-file-protection-error?			i v r ip is fi)
    (&i/o-filename				i v r ip is fi)
    (i/o-filename-error?			i v r ip is fi)
    (&i/o-invalid-position			i v r ip is fi)
    (i/o-invalid-position-error?		i v r ip is fi)
    (&i/o-port					i v r ip is fi)
    (i/o-port-error?				i v r ip is fi)
    (&i/o-read					i v r ip is fi)
    (i/o-read-error?				i v r ip is fi)
    (&i/o-write					i v r ip is fi)
    (i/o-write-error?				i v r ip is fi)
    (&i/o-eagain				i v)
    (i/o-eagain-error?				i v)
    (&errno					i v)
    (errno-condition?				i v)
    (&h_errno					i v)
    (h_errno-condition?				i v)
    (lookahead-char				i v r ip)
    (lookahead-u8				i v r ip)
    (lookahead-two-u8				i v)
    (make-bytevector				i v r bv)
    (make-custom-binary-input-port		i v r ip)
    (make-custom-binary-output-port		i v r ip)
    (make-custom-textual-input-port		i v r ip)
    (make-custom-textual-output-port		i v r ip)
    (make-custom-binary-input/output-port	i v r ip)
    (make-custom-textual-input/output-port	i v r ip)
    (make-binary-file-descriptor-input-port	i v)
    (make-binary-file-descriptor-input-port*	i v)
    (make-binary-file-descriptor-output-port	i v)
    (make-binary-file-descriptor-output-port*	i v)
    (make-binary-file-descriptor-input/output-port	i v)
    (make-binary-file-descriptor-input/output-port*	i v)
    (make-binary-socket-input/output-port	i v)
    (make-binary-socket-input/output-port*	i v)
    (make-textual-file-descriptor-input-port	i v)
    (make-textual-file-descriptor-input-port*	i v)
    (make-textual-file-descriptor-output-port	i v)
    (make-textual-file-descriptor-output-port*	i v)
    (make-textual-file-descriptor-input/output-port	i v)
    (make-textual-file-descriptor-input/output-port*	i v)
    (make-textual-socket-input/output-port	i v)
    (make-textual-socket-input/output-port*	i v)
    (make-i/o-decoding-error			i v r ip)
    (make-i/o-encoding-error			i v r ip)
    (make-i/o-error				i v r ip is fi)
    (make-i/o-file-already-exists-error		i v r ip is fi)
    (make-i/o-file-does-not-exist-error		i v r ip is fi)
    (make-i/o-file-is-read-only-error		i v r ip is fi)
    (make-i/o-file-protection-error		i v r ip is fi)
    (make-i/o-filename-error			i v r ip is fi)
    (make-i/o-invalid-position-error		i v r ip is fi)
    (make-i/o-port-error			i v r ip is fi)
    (make-i/o-read-error			i v r ip is fi)
    (make-i/o-write-error			i v r ip is fi)
    (make-i/o-eagain				i v)
    (make-errno-condition			i v)
    (condition-errno				i v)
    (make-h_errno-condition			i v)
    (condition-h_errno				i v)
    (latin-1-codec				i v r ip)
    (make-transcoder				i v r ip)
    (native-eol-style				i v r ip)
    (native-transcoder				i v r ip)
    (transcoder?				i v)
    (open-bytevector-input-port			i v r ip)
    (open-bytevector-output-port		i v r ip)
    (open-file-input-port			i v r ip)
    (open-file-input/output-port		i v r ip)
    (open-file-output-port			i v r ip)
    (open-string-input-port			i v r ip)
    (open-string-output-port			i v r ip)
    (bytevector-port-buffer-size		i v)
    (string-port-buffer-size			i v)
    (input-file-buffer-size			i v)
    (output-file-buffer-size			i v)
    (input/output-file-buffer-size		i v)
    (input/output-socket-buffer-size		i v)
    (output-port-buffer-mode			i v r ip)
    (set-port-buffer-mode!			i v)
    (port-eof?					i v r ip)
    (port-has-port-position?			i v r ip)
    (port-has-set-port-position!?		i v r ip)
    (port-position				i v r ip)
    (get-char-and-track-textual-position	i v)
    (port-textual-position			i v)
    (port-transcoder				i v r ip)
    (port?					i v r ip)
    (put-bytevector				i v r ip)
    (put-char					i v r ip)
    (put-datum					i v r ip)
    (put-string					i v r ip)
    (put-u8					i v r ip)
    (set-port-position!				i v r ip)
    (standard-error-port			i v r ip)
    (standard-input-port			i v r ip)
    (standard-output-port			i v r ip)
    (string->bytevector				i v r ip)
    (textual-port?				i v r ip)
    (transcoded-port				i v r ip)
    (transcoder-codec				i v r ip)
    (transcoder-eol-style			i v r ip)
    (transcoder-error-handling-mode		i v r ip)
    (utf-8-codec				i v r ip)
    (utf-16-codec				i v r ip)
    (utf-16le-codec				i v)
    (utf-16be-codec				i v)
    (utf-16n-codec				i v)
    (utf-bom-codec				i v)
    (input-port?				i v r is ip se)
    (output-port?				i v r is ip se)
    (current-input-port				i v r ip is se)
    (current-output-port			i v r ip is se)
    (current-error-port				i v r ip is)
    (eof-object					i v r ip is)
    (eof-object?				i v r ip is se)
    (close-input-port				i v r is se)
    (close-output-port				i v r is se)
    (display					i v r is se)
    (newline					i v r is se)
    (open-input-file				i v r is se)
    (open-output-file				i v r is se)
    (peek-char					i v r is se)
    (read					i v r is se)
    (read-char					i v r is se)
    (with-input-from-file			i v r is se)
    (with-output-to-file			i v r is se)
    (with-output-to-port			i v)
    (write					i v r is se)
    (write-char					i v r is se)
    (call-with-input-file			i v r is se)
    (call-with-output-file			i v r is se)
    (hashtable-clear!				i v r ht)
    (hashtable-contains?			i v r ht)
    (hashtable-copy				i v r ht)
    (hashtable-delete!				i v r ht)
    (hashtable-entries				i v r ht)
    (hashtable-keys				i v r ht)
    (hashtable-mutable?				i v r ht)
    (hashtable-ref				i v r ht)
    (hashtable-set!				i v r ht)
    (hashtable-size				i v r ht)
    (hashtable-update!				i v r ht)
    (hashtable?					i v r ht)
    (make-eq-hashtable				i v r ht)
    (make-eqv-hashtable				i v r ht)
    (hashtable-hash-function			i v r ht)
    (make-hashtable				i v r ht)
    (hashtable-equivalence-function		i v r ht)
    (equal-hash					i v r ht)
    (string-hash				i v r ht)
    (string-ci-hash				i v r ht)
    (symbol-hash				i v r ht)
    (list-sort					i v r sr)
    (vector-sort				i v r sr)
    (vector-sort!				i v r sr)
    (file-exists?				i v r fi)
    (delete-file				i v r fi)
    (define-record-type				i v r rs)
    (fields					i v r rs)
    (immutable					i v r rs)
    (mutable					i v r rs)
    (opaque					i v r rs)
    (parent					i v r rs)
    (parent-rtd					i v r rs)
    (protocol					i v r rs)
    (record-constructor-descriptor		i v r rs)
    (record-type-descriptor			i v r rs)
    (sealed					i v r rs)
    (nongenerative				i v r rs)
    (record-field-mutable?			i v r ri)
    (record-rtd					i v r ri)
    (record-type-field-names			i v r ri)
    (record-type-generative?			i v r ri)
    (record-type-name				i v r ri)
    (record-type-opaque?			i v r ri)
    (record-type-parent				i v r ri)
    (record-type-sealed?			i v r ri)
    (record-type-uid				i v r ri)
    (record?					i v r ri)
    (make-record-constructor-descriptor		i v r rp)
    (make-record-type-descriptor		i v r rp)
    (record-accessor				i v r rp)
    (record-constructor				i v r rp)
    (record-mutator				i v r rp)
    (record-predicate				i v r rp)
    (record-type-descriptor?			i v r rp)
    (syntax-violation				i v r sc)
    (bound-identifier=?				i v r sc)
    (datum->syntax				i v r sc)
    (syntax					i v r sc)
    (syntax->datum				i v r sc)
    (syntax-case				i v r sc)
    (unsyntax					i v r sc)
    (unsyntax-splicing				i v r sc)
    (quasisyntax				i v r sc)
    (with-syntax				i v r sc)
    (free-identifier=?				i v r sc)
    (generate-temporaries			i v r sc)
    (identifier?				i v r sc)
    (make-variable-transformer			i v r sc)
    (variable-transformer?			i v)
    (variable-transformer-procedure		i v)
    (make-compile-time-value			i v)
    (syntax-transpose				i v)
    (char-alphabetic?				i v r uc se)
    (char-ci<=?					i v r uc se)
    (char-ci<?					i v r uc se)
    (char-ci=?					i v r uc se)
    (char-ci>=?					i v r uc se)
    (char-ci>?					i v r uc se)
    (char-downcase				i v r uc se)
    (char-foldcase				i v r uc)
    (char-titlecase				i v r uc)
    (char-upcase				i v r uc se)
    (char-general-category			i v r uc)
    (char-lower-case?				i v r uc se)
    (char-numeric?				i v r uc se)
    (char-title-case?				i v r uc)
    (char-upper-case?				i v r uc se)
    (char-whitespace?				i v r uc se)
    (string-ci<=?				i v r uc se)
    (string-ci<?				i v r uc se)
    (string-ci=?				i v r uc se)
    (string-ci>=?				i v r uc se)
    (string-ci>?				i v r uc se)
    (string-downcase				i v r uc)
    (string-foldcase				i v r uc)
    (string-normalize-nfc			i v r uc)
    (string-normalize-nfd			i v r uc)
    (string-normalize-nfkc			i v r uc)
    (string-normalize-nfkd			i v r uc)
    (string-titlecase				i v r uc)
    (string-upcase				i v r uc)
    (load					i v)
    (load-r6rs-script				i v)
    (void					i v $boot)
    (gensym					i v symbols $boot)
    (symbol-value				i v symbols $boot)
    (system-value				i v)
    (set-symbol-value!				i v symbols $boot)
    (eval-core					$boot)
    (current-core-eval				i v) ;;; temp
    (pretty-print				i v $boot)
    (pretty-format				i v)
    (pretty-width				i v)
    (module					i v cm)
    (library					i v)
    (syntax-dispatch				)
    (syntax-error				i v)
    ($transcoder->data				$transc)
    ($data->transcoder				$transc)
    (make-file-options				i v)
;;;
    (port-id					i v)
    (port-fd					i v)
    (string->filename-func			i v)
    (filename->string-func			i v)
    (port-dump-status				i v)
    (port-closed?				i v)
;;; (ikarus system $io)
    ($make-port					$io)
    ($port-tag					$io)
    ($port-id					$io)
    ($port-cookie				$io)
    ($port-transcoder				$io)
    ($port-index				$io)
    ($port-size					$io)
    ($port-buffer				$io)
    ($port-get-position				$io)
    ($port-set-position!			$io)
    ($port-close				$io)
    ($port-read!				$io)
    ($port-write!				$io)
    ($set-port-index!				$io)
    ($set-port-size!				$io)
    ($port-attrs				$io)
    ($set-port-attrs!				$io)
;;;
    (get-annotated-datum			i v)
    (annotation?				i v)
    (annotation-expression			i v)
    (annotation-source				i v)
    (annotation-stripped			i v)
;;;
    (&condition-rtd)
    (&condition-rcd)
    (&message-rtd)
    (&message-rcd)
    (&warning-rtd)
    (&warning-rcd)
    (&serious-rtd)
    (&serious-rcd)
    (&error-rtd)
    (&error-rcd)
    (&violation-rtd)
    (&violation-rcd)
    (&assertion-rtd)
    (&assertion-rcd)
    (&irritants-rtd)
    (&irritants-rcd)
    (&who-rtd)
    (&who-rcd)
    (&non-continuable-rtd)
    (&non-continuable-rcd)
    (&implementation-restriction-rtd)
    (&implementation-restriction-rcd)
    (&lexical-rtd)
    (&lexical-rcd)
    (&syntax-rtd)
    (&syntax-rcd)
    (&undefined-rtd)
    (&undefined-rcd)
    (&i/o-rtd)
    (&i/o-rcd)
    (&i/o-read-rtd)
    (&i/o-read-rcd)
    (&i/o-write-rtd)
    (&i/o-write-rcd)
    (&i/o-invalid-position-rtd)
    (&i/o-invalid-position-rcd)
    (&i/o-filename-rtd)
    (&i/o-filename-rcd)
    (&i/o-file-protection-rtd)
    (&i/o-file-protection-rcd)
    (&i/o-file-is-read-only-rtd)
    (&i/o-file-is-read-only-rcd)
    (&i/o-file-already-exists-rtd)
    (&i/o-file-already-exists-rcd)
    (&i/o-file-does-not-exist-rtd)
    (&i/o-file-does-not-exist-rcd)
    (&i/o-port-rtd)
    (&i/o-port-rcd)
    (&i/o-decoding-rtd)
    (&i/o-decoding-rcd)
    (&i/o-encoding-rtd)
    (&i/o-encoding-rcd)
    (&no-infinities-rtd)
    (&no-infinities-rcd)
    (&no-nans-rtd)
    (&no-nans-rcd)
    (&interrupted-rtd)
    (&interrupted-rcd)
    (&source-rtd)
    (&source-rcd)

;;; --------------------------------------------------------------------
;;; POSIX functions

    (strerror					i v)
    (errno->string				posix)
    (getenv					i v posix)
    (mkdir					posix)
    (mkdir/parents				posix)
    (real-pathname				posix)
    (file-modification-time			posix)
    (split-file-name				posix)

;;; --------------------------------------------------------------------
;;; (ikarus system $foreign)
    (errno					$for i v)
    (pointer?					$for i v)
    (null-pointer				$for i v)
    (pointer->integer				$for i v)
    (integer->pointer				$for i v)
    (pointer-null?				$for i v)
    (pointer-diff				$for i v)
    (pointer-add				$for i v)
    (pointer=?					$for i v)
    (pointer<>?					$for i v)
    (pointer<?					$for i v)
    (pointer>?					$for i v)
    (pointer<=?					$for i v)
    (pointer>=?					$for i v)
    (set-pointer-null!				$for i v)
;;;
    (make-out-of-memory-error			$for i v)
    (out-of-memory-error?			$for i v)
    (out-of-memory-error.old-pointer		$for i v)
    (out-of-memory-error.number-of-bytes	$for i v)
    (out-of-memory-error.clean?			$for i v)
    (malloc					$for i v)
    (realloc					$for i v)
    (calloc					$for i v)
    (guarded-malloc				$for i v)
    (guarded-realloc				$for i v)
    (guarded-calloc				$for i v)
    (malloc*					$for i v)
    (realloc*					$for i v)
    (calloc*					$for i v)
    (guarded-malloc*				$for i v)
    (guarded-realloc*				$for i v)
    (guarded-calloc*				$for i v)
    (free					$for i v)
    (memcpy					$for i v)
    (memcmp					$for i v)
    (memmove					$for i v)
    (memset					$for i v)
    (memory-copy				$for i v)
    (memory->bytevector				$for i v)
    (bytevector->memory				$for i v)
    (bytevector->guarded-memory			$for i v)
;;;
    (with-local-storage				$for i v)
;;;
    (bytevector->cstring			$for i v)
    (bytevector->guarded-cstring		$for i v)
    (cstring->bytevector			$for i v)
    (string->cstring				$for i v)
    (string->guarded-cstring			$for i v)
    (cstring->string				$for i v)
    (strlen					$for i v)
    (strcmp					$for i v)
    (strncmp					$for i v)
    (strdup					$for i v)
    (strndup					$for i v)
    (guarded-strdup				$for i v)
    (guarded-strndup				$for i v)
    (bytevectors->argv				$for i v)
    (bytevectors->guarded-argv			$for i v)
    (argv->bytevectors				$for i v)
    (strings->argv				$for i v)
    (strings->guarded-argv			$for i v)
    (argv->strings				$for i v)
    (argv-length				$for i v)
;;;
    (pointer-ref-c-uint8			$for i v)
    (pointer-ref-c-sint8			$for i v)
    (pointer-ref-c-uint16			$for i v)
    (pointer-ref-c-sint16			$for i v)
    (pointer-ref-c-uint32			$for i v)
    (pointer-ref-c-sint32			$for i v)
    (pointer-ref-c-uint64			$for i v)
    (pointer-ref-c-sint64			$for i v)
;;;
    (pointer-ref-c-signed-char			$for i v)
    (pointer-ref-c-signed-short			$for i v)
    (pointer-ref-c-signed-int			$for i v)
    (pointer-ref-c-signed-long			$for i v)
    (pointer-ref-c-signed-long-long		$for i v)
    (pointer-ref-c-unsigned-char		$for i v)
    (pointer-ref-c-unsigned-short		$for i v)
    (pointer-ref-c-unsigned-int			$for i v)
    (pointer-ref-c-unsigned-long		$for i v)
    (pointer-ref-c-unsigned-long-long		$for i v)
;;;
    (pointer-ref-c-float			$for i v)
    (pointer-ref-c-double			$for i v)
    (pointer-ref-c-pointer			$for i v)
;;;
    (pointer-set-c-uint8!			$for i v)
    (pointer-set-c-sint8!			$for i v)
    (pointer-set-c-uint16!			$for i v)
    (pointer-set-c-sint16!			$for i v)
    (pointer-set-c-uint32!			$for i v)
    (pointer-set-c-sint32!			$for i v)
    (pointer-set-c-uint64!			$for i v)
    (pointer-set-c-sint64!			$for i v)
;;;
    (pointer-set-c-signed-char!			$for i v)
    (pointer-set-c-signed-short!		$for i v)
    (pointer-set-c-signed-int!			$for i v)
    (pointer-set-c-signed-long!			$for i v)
    (pointer-set-c-signed-long-long!		$for i v)
    (pointer-set-c-unsigned-char!		$for i v)
    (pointer-set-c-unsigned-short!		$for i v)
    (pointer-set-c-unsigned-int!		$for i v)
    (pointer-set-c-unsigned-long!		$for i v)
    (pointer-set-c-unsigned-long-long!		$for i v)
;;;
    (pointer-set-c-float!			$for i v)
    (pointer-set-c-double!			$for i v)
    (pointer-set-c-pointer!			$for i v)
;;;
    (dlopen					$for)
    (dlerror					$for)
    (dlclose					$for)
    (dlsym					$for)
;;;
    (make-c-callout-maker			$for)
    (make-c-callout-maker/with-errno		$for)
    (make-c-callback-maker			$for)
    (free-c-callback				$for)

;;; --------------------------------------------------------------------
;;;
    (ellipsis-map)
    (optimize-cp				i v)
    (optimize-level				i v)
    (cp0-size-limit				i v)
    (cp0-effort-limit				i v)
    (tag-analysis-output			i v)
    (perform-tag-analysis			i v)
    (current-letrec-pass			i v)
    (host-info					i v)
    (debug-call)))


(define bootstrap-collection
  ;;A collection of LIBRARY  structures accessed through a closure.  The
  ;;LIBRARY structure type is defined in the psyntax modules.
  ;;
  ;;This  function works  somewhat like  a parameter  function; it  is a
  ;;closure   with  the  same   interface  of   the  ones   returned  by
  ;;MAKE-COLLECTION,  but it  has an  initial  value and  it checks  for
  ;;duplicates to avoid them.
  ;;
  ;;If the  function is called with  no arguments: it  returns the whole
  ;;collection, which is a list  of LIBRARY structures.  If the function
  ;;is  called  with one  argument:  such  argument  must be  a  LIBRARY
  ;;structure and it is added to the collection if not already there.
  ;;
  ;;The initial  value is a list  of LIBRARY structures  built by adding
  ;;all the  libraries in LIBRARY-LEGEND which are  marked as REQUIRED?.
  ;;Notice that such structures are built by FIND-LIBRARY-BY-NAME, which
  ;;means  that  the  libraries  marked  as REQUIRED?  must  be  already
  ;;installed in the boot image running this program.
  ;;
  ;;To add a REQUIRED? library to a  boot image: first we have to add an
  ;;entry to  LIBRARY-LEGEND marked as  VISIBLE?  and build  a temporary
  ;;boot image, then mark the entry as REQUIRED? and using the temporary
  ;;boot image build another boot  image which will have the new library
  ;;as REQUIRED?.
  ;;
  (let ((list-of-library-records
	 (let next-library-entry ((entries library-legend))
	   (define required?	cadddr)
	   (define library-name	cadr)
	   (cond ((null? entries)
		  '())
		 ((required? (car entries))
		  (cons (find-library-by-name (library-name (car entries)))
			(next-library-entry (cdr entries))))
		 (else
		  (next-library-entry (cdr entries)))))))
    (case-lambda
     (()
      list-of-library-records)
     ((x)
      (unless (memq x list-of-library-records)
	(set! list-of-library-records (cons x list-of-library-records)))))))


(define (make-system-data subst env)
  ;;SUBST  is  an  alist  representing  the  substitutions  of  all  the
  ;;libraries  in the  boot  image,  ENV is  an  alist representing  the
  ;;environment of all the libraries in the boot image.
  ;;
  (define who 'make-system-data)
  (define (macro-identifier? x)
    (and (assq x ikarus-system-macros) #t))
  (define (procedure-identifier? x)
    (not (macro-identifier? x)))
  (define (assq1 x ls)
    (let loop ((x x) (ls ls) (p #f))
      (cond ((null? ls)
	     p)
	    ((eq? x (caar ls))
	     (if p
		 (if (pair? p)
		     (if (eq? (cdr p) (cdar ls))
			 (loop x (cdr ls) p)
		       (loop x (cdr ls) 2))
		   (loop x (cdr ls) (+ p 1)))
	       (loop x (cdr ls) (car ls))))
	    (else
	     (loop x (cdr ls) p)))))

  (let ((export-subst    (make-collection))
        (export-env      (make-collection))
        (export-primlocs (make-collection)))

    (each-for ikarus-system-macros
      (lambda (x)
	(let ((name	(car  x))
	      (binding	(cadr x))
	      (label	(gensym)))
	  (export-subst (cons name label))
	  (export-env   (cons label binding)))))
    (each-for (map car identifier->library-map)
      (lambda (x)
	(when (procedure-identifier? x)
	  (cond ((assq x (export-subst))
		 (error who "ambiguous export" x))
		((assq1 x subst) =>
		 ;;Primitive  defined  (exported)  within  the  compiled
		 ;;libraries.
		 (lambda (p)
		   (unless (pair? p)
		     (error who "invalid exports" p x))
		   (let ((label (cdr p)))
		     (cond ((assq label env) =>
			    (lambda (p)
			      (let ((binding (cdr p)))
				(case (car binding)
				  ((global)
				   (export-subst (cons x label))
				   (export-env   (cons label (cons 'core-prim x)))
				   (export-primlocs (cons x (cdr binding))))
				  (else
				   (error who "invalid binding for identifier" p x))))))
			   (else
			    (error who "cannot find binding" x label))))))
		(else
		 ;;Core primitive with no backing definition, assumed to
		 ;;be defined in other strata of the system
;;;		 (fprintf (console-error-port) "undefined primitive ~s\n" x)
		 (let ((label (gensym)))
		   (export-subst (cons x label))
		   (export-env (cons label (cons 'core-prim x)))))))))

    (values (export-subst) (export-env) (export-primlocs))))


(define (build-system-library export-subst export-env primlocs)
  (define (main export-subst export-env primlocs)
    (let ((code `(library (ikarus primlocs)
		   (export) ;;; must be empty
		   (import (only (ikarus.symbols) system-value-gensym)
		     (only (psyntax library-manager)
			   install-library)
		     (only (ikarus.compiler)
			   current-primitive-locations)
		     (ikarus))
		   (let ((g system-value-gensym))
		     (for-each (lambda (x)
				 (putprop (car x) g (cdr x)))
		       ',primlocs)
		     (let ((proc (lambda (x) (getprop x g))))
		       (current-primitive-locations proc)))
		   ;;This evaluates to a spliced list of INSTALL-LIBRARY
		   ;;forms.
		   ,@(map build-install-library-form library-legend))))
      ;;Expand  the library in  CODE; we  know that  the EXPORT  form is
      ;;empty,  so  we  know  that  the  last  two  values  returned  by
      ;;BOOT-LIBRARY-EXPAND are empty.
      ;;
      (let-values (((name code empty-subst empty-env)
		    (boot-library-expand code)))
	(values name code))))

  (define (build-install-library-form legend-entry)
    (let* ((nickname	(car	legend-entry))
	   (name	(cadr	legend-entry))
	   (visible?	(caddr	legend-entry))
	   (id		(gensym))
	   (version	(if (eq? 'rnrs (car name)) '(6) '()))
	   (system-all?	(equal? name '(psyntax system $all)))
	   (env		(if system-all? export-env '()))
	   (subst	(if system-all?
			    export-subst
			  (get-export-subset nickname export-subst))))
      ;;Datums  embedded in  this  symbolic expression  are quoted  to
      ;;allow the sexp to be handed to EVAL (I guess; Marco Maggi, Aug
      ;;26, 2011).
      `(install-library ',id ',name ',version
			'() ;; import-libs
			'() ;; visit-libs
			'() ;; invoke-libs
			',subst ',env void void '#f '#f '#f '() ',visible? '#f)))

  (define (get-export-subset nickname subst)
    ;;Given  the alist  of  substitutions SUBST,  build  and return  the
    ;;subset  of  substitutions  corresponding  to  identifiers  in  the
    ;;library selected by NICKNAME.
    ;;
    (let loop ((ls subst))
      (if (null? ls)
	  '()
	(let ((x (car ls)))
	  (let ((name (car x)))
	    (cond ((assq name identifier->library-map)
		   => (lambda (q)
			(if (memq nickname (cdr q))
			    (cons x (loop (cdr ls)))
			  (loop (cdr ls)))))
		  (else ;not going to any library?
		   (loop (cdr ls)))))))))

  (main export-subst export-env primlocs))


(define (make-init-code)
  ;;The first  code to  run on  the system is  one that  initializes the
  ;;value  and  proc  fields  of  the  location  of  $init-symbol-value!
  ;;Otherwise,  all  subsequent  inits   to  any  global  variable  will
  ;;segfault.
  ;;
  (let ((proc	(gensym))
	(loc	(gensym))
	(label	(gensym))
	(sym	(gensym))
	(val	(gensym))
	(args	(gensym)))
    (values (list '(ikarus.init))
	    (list `((case-lambda
		     ((,proc) (,proc ',loc ,proc)))
		    (case-lambda
		     ((,sym ,val)
		      (begin
			((primitive $set-symbol-value!) ,sym ,val)
			(if ((primitive procedure?) ,val)
			    ((primitive $set-symbol-proc!) ,sym ,val)
			  ((primitive $set-symbol-proc!) ,sym
			   (case-lambda
			    (,args
			     ((primitive error) 'apply
			      (quote "not a procedure") ((primitive $symbol-value) ,sym)))))))))))
	    `(($init-symbol-value! . ,label))
	    `((,label . (global . ,loc))))))


(define (expand-all files)
  ;;Expand all the  libraries in FILES, which must be  a list of strings
  ;;representing  file  pathnames  under  SRC-DIR.
  ;;
  ;;Return  3  values:  the  list  of  library  specifications,  a  list
  ;;representing  all  the  code  forms  from  all  the  libraries,  the
  ;;EXPORT-LOCS.
  ;;
  ;;Notice that the  last code to be executed is the  one of the (ikarus
  ;;main)  library,  and  the one  before  it  is  the one  returned  by
  ;;BUILD-SYSTEM-LIBRARY.
  ;;
  (define (prune-subst subst env)
    ;;Remove all re-exported identifiers (those with labels in SUBST but
    ;;no binding in ENV).
    ;;
    (cond ((null? subst)
	   '())
	  ((not (assq (cdar subst) env))
	   (prune-subst (cdr subst) env))
	  (else
	   (cons (car subst) (prune-subst (cdr subst) env)))))

  ;;For each library: accumulate all the code in the CODE* variable, all
  ;;the substitutions in SUBST, the whole environment in ENV.
  (let-values (((name* code* subst env) (make-init-code)))
    (debug-printf "Expanding ")
    (for-each (lambda (file)
		(debug-printf " ~s" file)
		;;For each  library in the  file apply the  function for
		;;its side effects.
		(load (string-append src-dir "/" file)
		      (lambda (x)
			(let-values (((name code export-subst export-env)
				      (boot-library-expand x)))
			  (set! name* (cons name name*))
			  (set! code* (cons code code*))
			  (set! subst (append export-subst subst))
			  (set! env   (append export-env   env))))))
      files)
    (debug-printf "\n")
    (let-values (((export-subst export-env export-locs)
                  (make-system-data (prune-subst subst env) env)))
      (let-values (((name code) (build-system-library export-subst export-env export-locs)))
        (values (reverse (cons* (car name*) name (cdr name*)))
		(reverse (cons* (car code*) code (cdr code*)))
		export-locs)))))


;;;; Go!

;;Internal consistency check: verify that all the library nicknames used
;;in IDENTIFIER->LIBRARY-MAP are defined by LIBRARY-LEGEND.
;;
(for-each (lambda (x)
	    (for-each (lambda (x)
			(unless (assq x library-legend)
			  (error 'identifier->library-map "not in the libraries list" x)))
	      (cdr x)))
  identifier->library-map)

;;;(pretty-print/stderr (bootstrap-collection))

;;Perform the bootstrap process generating the boot image.
;;
(time-it "the entire bootstrap process"
  (lambda ()
    (let-values (((name* core* locs)
		  (time-it "macro expansion"
		    (lambda ()
		      (parameterize ((current-library-collection bootstrap-collection))
			(expand-all scheme-library-files))))))
      (current-primitive-locations (lambda (x)
;;;(pretty-print/stderr (list x (assq x locs)))
				     (cond ((assq x locs) => cdr)
					   (else
					    (error 'bootstrap "no location for primitive" x)))))
      (let ((port (open-file-output-port boot-file-name (file-options no-fail))))
	(time-it "code generation and serialization"
	  (lambda ()
	    (debug-printf "Compiling ")
	    (for-each (lambda (name core)
			(debug-printf " ~s" name)
			(compile-core-expr-to-port core port))
	      name*
	      core*)
	    (debug-printf "\n")))
	(close-output-port port)))))

;(print-missing-prims)

(fprintf (console-error-port) "Happy Happy Joy Joy\n")

;;; end of file
;;; Local Variables:
;;; eval: (put 'time-it 'scheme-indent-function 1)
;;; eval: (put 'each-for 'scheme-indent-function 1)
;;; End:
