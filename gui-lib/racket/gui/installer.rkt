#lang racket/base
(require launcher
         racket/path
         racket/file
         setup/dirs)

(provide installer
         addon-installer)

(define (installer path coll user?)
  (do-installer path coll user? #f))

(define (addon-installer path coll user?)
  (do-installer path coll #t #t))

(define (do-installer path collection user? addon?)
  (define variants (available-mred-variants))
  ;; add a gracket-text executable that uses the -z flag (preferring a script)
  (for ([vs '((script-3m 3m) (script-cgc cgc))])
    (let ([v (findf (lambda (v) (memq v variants)) vs)])
      (when v
        (parameterize ([current-launcher-variant v])
          (make-mred-launcher
           (append
            (if addon? (addon-flags) null)
            '("-z"))
           (prep-dir
            (mred-program-launcher-path "gracket-text" #:user? user? #:addon? addon?))
           `([subsystem . console] [single-instance? . #f]
             [relative? . ,(not user?)]))))))
  ;; add a bin/gracket (in addition to lib/gracket)
  (for ([vs '((script-3m 3m) (script-cgc cgc))])
    (let ([v (findf (lambda (v) (memq v variants)) vs)])
      (when v
        (parameterize ([current-launcher-variant v])
          (make-mred-launcher (if addon? (addon-flags) null)
                              (prep-dir
                               (mred-program-launcher-path "GRacket" #:user? user? #:addon? addon?))
                              `([exe-name . "GRacket"] [relative? . ,(not user?)]
                                [exe-is-gracket . #t])))))))

(define (prep-dir p)
  (define dir (path-only p))
  (make-directory* dir)
  p)

(define (addon-flags)
  (list "-A" (path->string (find-system-path 'addon-dir))))
