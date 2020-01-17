#lang racket/base
(require ffi/unsafe
         ffi/unsafe/alloc
         "utils.rkt"
         "const.rkt"
         "types.rkt"
         "font.rkt")

(provide
 (protect-out get-theme-logfont
              get-theme-font-face
              get-theme-font-size
              OpenThemeData
              CloseThemeData
              DrawThemeParentBackground
              DrawThemeBackground
              DrawThemeEdge
              EnableThemeDialogTexture
	      enable-dark-mode
	      enable-frame-dark-mode))

(define _HTHEME (_cpointer 'HTHEME))

(define-uxtheme CloseThemeData (_wfun _HTHEME -> (r : _HRESULT)
				      -> (when (negative? r)
					   (error 'CloseThemeData "failed: ~s" (bitwise-and #xFFFF r))))
  #:wrap (deallocator))
(define (maybe-CloseThemeData v) (when v (CloseThemeData v)))
(define-uxtheme OpenThemeData (_wfun _HWND _string/utf-16 -> (_or-null _HTHEME))
  #:wrap (allocator maybe-CloseThemeData))

(define-uxtheme GetThemeFont (_wfun _HTHEME _HDC _int _int _int (f : (_ptr o _LOGFONTW))
				    -> (r : _HRESULT)
				    -> (if (negative? r) 
					   (error 'GetThemeFont "failed: ~s" (bitwise-and #xFFFF r))
					   f)))

(define-uxtheme GetThemeSysFont(_wfun (_or-null _HTHEME) _int (f : (_ptr o _LOGFONTW))
				      -> (r : _HRESULT)
				      -> (if (negative? r) 
					     (error 'GetThemeSysFont "failed: ~s" (bitwise-and #xFFFF r))
					     f)))

(define-uxtheme DrawThemeBackground (_wfun _HTHEME _HDC _int _int _RECT-pointer (_or-null _RECT-pointer) -> (r : _HRESULT)
                                           -> (when (negative? r)
                                                (error 'DrawThemeBackground "failed: ~s" (bitwise-and #xFFFF r)))))
(define-uxtheme DrawThemeParentBackground (_wfun _HWND _HDC _pointer -> (r : _HRESULT)
                                                 -> (when (negative? r)
                                                      (error 'DrawThemeParentBackground "failed: ~s" (bitwise-and #xFFFF r)))))
(define-uxtheme DrawThemeEdge (_wfun _HWND _HDC _int _int _RECT-pointer _int _int _RECT-pointer -> (r : _HRESULT)
                                     -> (when (negative? r)
                                          (error 'DrawThemeEdge "failed: ~s" (bitwise-and #xFFFF r)))))

(define-uxtheme EnableThemeDialogTexture (_wfun _HWND _DWORD -> (r : _HRESULT)
                                                -> (when (negative? r)
                                                     (error 'EnableThemeDialogTexture "failed: ~s" (bitwise-and #xFFFF r)))))

(define-uxtheme SetWindowTheme (_wfun _HWND _string/utf-16 _pointer -> (r : _HRESULT)
				      -> (when (negative? r)
                                           (error 'SetWindowTheme "failed: ~s" (bitwise-and #xFFFF r)))))

(define-kernel32 LoadLibraryW (_wfun _string/utf-16 -> _pointer))
(define-kernel32 GetProcAddress (_wfun _pointer _intptr -> _pointer))

(define ShouldAppUseDarkMode
  (let ([p (GetProcAddress (LoadLibraryW "uxtheme.dll") 132)])
    (if p
	(cast p _pointer (_wfun -> _bool))
	(lambda () #f))))

(define-dwmapi DwmSetWindowAttribute
  (_wfun _HWND _DWORD _pointer _DWORD -> _HRESULT))

(define DWMWA_USE_IMMERSIVE_DARK_MODE 19)
(define DWMWA_USE_IMMERSIVE_DARK_MODE_NEW 20)

(define (enable-dark-mode hwnd)
  (when (ShouldAppUseDarkMode)
    (SetWindowTheme hwnd "DarkMode_Explorer" #f)))

(define (enable-frame-dark-mode hwnd)
  (when (ShouldAppUseDarkMode)
    (let ([on (malloc _BOOL)])
      (ptr-set! on _BOOL #t)
      (when (negative? (DwmSetWindowAttribute hwnd DWMWA_USE_IMMERSIVE_DARK_MODE_NEW on (ctype-sizeof _BOOL)))
	(DwmSetWindowAttribute hwnd DWMWA_USE_IMMERSIVE_DARK_MODE on (ctype-sizeof _BOOL))))))
  
(define BP_PUSHBUTTON 1)
(define PBS_NORMAL 1)
(define TMT_FONT 210)
(define TMT_BODYFONT 809)

(define TMT_MSGBOXFONT 805)

(define theme-logfont (GetThemeSysFont #f TMT_MSGBOXFONT))

(define (get-theme-logfont)
  theme-logfont)

(define (get-theme-font-face)
  (cast (array-ptr (LOGFONTW-lfFaceName theme-logfont)) _pointer _string/utf-16))

(define (get-theme-font-size)
  (abs (LOGFONTW-lfHeight theme-logfont)))
