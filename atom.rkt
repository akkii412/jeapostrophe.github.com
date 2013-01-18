#lang racket/base
(require racket/cmdline
         racket/match
         racket/list
         racket/file
         xml
         "post-help.rkt")

(define (atom! path)
  (with-output-to-file
      path
    #:exists 'replace
    (λ ()
      (match-define
       (regexp #rx"^(....)-(..)-(..)-"
               (list _ last-year last-month last-day))
       (first (all-posts)))
      (write-xexpr
       `(feed ([xmlns "http://www.w3.org/2005/Atom"])
              (title ,(cdata #f #f (format "<![CDATA[~a]]>" *BLOG-TITLE*)))
              (link ([href ,(format "~a/atom.xml" *BLOG-URL*)]
                     [rel "self"]))
              (link ([href ,*BLOG-URL*]))
              (updated ,(format "~a-~a-~aT00:00:00-00:00"
                                last-year last-month last-day))
              (id ,(format "~a/" *BLOG-URL*))
              ,@(for/list ([p (in-list (all-posts))])
                  (define pd (filename->tag p))
                  (match-define
                   (regexp #rx"^(....)-(..)-(..)-"
                           (list _ year month day))
                   pd)
                  (define title (file->string (build-path titles-path pd)))
                  (define html-n (format "~a-post.html" pd))
                  (define this-url (format "~a/~a" *BLOG-URL* html-n))
                  `(entry
                    (title ([type "html"])
                           ,(cdata #f #f (format "<![CDATA[~a]]>" title)))
                    (link ([href
                            ,this-url]))
                    (updated ,(format "~a-~a-~aT00:00:00-00:00"
                                      year month day))
                    (id ,this-url)
                    (content ([type "html"])
                             ,(cdata #f #f
                                     (format "<![CDATA[~a]]>"
                                             (xexpr->string
                                              `(p "For the complete post, please visit " (a ([href ,this-url]) ,this-url) "."))))))))))))

(module+ main
  (command-line
   #:program "atom"
   #:args (output-p)
   (atom! output-p)))
