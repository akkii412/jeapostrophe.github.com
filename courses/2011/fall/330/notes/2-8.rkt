#lang plai

;; 1 + 1
;; + 1 1
;; 1 1 +

;(define-struct num (the-number))
;(define-struct add (the-lhs the-rhs))

;; abstract syntax
(define-type AE
  [num (n number?)]
  [add (lhs AE?)
       (rhs AE?)]
  [mult (lhs AE?)
        (rhs AE?)]
  [id (s symbol?)]
  [with (name symbol?)
        (named-thing AE?)
        (place-where-it-is-named AE?)])

;; abstract program
(add (num 1)
     (num 1))


;; concrete program
(define e '(+ 1 1))
e
(empty? e)
(cons? e)
(first e)
(second e)
(third e)

;; concrete syntax
#|
AE = <number>
   | (* <AE> <AE>)
   | (+ <AE> <AE>)
   | <id>
   | (with (<id> <AE>) <AE>)
|#

;; parse : concrete -> abstract
(define (parse c)
  (cond
   [(number? c)
    (num c)]
   [(and (list? c)
         (= 3 (length c))
         (equal? '+ (first c)))
    (add (parse (second c))
         (parse (third c)))]
   [(and (list? c)
         (= 3 (length c))
         (equal? '* (first c)))
    (mult (parse (second c))
          (parse (third c)))]
   [(symbol? c)
    (id c)]
   [(and (list? c)
         (= 3 (length c))
         (equal? 'with (first c)))
    (with (first (second c))
          (parse (second (second c)))
          (parse (third c)))]
   [else
    (error 'parse "Bd programmer, no cake ~e" c)]))

(parse e)

;; paren'd thing is an s-expression, abbrv'd sexpr
;; <xml><a>stupid</a><way>of writing</way><sexpr /></xml>
;; (xml (a stupid) (way of writing) (sexpr))

(test (parse '(+ 1 1))
      (add (num 1) (num 1)))
(test/exn (parse '(+ 1 1 1))
          "no cake")

(test (parse '(* 3 1))
      (mult (num 3) (num 1)))

;; subst : id AE AE -> AE
(define (subst i v e)
  (type-case
   AE e
   [num (n)
        (num n)]
   [add (lhs rhs)
        (add (subst i v lhs)
             (subst i v rhs))]
   [mult (lhs rhs)
        (mult (subst i v lhs)
              (subst i v rhs))]
   [id (s)
       (if (equal? i s)
           v
           (id s))]
   [with (i* v* e*)
         (if (equal? i i*)
             (with i*
                   (subst i v v*)
                   e*)
             (with i*
                   (subst i v v*)
                   (subst i v e*)))]))

;; interp : program -> meaning

;; calc : AE -> number
(define (calc some-ae)
  (type-case
   AE some-ae
   [num (n)
        n]
   [add (lhs rhs)
        (+ (calc lhs)
           (calc rhs))]
   [mult (lhs rhs)
         (* (calc lhs)
            (calc rhs))]
   [id (s)
       (error 'calc "Unbound id: ~e" s)]
   [with (i v e)
         ;(calc (subst i v e))
         (calc (subst i (num (calc v)) e))
         ]
   ))

(test/exn (calc (parse 'x))
          "Unbound")

(test (calc (parse '5))
      5)
(test (calc (parse '42))
      42)

(test (calc (parse '(+ 1 1)))
      2)
(test (calc (parse '(+ 1 99)))
      100)

(test (calc (parse '(* 3 2)))
      6)
(test (calc (parse '(* 1/99 99)))
      1)

(test (calc (parse '(+ (+ (+ (+ 1 1) (+ 1 1)) (+ (+ 1 1) (+ 1 1))) (+ 1 1))))
      10)

(define awesomitude 42981458484)
(define wicked-hard (+ 1 1))

(test (calc (parse '(+ (+ 1 1)
                       (+ 1 1))))
      4)
(test (calc (parse '(with (x (+ 1 1))
                          (+ x x))))
      4)
(test (calc (parse '(with (x (+ 1 1))
                          4)))
      4)
(test (calc (parse '(+ (with (x (+ 1 1))
                             (+ x x))
                       (with (x 4)
                             (+ x x)))))
      12)

;; Substitution of i for v inside e

;; Definition 1: replace all the 'i's inside e with v
(test (subst 'x (parse '(+ 1 1))
             (parse '(+ x x)))
      (parse '(+ (+ 1 1)
                 (+ 1 1))))

;(test (subst 'x (parse '1)
;             (parse '(with (x 2) x)))
;      (parse '(with (1 2) 1)))

;; Definition 2: replace all the 'i's inside e with v, provided they are references
;(test (subst 'x (parse '1)
;             (parse '(with (x 2) x)))
;      (parse '(with (x 2) 1)))

;; Definition 2b: replace all the 'i's inside e with v, provided they are references, until you get to another with
;(test (subst 'x (parse '1)
;             (parse '(with (y 2) x)))
;      (parse '(with (y 2) x)))

;; Definition 3: replace all the 'i's inside e with v, provided they are references, until you get to another with that binds i
(test (subst 'x (parse '1)
             (parse '(with (x 2) x)))
      (parse '(with (x 2) x)))
(test (subst 'x (parse '1)
             (parse 'x))
      (parse '1))

(test (subst 'x (parse '1)
             (parse '(+ (with (x 2) x)
                        x)))
      (parse '(+ (with (x 2) x)
                 1)))

(test (subst 'x (parse '1)
             (parse '(with (y 2) x)))
      (parse '(with (y 2) 1)))

(test (subst 'x (parse '1)
             (parse '(with (y x) x)))
      (parse '(with (y 1) 1)))

;(test (subst 'x (parse '1)
;             (parse '(with (x x) x)))
;      (parse '(with (x x) x)))

;; Definition 4: replace all the 'i's inside e with v, provided they are references, and don't go inside with bodies that bind i
(test (subst 'x (parse '1)
             (parse '(with (x x) x)))
      (parse '(with (x 1) x)))

;; Definition 5: replace all free occurrence of i in e with v
;; A free occurrence is an unbound occurrence
;; A bound occurrence is one that appears inside a with body where the with binds the identifier