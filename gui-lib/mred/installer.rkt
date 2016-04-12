#lang racket/base
(require launcher 
         compiler/embed
         racket/file
         racket/path
         setup/dirs
         setup/cross-system)

(provide installer
         addon-installer)

;; Platforms that get a `MrEd' executable:
(define mred-exe-systems '(unix))

(define (installer path coll user?)
  (do-installer path coll user? #f))

(define (addon-installer path coll user?)
  (do-installer path coll #t #t))

(define (do-installer path coll user? addon?)
  (define variants (available-mred-variants))
  (when (memq (cross-system-type) mred-exe-systems)
    (for ([v variants] #:when (memq v '(3m cgc)))
      (parameterize ([current-launcher-variant v])
        (create-embedding-executable
         (prep-dir (mred-program-launcher-path "MrEd" #:user? user? #:addon? addon?))
         #:cmdline (append
                    (if addon? (addon-flags) null)
                    '("-I" "scheme/gui/init"))
         #:variant v
         #:launcher? #t
         #:gracket? #t
         #:aux `((relative? . ,(not user?)))))))
  ;; add a mred-text executable that uses the -z flag (preferring a script)
  (for ([vs '((script-3m 3m) (script-cgc cgc))])
    (let ([v (findf (lambda (v) (memq v variants)) vs)])
      (when v
        (parameterize ([current-launcher-variant v])
          (make-gracket-launcher
           (append
            (if addon? (addon-flags) null)
            '("-I" "scheme/gui/init" "-z"))
           (prep-dir (mred-program-launcher-path "mred-text" #:user? user? #:addon? addon?))
           `([relative? . ,(not user?)] [subsystem . console] [single-instance? . #f]))))))
  ;; add bin/mred script under OS X
  (when (eq? 'macosx (cross-system-type))
    (for ([v variants] #:when (memq v '(script-3m script-cgc)))
      (parameterize ([current-launcher-variant v])
        (make-gracket-launcher
         (if addon? (addon-flags) null)
         (prep-dir (mred-program-launcher-path "MrEd" #:user? user? #:addon? addon?))
         `([exe-name . "GRacket"] [relative? . ,(not user?)] [exe-is-gracket . #t]))))))

(define (prep-dir p)
  (define dir (path-only p))
  (make-directory* dir)
  p)

(define (addon-flags)
  (list "-A" (path->string (find-system-path 'addon-dir))))
