;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for numerics functions: modulo
;;;Date: Fri Nov 30, 2012
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2012, 2013 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under the terms of the  GNU General Public License as published by
;;;the Free Software Foundation, either version 3 of the License, or (at
;;;your option) any later version.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY or  FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received a  copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!r6rs
(import (vicare)
  (libtest numerics-helpers)
  (vicare system $ratnums)
  (vicare system $compnums)
  (vicare system $numerics)
  (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare numerics functions: modulo, integer division\n")


(parametrise ((check-test-name	'fixnums))

  (let-syntax ((test (make-test modulo $modulo-fixnum-fixnum)))
    (test 0 +1 (r6rs-modulo 0 +1))
    (test 0 -1 (r6rs-modulo 0 -1))
    (test FX1 FX1 (r6rs-modulo FX1 FX1))
    (test FX2 FX1 (r6rs-modulo FX2 FX1))
    (test FX3 FX1 (r6rs-modulo FX3 FX1))
    (test FX4 FX1 (r6rs-modulo FX4 FX1))
    (test FX1 FX2 (r6rs-modulo FX1 FX2))
    (test FX2 FX2 (r6rs-modulo FX2 FX2))
    (test FX3 FX2 (r6rs-modulo FX3 FX2))
    (test FX4 FX2 (r6rs-modulo FX4 FX2))
    (test FX1 FX3 (r6rs-modulo FX1 FX3))
    (test FX2 FX3 (r6rs-modulo FX2 FX3))
    (test FX3 FX3 (r6rs-modulo FX3 FX3))
    (test FX4 FX3 (r6rs-modulo FX4 FX3))
    (test FX1 FX4 (r6rs-modulo FX1 FX4))
    (test FX2 FX4 (r6rs-modulo FX2 FX4))
    (test FX3 FX4 (r6rs-modulo FX3 FX4))
    (test FX4 FX4 (r6rs-modulo FX4 FX4))
    #f)

  (let-syntax ((test (make-test modulo #;$modulo-fixnum-bignum)))
    (test FX1 BN1 (r6rs-modulo FX1 BN1))
    (test FX2 BN1 (r6rs-modulo FX2 BN1))
    (test FX3 BN1 (r6rs-modulo FX3 BN1))
    (test FX4 BN1 (r6rs-modulo FX4 BN1))
    (test FX1 BN2 (r6rs-modulo FX1 BN2))
    (test FX2 BN2 (r6rs-modulo FX2 BN2))
    (test FX3 BN2 (r6rs-modulo FX3 BN2))
    (test FX4 BN2 (r6rs-modulo FX4 BN2))
    (test FX1 BN3 (r6rs-modulo FX1 BN3))
    (test FX2 BN3 (r6rs-modulo FX2 BN3))
    (test FX3 BN3 (r6rs-modulo FX3 BN3))
    (test FX4 BN3 (r6rs-modulo FX4 BN3))
    (test FX1 BN4 (r6rs-modulo FX1 BN4))
    (test FX2 BN4 (r6rs-modulo FX2 BN4))
    (test FX3 BN4 (r6rs-modulo FX3 BN4))
    (test FX4 BN4 (r6rs-modulo FX4 BN4))
    #f)

  (let-syntax ((test (make-inexact-test modulo $modulo-fixnum-flonum)))
    (test 0 +2.0 (r6rs-modulo 0 +2.0))
    (test 0 -2.0 (r6rs-modulo 0 -2.0))

    (test +10 +2.0 (r6rs-modulo +10 +2.0))
    (test +10 -2.0 (r6rs-modulo +10 -2.0))
    (test -10 +2.0 (r6rs-modulo -10 +2.0))
    (test -10 -2.0 (r6rs-modulo -10 -2.0))

    (test +10 +22.0 (r6rs-modulo +10 +22.0))
    (test +10 -22.0 (r6rs-modulo +10 -22.0))
    (test -10 +22.0 (r6rs-modulo -10 +22.0))
    (test -10 -22.0 (r6rs-modulo -10 -22.0))

    (test +10 +13.0 (r6rs-modulo +10 +13.0))
    (test +10 -13.0 (r6rs-modulo +10 -13.0))
    (test -10 +13.0 (r6rs-modulo -10 +13.0))
    (test -10 -13.0 (r6rs-modulo -10 -13.0))

    #f)

;;; --------------------------------------------------------------------

  (let-syntax ((test (make-test modulo $modulo-fixnum-bignum)))
    (test FX1 VBN1 (r6rs-modulo FX1 VBN1))
    (test FX2 VBN1 (r6rs-modulo FX2 VBN1))
    (test FX3 VBN1 (r6rs-modulo FX3 VBN1))
    (test FX4 VBN1 (r6rs-modulo FX4 VBN1))
    (test FX1 VBN2 (r6rs-modulo FX1 VBN2))
    (test FX2 VBN2 (r6rs-modulo FX2 VBN2))
    (test FX3 VBN2 (r6rs-modulo FX3 VBN2))
    (test FX4 VBN2 (r6rs-modulo FX4 VBN2))
    (test FX1 VBN3 (r6rs-modulo FX1 VBN3))
    (test FX2 VBN3 (r6rs-modulo FX2 VBN3))
    (test FX3 VBN3 (r6rs-modulo FX3 VBN3))
    (test FX4 VBN3 (r6rs-modulo FX4 VBN3))
    (test FX1 VBN4 (r6rs-modulo FX1 VBN4))
    (test FX2 VBN4 (r6rs-modulo FX2 VBN4))
    (test FX3 VBN4 (r6rs-modulo FX3 VBN4))
    (test FX4 VBN4 (r6rs-modulo FX4 VBN4))
    #f)

  #t)


(parametrise ((check-test-name	'bignums))

  (let-syntax ((test (make-test modulo $modulo-bignum-fixnum)))
    (test VBN1 FX1  (r6rs-modulo VBN1 FX1 ))
    (test VBN2 FX1  (r6rs-modulo VBN2 FX1 ))
    (test VBN3 FX1  (r6rs-modulo VBN3 FX1 ))
    (test VBN4 FX1  (r6rs-modulo VBN4 FX1 ))
    (test VBN1 FX2  (r6rs-modulo VBN1 FX2 ))
    (test VBN2 FX2  (r6rs-modulo VBN2 FX2 ))
    (test VBN3 FX2  (r6rs-modulo VBN3 FX2 ))
    (test VBN4 FX2  (r6rs-modulo VBN4 FX2 ))
    (test VBN1 FX3  (r6rs-modulo VBN1 FX3 ))
    (test VBN2 FX3  (r6rs-modulo VBN2 FX3 ))
    (test VBN3 FX3  (r6rs-modulo VBN3 FX3 ))
    (test VBN4 FX3  (r6rs-modulo VBN4 FX3 ))
    (test VBN1 FX4  (r6rs-modulo VBN1 FX4 ))
    (test VBN2 FX4  (r6rs-modulo VBN2 FX4 ))
    (test VBN3 FX4  (r6rs-modulo VBN3 FX4 ))
    (test VBN4 FX4  (r6rs-modulo VBN4 FX4 ))
    #f)

  (let-syntax ((test (make-test modulo $modulo-bignum-bignum)))
    (test VBN1 VBN1 (r6rs-modulo VBN1 VBN1))
    (test VBN2 VBN1 (r6rs-modulo VBN2 VBN1))
    (test VBN3 VBN1 (r6rs-modulo VBN3 VBN1))
    (test VBN4 VBN1 (r6rs-modulo VBN4 VBN1))
    (test VBN1 VBN2 (r6rs-modulo VBN1 VBN2))
    (test VBN2 VBN2 (r6rs-modulo VBN2 VBN2))
    (test VBN3 VBN2 (r6rs-modulo VBN3 VBN2))
    (test VBN4 VBN2 (r6rs-modulo VBN4 VBN2))
    (test VBN1 VBN3 (r6rs-modulo VBN1 VBN3))
    (test VBN2 VBN3 (r6rs-modulo VBN2 VBN3))
    (test VBN3 VBN3 (r6rs-modulo VBN3 VBN3))
    (test VBN4 VBN3 (r6rs-modulo VBN4 VBN3))
    (test VBN1 VBN4 (r6rs-modulo VBN1 VBN4))
    (test VBN2 VBN4 (r6rs-modulo VBN2 VBN4))
    (test VBN3 VBN4 (r6rs-modulo VBN3 VBN4))
    (test VBN4 VBN4 (r6rs-modulo VBN4 VBN4))
    #f)

  (let-syntax ((test (make-inexact-test modulo $modulo-bignum-flonum)))
    (test VBN1 +2.0 (r6rs-modulo VBN1 +2.0))
    (test VBN1 -2.0 (r6rs-modulo VBN1 -2.0))
    (test VBN2 +2.0 (r6rs-modulo VBN2 +2.0))
    (test VBN2 -2.0 (r6rs-modulo VBN2 -2.0))

    (test VBN1 +22.0 (r6rs-modulo VBN1 +22.0))
    (test VBN1 -22.0 (r6rs-modulo VBN1 -22.0))
    (test VBN2 +22.0 (r6rs-modulo VBN2 +22.0))
    (test VBN2 -22.0 (r6rs-modulo VBN2 -22.0))

    (test VBN1 +13.0 (r6rs-modulo VBN1 +13.0))
    (test VBN1 -13.0 (r6rs-modulo VBN1 -13.0))
    (test VBN2 +13.0 (r6rs-modulo VBN2 +13.0))
    (test VBN2 -13.0 (r6rs-modulo VBN2 -13.0))

    (test VBN1 +2.0 (r6rs-modulo VBN1 +2.0))
    (test VBN1 -2.0 (r6rs-modulo VBN1 -2.0))
    (test VBN4 +2.0 (r6rs-modulo VBN4 +2.0))
    (test VBN4 -2.0 (r6rs-modulo VBN4 -2.0))

    (test VBN3 +22.0 (r6rs-modulo VBN3 +22.0))
    (test VBN3 -22.0 (r6rs-modulo VBN3 -22.0))
    (test VBN4 +22.0 (r6rs-modulo VBN4 +22.0))
    (test VBN4 -22.0 (r6rs-modulo VBN4 -22.0))

    (test VBN3 +13.0 (r6rs-modulo VBN3 +13.0))
    (test VBN3 -13.0 (r6rs-modulo VBN3 -13.0))
    (test VBN4 +13.0 (r6rs-modulo VBN4 +13.0))
    (test VBN4 -13.0 (r6rs-modulo VBN4 -13.0))
    #f)

  #t)


(parametrise ((check-test-name	'flonums))

  (let-syntax ((test (make-inexact-test modulo $modulo-flonum-fixnum)))
    (test (inexact BN1) FX1 (r6rs-modulo (inexact BN1) FX1))
    (test (inexact BN2) FX1 (r6rs-modulo (inexact BN2) FX1))
    (test (inexact BN3) FX1 (r6rs-modulo (inexact BN3) FX1))
    (test (inexact BN4) FX1 (r6rs-modulo (inexact BN4) FX1))

    (test (inexact BN1) FX2 (r6rs-modulo (inexact BN1) FX2))
    (test (inexact BN2) FX2 (r6rs-modulo (inexact BN2) FX2))
    (test (inexact BN3) FX2 (r6rs-modulo (inexact BN3) FX2))
    (test (inexact BN4) FX2 (r6rs-modulo (inexact BN4) FX2))

    (test (inexact BN1) FX3 (r6rs-modulo (inexact BN1) FX3))
    (test (inexact BN2) FX3 (r6rs-modulo (inexact BN2) FX3))
    (test (inexact BN3) FX3 (r6rs-modulo (inexact BN3) FX3))
    (test (inexact BN4) FX3 (r6rs-modulo (inexact BN4) FX3))

    (test (inexact BN1) FX4 (r6rs-modulo (inexact BN1) FX4))
    (test (inexact BN2) FX4 (r6rs-modulo (inexact BN2) FX4))
    (test (inexact BN3) FX4 (r6rs-modulo (inexact BN3) FX4))
    (test (inexact BN4) FX4 (r6rs-modulo (inexact BN4) FX4))
    #f)

  (let-syntax ((test (make-inexact-test modulo #;$modulo-flonum-bignum)))
    (test (inexact BN1) VBN1 (r6rs-modulo (inexact BN1) VBN1))
    (test (inexact BN2) VBN1 (r6rs-modulo (inexact BN2) VBN1))
    (test (inexact BN3) VBN1 (r6rs-modulo (inexact BN3) VBN1))
    (test (inexact BN4) VBN1 (r6rs-modulo (inexact BN4) VBN1))

    (test (inexact BN1) VBN2 (r6rs-modulo (inexact BN1) VBN2))
    (test (inexact BN2) VBN2 (r6rs-modulo (inexact BN2) VBN2))
    (test (inexact BN3) VBN2 (r6rs-modulo (inexact BN3) VBN2))
    (test (inexact BN4) VBN2 (r6rs-modulo (inexact BN4) VBN2))

    (test (inexact BN1) VBN3 (r6rs-modulo (inexact BN1) VBN3))
    (test (inexact BN2) VBN3 (r6rs-modulo (inexact BN2) VBN3))
    (test (inexact BN3) VBN3 (r6rs-modulo (inexact BN3) VBN3))
    (test (inexact BN4) VBN3 (r6rs-modulo (inexact BN4) VBN3))

    (test (inexact BN1) VBN4 (r6rs-modulo (inexact BN1) VBN4))
    (test (inexact BN2) VBN4 (r6rs-modulo (inexact BN2) VBN4))
    (test (inexact BN3) VBN4 (r6rs-modulo (inexact BN3) VBN4))
    (test (inexact BN4) VBN4 (r6rs-modulo (inexact BN4) VBN4))
    #f)

  (let-syntax ((test (make-inexact-test modulo $modulo-flonum-flonum)))
    (test 25.0 10.0  (r6rs-modulo 25.0 10.0 ))
    (test 10.0 25.0  (r6rs-modulo 10.0 25.0 ))

    (test +0.0 +2.0 (r6rs-modulo +0.0 +2.0))
    (test +0.0 -2.0 (r6rs-modulo +0.0 -2.0))
    (test -0.0 +2.0 (r6rs-modulo -0.0 +2.0))
    (test -0.0 -2.0 (r6rs-modulo -0.0 -2.0))

    (test +10.0 +2.0 (r6rs-modulo +10.0 +2.0))
    (test +10.0 -2.0 (r6rs-modulo +10.0 -2.0))
    (test -10.0 +2.0 (r6rs-modulo -10.0 +2.0))
    (test -10.0 -2.0 (r6rs-modulo -10.0 -2.0))

    (test +10.0 +22.0 (r6rs-modulo +10.0 +22.0))
    (test +10.0 -22.0 (r6rs-modulo +10.0 -22.0))
    (test -10.0 +22.0 (r6rs-modulo -10.0 +22.0))
    (test -10.0 -22.0 (r6rs-modulo -10.0 -22.0))

    (test +10.0 +13.0 (r6rs-modulo +10.0 +13.0))
    (test +10.0 -13.0 (r6rs-modulo +10.0 -13.0))
    (test -10.0 +13.0 (r6rs-modulo -10.0 +13.0))
    (test -10.0 -13.0 (r6rs-modulo -10.0 -13.0))

    #f)

  #t)


;;;; done

(check-report)

;;; end of file
