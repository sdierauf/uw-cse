;; Programming Languages, Homework 5
;; Stefan Dierauf sdierauf@cs 1232328

#lang racket
(provide (all-defined-out)) ;; so we can put tests in a second file

;; definition of structures for MUPL programs - Do NOT change
(struct var  (string) #:transparent)  ;; a variable, e.g., (var "foo")
(struct int  (num)    #:transparent)  ;; a constant number, e.g., (int 17)
(struct add  (e1 e2)  #:transparent)  ;; add two expressions
(struct ifgreater (e1 e2 e3 e4)    #:transparent) ;; if e1 > e2 then e3 else e4
(struct fun  (nameopt formal body) #:transparent) ;; a recursive(?) 1-argument function
(struct call (funexp actual)       #:transparent) ;; function call
(struct mlet (var e body) #:transparent) ;; a local binding (let var = e in body) 
(struct apair (e1 e2)     #:transparent) ;; make a new pair
(struct fst  (e)    #:transparent) ;; get first part of a pair
(struct snd  (e)    #:transparent) ;; get second part of a pair
(struct aunit ()    #:transparent) ;; unit value -- good for ending a list
(struct isaunit (e) #:transparent) ;; evaluate to 1 if e is unit else 0

;; a closure is not in "source" programs; it is what functions evaluate to
(struct closure (env fun) #:transparent) 

;; Problem 1

;; CHANGE (put your solutions here)
(define (racketlist->mupllist ls)
  (if (null? ls)
      (aunit)
      (apair (car ls) (racketlist->mupllist (cdr ls)))))

(define (mupllist->racketlist ls)
  (if (aunit? ls)
      null
      (cons (apair-e1 ls) (mupllist->racketlist (apair-e2 ls)))))

;; Problem 2

;; lookup a variable in an environment
;; Do NOT change this function
(define (envlookup env str)
  (cond [(null? env) (error "unbound variable during evaluation" str)]
        [(equal? (car (car env)) str) (cdr (car env))]
        [#t (envlookup (cdr env) str)]))

;; Do NOT change the two cases given to you.  
;; DO add more cases for other kinds of MUPL expressions.
;; We will test eval-under-env by calling it directly even though
;; "in real life" it would be a helper function of eval-exp.
(define (eval-under-env e env)
  (cond [(var? e) 
         (envlookup env (var-string e))]
        [(add? e) 
         (let ([v1 (eval-under-env (add-e1 e) env)]
               [v2 (eval-under-env (add-e2 e) env)])
           (if (and (int? v1)
                    (int? v2))
               (int (+ (int-num v1) 
                       (int-num v2)))
               (error "MUPL addition applied to non-number")))]
        ;; CHANGE add more cases here
        [(apair? e)
         (apair (eval-under-env (apair-e1 e) env) (eval-under-env (apair-e2 e) env))]
        [(aunit? e) e]
        [(call? e)
         (let ([c (eval-under-env (call-funexp e) env)]) ; evaluate function to closure in current env
           (if (closure? c)
               ; yay, evaluate it
               (let* ([c-env (closure-env c)] ; env of closure
                      [c-env (if (fun-nameopt (closure-fun c)) 
                                 (append c-env (list (cons (fun-nameopt (closure-fun c)) c))) 
                                 c-env)] ; update c-env with (function name, closure)
                      [c-env (append (list (cons 
                                            (fun-formal (closure-fun c)) 
                                            (eval-under-env (call-actual e) env))) 
                                     c-env)]) ; zips variable of function with value (could be closure!)
                 (eval-under-env (fun-body (closure-fun c)) c-env)) ; evaluates function body under updated closure environment
               (error "MUPL call on non closure")))]
        [(closure? e) e]
        [(fst? e) (let [(arg (eval-under-env (fst-e e) env))]
                    (if (apair? arg)
                        (apair-e1 arg)
                        (error "MUPL fst applied to non-pair")))]
        [(fun? e) (closure env e)]
        [(ifgreater? e) (let ([arg1 (eval-under-env (ifgreater-e1 e) env)]
                              [arg2 (eval-under-env (ifgreater-e2 e) env)])
                          (if (and (int? arg1) (int? arg2))
                              (if (> (int-num arg1) (int-num arg2))
                                  (eval-under-env (ifgreater-e3 e) env)
                                  (eval-under-env (ifgreater-e4 e) env))
                              (error "MUPL ifgreater applied to non-number")))]
        [(int? e) e]
        [(isaunit? e) (if (aunit? (eval-under-env (isaunit-e e) env)) (int 1) (int 0))]
        [(mlet? e)
         (let ([arg (eval-under-env (mlet-e e) env)])
           (eval-under-env (mlet-body e) (cons (cons (mlet-var e) arg) env)))]
        

        [(snd? e) (let [(arg (eval-under-env (snd-e e) env))]
                    (if (apair? arg)
                        (apair-e2 arg)
                        (error "MUPL snd applied to non pair")))]
        
        [#t (error (format "bad MUPL expression: ~v" e))]))

;; Do NOT change
(define (eval-exp e)
  (eval-under-env e null))
        
;; Problem 3

(define (ifaunit e1 e2 e3) (ifgreater (isaunit e1) (int 0) e2 e3))

; basically a recursive pile of mlets
(define (mlet* lstlst e2)
  (if (null? lstlst)
      e2
      (mlet (car (car lstlst)) (cdr (car lstlst)) (mlet* (cdr lstlst) e2))))

; returns e3 if e1 and e2 are equal otherwise returns e4
(define (ifeq e1 e2 e3 e4) 
  (mlet* (list (cons "_x" e1) (cons "_y" e2))
         ; if both ifgreater "fail" then _x and _y must be equal
         (ifgreater (var "_x") (var "_y") e4 (ifgreater (var "_y") (var "_x") e4 e3)))) 

;; Problem 4

(define mupl-map
  (fun #f "f" 
       (fun "loop" "xs" (ifgreater (isaunit (var "xs")) (int 0) 
                                   (aunit)
                                   (apair
                                    (call (var "f") (fst (var "xs")))
                                    (call (var "loop") (snd (var "xs"))))))))

(define mupl-mapAddN 
  (fun #f "numtoadd" (call mupl-map (fun #f "element" (add (var "element") (var "numtoadd"))))))

;; Challenge Problem

(struct fun-challenge (nameopt formal body freevars) #:transparent) ;; a recursive(?) 1-argument function

;; We will test this function directly, so it must do
;; as described in the assignment
(define (compute-free-vars e) "CHANGE")

;; Do NOT share code with eval-under-env because that will make grading
;; more difficult, so copy most of your interpreter here and make minor changes
(define (eval-under-env-c e env) "CHANGE")

;; Do NOT change this
(define (eval-exp-c e)
  (eval-under-env-c (compute-free-vars e) null))