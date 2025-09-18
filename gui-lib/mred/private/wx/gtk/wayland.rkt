#lang racket/base
(require ffi/unsafe
         ffi/unsafe/define
         "types.rkt"
         "utils.rkt")

(provide wayland-get-subcompositor
	 wayland-compositor-create-surface
	 wayland-subcompositor-get-subsurface)

(define wayland-lib
  (ffi-lib "libwayland-client" '("1" "")))

(define-ffi-definer define-wayland wayland-lib)

(define-cstruct _wl_registry_listener ([handle (_fun #:atomic? #t
						     _pointer ; data
						     _pointer ; registry
						     _uint32  ; id
						     _string  ; interface
						     _uint32  ; version
						     -> _void)]
				       [remove (_fun #:atomic? #t
						     _pointer ; data
						     _pointer ; registry
						     _uint32  ; id
						     -> _void)])
  #:malloc-mode 'atomic-interior)

(define WL_DISPLAY_GET_REGISTRY 1)
(define WL_REGISTRY_BIND 0)
(define WL_COMPOSITOR_CREATE_SURFACE 0)
(define WL_SUBCOMPOSITOR_GET_SUBSURFACE 1)

(define _registry (_cpointer/null 'wl_registry))

(define-wayland wl_registry_interface _fpointer) ; really a struct address
(define-wayland wl_subcompositor_interface _fpointer)
(define-wayland wl_surface_interface _fpointer)
(define-wayland wl_subsurface_interface _fpointer)

(define-wayland wl_display_roundtrip
  (_fun _pointer -> _int))
(define-wayland wl_proxy_marshal_constructor/wl_display_get_registry
  (_fun #:varargs-after 3 _pointer _uint32 _pointer _pointer -> _registry)
  #:c-id wl_proxy_marshal_constructor)
(define-wayland wl_proxy_marshal_flags/wl_registry_bind
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	_uint32 _pointer _uint32
	_pointer
	-> _pointer)
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_marshal_flags/wl_compositor_create_surface
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	_pointer
	-> _pointer)
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_marshal_flags/wl_subcompositor_get_subsurface
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	_pointer
	_pointer _pointer
	-> _pointer)
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_add_listener
  (_fun _registry _wl_registry_listener-pointer _pointer -> _void))
(define-wayland wl_proxy_get_version (_fun _pointer -> _uint32))

(define subcompositor #f)

(define (handle-callback data registry id interface version)
  (when (equal? interface "wl_subcompositor")
    (log-error "match")
    (set! subcompositor (wl_proxy_marshal_flags/wl_registry_bind
			 registry
			 WL_REGISTRY_BIND
			 wl_subcompositor_interface 1
			 0
			 ;; name is immedieate member of an interface
			 id (ptr-ref wl_subcompositor_interface _pointer) 1
			 #f))))
(define (remove-callback data registry id)
  (void))

(define (wayland-get-subcompositor display)
  (define registry (wl_proxy_marshal_constructor/wl_display_get_registry
		    display
		    WL_DISPLAY_GET_REGISTRY
		    wl_registry_interface
		    #f))
  (define l (make-wl_registry_listener handle-callback remove-callback))
  (wl_proxy_add_listener registry l #f)
  (log-error "go")
  (wl_display_roundtrip display)
  (log-error "done")
  (void/reference-sink l)
  subcompositor)

(define (wayland-compositor-create-surface compositor)
  (wl_proxy_marshal_flags/wl_compositor_create_surface
   compositor
   WL_COMPOSITOR_CREATE_SURFACE
   wl_surface_interface (wl_proxy_get_version compositor)
   0
   #f))

(define (wayland-subcompositor-get-subsurface subcompositor child parent)
  (wl_proxy_marshal_flags/wl_subcompositor_get_subsurface
   subcompositor
   WL_SUBCOMPOSITOR_GET_SUBSURFACE
   wl_subsurface_interface (wl_proxy_get_version subcompositor)
   0
   #f child parent))
