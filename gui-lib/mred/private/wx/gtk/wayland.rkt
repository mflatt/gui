#lang racket/base
(require ffi/unsafe
         ffi/unsafe/define
         "types.rkt"
         "utils.rkt")

(provide wayland-get-subcompositor
	 wayland-compositor-create-surface
	 wayland-subcompositor-get-subsurface
	 wayland-subsurface-set-position
	 wayland-subsurface-set-sync
	 wayland-surface-commit
	 wayland-roundtrip
	 wayland-display-dispatch-pending
	 wayland-register-surface-frame-callback)

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

(define-cstruct _wl_frame_listener ([handle (_fun #:atomic? #t
						  _pointer ; data
						  _pointer ; callback
						  _uint32  ; time
						  -> _void)])
  #:malloc-mode 'atomic-interior)

(define WL_DISPLAY_GET_REGISTRY 1)
(define WL_REGISTRY_BIND 0)
(define WL_COMPOSITOR_CREATE_SURFACE 0)
(define WL_SUBCOMPOSITOR_GET_SUBSURFACE 1)
(define WL_SUBSURFACE_SET_POSITION 1)
(define WL_SUBSURFACE_SET_SYNC 4)
(define WL_SUBSURFACE_SET_DESYNC 5)
(define WL_SURFACE_FRAME 3)
(define WL_SURFACE_COMMIT 6)

(define _registry (_cpointer/null 'wl_registry))

(define-wayland wl_registry_interface _fpointer) ; really a struct address
(define-wayland wl_subcompositor_interface _fpointer)
(define-wayland wl_surface_interface _fpointer)
(define-wayland wl_subsurface_interface _fpointer)
(define-wayland wl_callback_interface _fpointer)

(define-wayland wl_display_roundtrip
  (_fun _pointer -> _int))
(define-wayland wl_display_dispatch_pending
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
(define-wayland wl_proxy_marshal_flags/wl_subcompositor_set_position
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	_int32 _int32
	-> _pointer)
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_marshal_flags/wl_subsurface_set_position
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	_int32 _int32
	-> _pointer
	-> (void))
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_marshal_flags/wl_subsurface_set_sync
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	-> _pointer
	-> (void))
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_marshal_flags/wl_surface_commit
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	-> _pointer
	-> (void))
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_marshal_flags/wl_surface_frame
  (_fun #:varargs-after 5
	_pointer _uint32 _pointer _uint32
	_uint32
	_pointer
	-> _pointer)
  #:c-id wl_proxy_marshal_flags)
(define-wayland wl_proxy_add_listener
  (_fun _pointer _pointer _pointer -> _void))
(define-wayland wl_proxy_get_version (_fun _pointer -> _uint32))

(define subcompositor #f)

(define (handle-callback data registry id interface version)
  (when (equal? interface "wl_subcompositor")
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

(define cached-subcompositor #f)

(define (wayland-get-subcompositor display)
  (unless cached-subcompositor
    (define registry (wl_proxy_marshal_constructor/wl_display_get_registry
		      display
		      WL_DISPLAY_GET_REGISTRY
		      wl_registry_interface
		      #f))
    (define l (make-wl_registry_listener handle-callback remove-callback))
    (wl_proxy_add_listener registry l #f)
    (wl_display_roundtrip display)
    (void/reference-sink l)
    (set! cached-subcompositor subcompositor))
  cached-subcompositor)

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

(define (wayland-subsurface-set-position subsurface x y)
  (wl_proxy_marshal_flags/wl_subsurface_set_position
   subsurface
   WL_SUBSURFACE_SET_POSITION
   #f (wl_proxy_get_version subsurface)
   0
   x y))

(define (wayland-subsurface-set-sync subsurface on?)
  (wl_proxy_marshal_flags/wl_subsurface_set_sync
   subsurface
   (if on? WL_SUBSURFACE_SET_SYNC WL_SUBSURFACE_SET_DESYNC)
   #f (wl_proxy_get_version subsurface)
   0))

(define (wayland-surface-commit surface)
  (wl_proxy_marshal_flags/wl_surface_commit
   surface
   WL_SURFACE_COMMIT
   #f (wl_proxy_get_version surface)
   0))

(define (wayland-roundtrip display)
  (wl_display_roundtrip display))
(define (wayland-display-dispatch-pending display)
  (wl_display_roundtrip display))


(define (wayland-register-surface-frame-callback surface callback)
  (define frame (wl_proxy_marshal_flags/wl_surface_frame
		 surface
		 WL_SURFACE_FRAME
		 wl_callback_interface (wl_proxy_get_version surface)
		 0
		 #f))
  (define l (make-wl_frame_listener callback))
  (wl_proxy_add_listener frame l #f)
  l)
