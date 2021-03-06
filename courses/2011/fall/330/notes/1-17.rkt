#lang plai
(halt-on-errors)

;; XXX remove envs
;; XXX remove closures/numVs
;; XXX meta interpreter
;; XXX meta-circular
;; XXX encode booleans
;; XXX encode lists
;; XXX encode numbers

;; abstract syntax
(define-type AE
  [num (n number?)]
  [binop (op procedure?)
         (lhs AE?)
         (rhs AE?)]
  [if0 (cond-e AE?)
       (true-e AE?)
       (false-e AE?)]
  [id (s symbol?)]
  [fun (arg-name symbol?)
       (body AE?)]
  [app (fun-expr AE?) 
       (arg AE?)])

(define (rec name named-value body)
  ;; make-the-recursive-bro!-stx = the Y (combinator)
  (define make-the-recursive-bro!-stx
    (parse '(fun (the-real-work)
                 (with (f
                        (fun (f)
                             (the-real-work
                              (fun (n)
                                   ((f f) n)))))
                       (fun (n)
                            ((f f) n))))))
  (with name
        (app
         make-the-recursive-bro!-stx    
         (fun name
              named-value))
        body))
  
(define (with name named-thing body)
  (app (fun name body) named-thing))
(define (add lhs rhs)
  (binop + lhs rhs))
(define (mult lhs rhs)
  (binop * lhs rhs))

;; concrete syntax
#|
AE = <number>
   | (* <AE> <AE>)
   | (+ <AE> <AE>)
   | (- <AE> <AE>)
   | (with (<id> <AE>) <AE>)
   | (rec (<id> <AE>) <AE>)
   | (fun (<id>) <AE>)
   | <id>
   | (<AE> <AE>)
   | (if0 <AE> <AE> <AE>)
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
         (equal? '- (first c)))
    (binop -
           (parse (second c))
           (parse (third c)))]
   [(and (list? c)
         (= 3 (length c))
         (equal? '* (first c)))
    (mult (parse (second c))
          (parse (third c)))]
   [(and (list? c)
         (= 3 (length c))
         (equal? 'with (first c)))
    (with (first (second c))
          (parse (second (second c)))
          (parse (third c)))]
   [(and (list? c)
         (= 3 (length c))
         (equal? 'rec (first c)))
    (rec (first (second c))
          (parse (second (second c)))
          (parse (third c)))]
   [(and (list? c)
         (= 3 (length c))
         (equal? 'fun (first c)))
    (fun (first (second c))
         (parse (third c)))]
   [(and (list? c)
         (= 4 (length c))
         (equal? 'if0 (first c)))
    (if0 (parse (second c))
         (parse (third c))
         (parse (fourth c)))]
   [(and (list? c)
         (= 2 (length c)))
    (app (parse (first c))
         (parse (second c)))]
   [(symbol? c)
    (id c)]
   [else
    (error 'parse "Bad programmer, no cake ~e" c)]))

(test (parse '(+ 1 1))
      (add (num 1) (num 1)))
(test/exn (parse '(+ 1 1 1))
          "no cake")
(test (parse '(* 3 1))
      (mult (num 3) (num 1)))
(test (parse '(fun (x) x))
      (fun 'x (id 'x)))
(test (parse '((fun (x) x) 5))
      (app (fun 'x (id 'x)) (num 5)))

;; Env = (symbol? -> AE?)
(define DefrdSubst? procedure?)
(define (mtEnv)
  (lambda (s)
    (error 'lookup-binding "Unbound identifier ~e" s)))
(define (anEnv name named-value more)
  (lambda (s)
    (if (symbol=? s name)
        named-value
        (lookup-binding s more))))

;; lookup-binding : symbol? DefrdSub -> AE?
(define (lookup-binding s ds)
  (ds s))

(define (AEV? x)
  (or (number? x)
      (procedure? x)))

(define (numV n)
  n)
(define (closureV arg-name fun-body saved-env)
  (lambda (arg-value)
    (interp* fun-body
             (anEnv arg-name
                    arg-value
                    saved-env))))

(define (lifted op . args)
  (apply op (map denum args)))

(define (denum v)
  (if (number? v)
      v
      (error 'interp "Not a number")))

(define (lift binop lhs rhs)
  (numV (lifted binop lhs rhs)))

;; interp* : AE DefrdSub -> meaning
(define (interp* some-ae ds)
  (type-case
   AE some-ae
   [num (n)
        (numV n)]
   [binop (op lhs rhs)
        (lift op
              (interp* lhs ds)
              (interp* rhs ds))]
   [id (s)
       (lookup-binding s ds)]
   [if0 (cond-e true-e false-e)
        (if (lifted zero? (interp* cond-e ds))
            (interp* true-e ds)
            (interp* false-e ds))]
   [fun (arg-name body-expr)
        ;; Save the Environment
        ;; Create A Closure, Today!
        (closureV arg-name body-expr ds)]
   [app (fun-expr arg-expr)
        ;; interp* : AE ds -> number
        ;; fun-expr : AE
        (local [(define the-fun (interp* fun-expr ds))]
               (if (procedure? the-fun)
                   (the-fun (interp* arg-expr ds))
                   (error 'interp "Not a function")))]))

(define (interp ae)
  (define ans
    (interp* ae (mtEnv)))
  ans)

(test/exn (interp (parse '(5 4)))
          "Not a function")
(test/exn (interp (parse '(+ (fun (x) x) 1)))
          "Not a number")      

;;(test (interp (parse '(fun (x) x)))
;;      (closureV 'x (id 'x) (mtEnv)))

(test (interp (parse '5))
      5)
(test (interp (parse '42))
      42)

(test (interp (parse '(+ 1 1)))
      2)
(test (interp (parse '(+ 1 99)))
      100)

(test (interp (parse '(* 3 2)))
      6)
(test (interp (parse '(* 1/99 99)))
      1)

(test (interp (parse '(+ (+ (+ (+ 1 1) (+ 1 1)) (+ (+ 1 1) (+ 1 1))) (+ 1 1))))
      10)

(test (interp (parse '(with (x (+ 1 1)) (+ x x))))
      4)
(test (interp (parse '(with (x 2) (+ x x))))
      4)
(test (interp (parse '(with (x 2) (+ 2 x))))
      4)
(test (interp (parse '(with (x 2) (+ 2 2))))
      4)
(test (interp (parse '(+ 2 2)))
      4)

(test/exn (interp (parse 'x))
          "Unbound")
(test (interp (parse '(with (x (+ 1 1)) (* x x))))
      4)
(test (interp (parse '(with (x 1) (with (y 2) (+ x y)))))
      3)
(test (interp (parse '(with (x 1) (with (y x) (+ x y)))))
      2)
(test (interp (parse '(with (x 1) (with (x x) (+ x x)))))
      2)

(test (interp (parse '(with (y 2) (+ 1 y))))
      3)

;; This tells if we are substituting text or not:
(test/exn (interp (parse '(with (y x) 3)))
          "Unbound")

(test (parse '(foo 1)) (app (id 'foo) (num 1)))
(test (interp (parse '(with (double (fun (x) (+ x x)))
                            (double 3))))
      6)
(test (interp (parse '(with (double (fun (x) (+ x x)))
                            (double (+ 3 2)))))
      10)

(test (interp (parse '(with (g 10)
                            (with (f (fun (n) (+ g 5)))
                                  (f 5)))))
      15)
(test (interp (parse '(with (g (fun (m) (+ m 1)))
                            (with (f (fun (n) (g (+ n 5))))
                                  (f 5)))))
      11)

;(test (interp (parse '(f 5)) (list (fundef 'f 'n (app 'f (add (id 'n) (num 5))))))
;      11)

;; induction vs co-induction
;; recursion vs co-recursion

;; Lisp1 vs (we are Lisp2)

(test (interp (parse '(with (x 5)
                            (+ (+ x x)
                               (* x x)))))
      35)

(test (interp (parse
               ;; ds = mt
               '(with (x 5)
                      ;; ds = x -> 5 :: mt
                      (+
                       ;; ds = x -> 5 :: mt
                       (with (x 10)
                             ;; ds = x -> 10 :: x -> 5 :: mt
                             (+ x x))
                       ;; ds = x -> 5 :: mt
                       (* x x)))))
      45)

(test (interp (parse
               '(with (x 5)
                      (+
                       (with (x x)
                             (+ x x))
                       (* x x)))))
      35)

(test (interp (parse '(+ (with (x 5)
                               x)
                         (with (x 7)
                               x))))
      12)


;; f(n) = g(n+5)
;; g(m) = n+1
;; f(5)
(test/exn (interp (parse '(with (g (fun (m) (+ n 1)))
                                (g 5))))
          "Unbound identifier")
(test/exn (interp (parse '(with (g (fun (m) (+ n 1)))
                                (with (n 10) (g 5)))))
          "Unbound identifier")

(test (interp (parse '(with (x 5) (+ x x))))
      10)

;; f(x) = x + x; f(5)
;; Voldemort(x) = x+x; Voldemort(5)
;; (\ x. x + x) 5
(test (interp (parse '((fun (x) (+ x x)) 5)))
      10)

(test (interp (parse '(if0 0 1 2)))
      1)
(test (interp (parse '(if0 1 1 2)))
      2)

(test/exn (interp (parse '(with (fac
                                 (fun (n)
                                      (if0 n
                                           1
                                           (* n (fac (- n 1))))))
                                (fac 5))))
          "Unbound identifier")

(test (interp (parse '(rec (fac
                             (fun (n)
                                  (if0 n
                                       1
                                       (* n (fac (- n 1))))))
                            (fac 0))))
      1)
(test (interp (parse '(rec (fac
                             (fun (n)
                                  (if0 n
                                       1
                                       (* n (fac (- n 1))))))
                           (fac 1))))
      1)
(test (interp (parse '(rec (fac
                             (fun (n)
                                  (if0 n
                                       1
                                       (* n (fac (- n 1))))))
                           (fac 2))))
      2)
(test (interp (parse '(rec (fac
                             (fun (n)
                                  (if0 n
                                       1
                                       (* n (fac (- n 1))))))
                            (fac 5))))
      120)

;;(test (interp (parse '(rec (x (+ x 2))
;;                           x)))
;;      2.145834543)

;;(test (interp (parse '(fun (x) (x x))))
;;      (closureV 'x (app (id 'x) (id 'x)) (mtEnv)))

(test/exn (interp (parse '(with (o (fun (x) (x x)))
                                (o (fun (n) (+ n 1))))))
          "Not a number")
(test/exn (interp (parse '((fun (n) (+ n 1))
                           (fun (n) (+ n 1)))))
          "Not a number")

(test/exn (interp (parse '(+ 
                           (fun (n) (+ n 1))
                           1)))
          "Not a number")
      
;;(test (interp (parse '(with (o (fun (x) (x x)))
;;                            (o o))))
;;      (interp (parse
;;               '(with (o (fun (x) (x x)))
;;                      (o o)))))


(test (interp (parse '(with (fac
                             (fun (fac)
                                  (fun (n)
                                       (if0 n
                                            1
                                            (* n ((fac fac) (- n 1)))))))
                            ((fac fac) 5))))
      120)

(define (fib n)
  (cond
   [(= n 0) 1]
   [(= n 1) 1]
   [else
    (+ (fib (- n 1))
       (fib (- n 2)))]))

(test (interp (parse '(with (fib
                             (fun (fib)
                                  (fun (n)
                                       (if0 n
                                            1
                                            (if0 (- n 1)
                                                 1
                                                 (+ ((fib fib) (- n 1))
                                                    ((fib fib) (- n 2))))))))
                            ((fib fib) 5))))
      (fib 5))

(test (interp (parse '(with (make-this-recursive-bro!
                             (fun (the-real-work)
                                  (with (f
                                         (fun (f)
                                              (the-real-work
                                               (fun (n)
                                                    ((f f) n)))))
                                        (fun (n)
                                             ((f f) n)))))
                            (with (fac
                                   (make-this-recursive-bro!
                                    (fun (fac)
                                         (fun (n)
                                              (if0 n
                                                   1
                                                   (* n (fac (- n 1))))))))
                                  (fac 5)))))
      120)

;; Church Encoding
;; Alonzo Church
;; Church-Turing Thesis
;;   = "algorithms are turning machines and turning machines are algorithms"
;;   = "anything you can think of is a program ps turing machines are programs"
;;   = The Lambda-Calculus and Turing Machines are equivalent representations of effective mathematics

;; lc = x
;;    | lc lc
;;    | \x. lc

;; (\x.e) e' => e [x <- e']


;; Bool = Ans -> Ans -> Ans
(define lc:true
  (lambda (tru-fun)
    (lambda (fal-fun)
      tru-fun)))
(define lc:false
  (lambda (tru-fun)
    (lambda (fal-fun)
      fal-fun)))

;; Nat = f -> x -> f ... f x
(define zero
  (lambda (f)
    (lambda (x)
      x)))
(define one
  (lambda (f)
    (lambda (x)
      (f x))))
(define two
  (lambda (f)
    (lambda (x)
      (f (f x)))))

((lc:true one) zero)
((lc:false one) zero)

(test ((two add1) 0) 2)
(test ((zero add1) 0) 0)

(define succ
  (lambda (n)
    (lambda (f)
      (lambda (x)
        (f ((n f) x))))))

(test (((succ two) add1) 0)
      3)

(define plus
  (lambda (n)
    (lambda (m)
      (lambda (f)
        (lambda (x)
          ((m f)
           ((n f) x)))))))

(test ((((plus two) two) add1) 0)
      4)

(define lc:mult
  (lambda (n)
    (lambda (m)
      (lambda (f)
        (lambda (x)
          ((n (m f)) x))))))

(test ((((lc:mult (succ two)) two) add1) 0)
      6)

(define lc:mult2
  (lambda (n)
    (lambda (m)
      (lambda (f)
        (n (m f))))))

(test ((((lc:mult2 (succ two)) two) add1) 0)
      6)


;; Sets => Nat ... Nat = 0 | S Nat

;; Nat => Int .... (Nat,Nat) it is the integer lhs - rhs
;; int0 + int1 = int2
;;(nat0l, nat0r) + (nat1l, nat1r) = (nat0l + nat1l, nat0r + nat1r)

;; Int => Rat ... (Int, Int) it is the rational lhs / rhs
;; Rat => Real ... Dedekind cut... ((Rat ...), (Rat ...)) (smaller, bigger)
;;             ... (Rat ...) converges to the Real

(define lc:cons
  (lambda (left)
    (lambda (right)
      (lambda (sel)
        ((sel left) right)))))
(define lc:first
  (lambda (left)
    (lambda (right)
      left)))
(define lc:rest
  (lambda (left)
    (lambda (right)
      right)))

(((lc:cons 1) 2) lc:first)
(((lc:cons 1) 2) lc:rest)
    
