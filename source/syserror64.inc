;-------------------------------------------------------------------------
;  file : syserror64.inc
;  2010/06/23
; Copyright (C) 2001-2010 Jun Mizutani <mizutani.jun@nifty.ne.jp>
; Read LICENSE file for full copyright information (GNU GPL)
;-------------------------------------------------------------------------

%include        "errno64.inc"

%ifdef  DEBUG
%include        "debug64.inc"
%endif

%ifndef __SYSERR_INC
%define __SYSERR_INC

;==============================================================
section .text

SysCallError:
                push    rax
                push    rbx
                push    rcx
                push    rdi
                or      rax, rax
                jns     .exit
                neg     rax
                mov     rbx, rax
                mov     ecx, num_sys_error
                shr     ecx, 4
                lea     rdi, [sys_error_tbl]
        .loop:
                cmp     bl, [rdi]
                jne     .next
                mov     eax, [rdi+1]
                lea     rax, [rax + msg_TOP]
                call    OutAsciiZ
                call    NewLine
                jmp     short .exit
        .next:
                lea     rdi, [rdi + 5]
                loop    .loop
                neg     rbx
                mov     rax, rbx
                call    PrintHex16
                call    NewLine
    .exit:
                pop     rdi
                pop     rcx
                pop     rbx
                pop     rax
                ret

;==============================================================
section .data

sys_error_tbl:
        db EPERM
        dd msg_EPERM - msg_TOP
        db ENOENT
        dd msg_ENOENT - msg_TOP
        db ESRCH
        dd msg_ESRCH - msg_TOP
        db EINTR
        dd msg_EINTR - msg_TOP
        db EIO
        dd msg_EIO - msg_TOP
        db ENXIO
        dd msg_ENXIO - msg_TOP
        db E2BIG
        dd msg_E2BIG - msg_TOP
        db ENOEXEC
        dd msg_ENOEXEC - msg_TOP
        db EBADF
        dd msg_EBADF - msg_TOP
        db ECHILD
        dd msg_ECHILD - msg_TOP
        db EAGAIN
        dd msg_EAGAIN - msg_TOP
        db ENOMEM
        dd msg_ENOMEM - msg_TOP
        db EACCES
        dd msg_EACCES - msg_TOP
        db EFAULT
        dd msg_EFAULT - msg_TOP
        db ENOTBLK
        dd msg_ENOTBLK - msg_TOP
        db EBUSY
        dd msg_EBUSY - msg_TOP
        db EEXIST
        dd msg_EEXIST - msg_TOP
        db EXDEV
        dd msg_EXDEV - msg_TOP
        db ENODEV
        dd msg_ENODEV - msg_TOP
        db ENOTDIR
        dd msg_ENOTDIR - msg_TOP
        db EISDIR
        dd msg_EISDIR - msg_TOP
        db EINVAL
        dd msg_EINVAL - msg_TOP
        db ENFILE
        dd msg_ENFILE - msg_TOP
        db EMFILE
        dd msg_EMFILE - msg_TOP
        db ENOTTY
        dd msg_ENOTTY - msg_TOP
        db ETXTBSY
        dd msg_ETXTBSY - msg_TOP
        db EFBIG
        dd msg_EFBIG - msg_TOP
        db ENOSPC
        dd msg_ENOSPC - msg_TOP
        db ESPIPE
        dd msg_ESPIPE - msg_TOP
        db EROFS
        dd msg_EROFS - msg_TOP
        db EMLINK
        dd msg_EMLINK - msg_TOP
        db EPIPE
        dd msg_EPIPE - msg_TOP
        db EDOM
        dd msg_EDOM - msg_TOP
        db ERANGE
        dd msg_ERANGE - msg_TOP
        db EDEADLK
        dd msg_EDEADLK - msg_TOP
        db ENAMETOOLONG
        dd msg_ENAMETOOLONG - msg_TOP
        db ENOLCK
        dd msg_ENOLCK - msg_TOP
        db ENOSYS
        dd msg_ENOSYS - msg_TOP
        db ENOTEMPTY
        dd msg_ENOTEMPTY - msg_TOP
        db ELOOP
        dd msg_ELOOP - msg_TOP
        db EWOULDBLOCK
        dd msg_EWOULDBLOCK - msg_TOP
        db ENOMSG
        dd msg_ENOMSG - msg_TOP
        db EIDRM
        dd msg_EIDRM - msg_TOP
        db ECHRNG
        dd msg_ECHRNG - msg_TOP
        db EL2NSYNC
        dd msg_EL2NSYNC - msg_TOP
        db EL3HLT
        dd msg_EL3HLT - msg_TOP
        db EL3RST
        dd msg_EL3RST - msg_TOP
        db ELNRNG
        dd msg_ELNRNG - msg_TOP
        db EUNATCH
        dd msg_EUNATCH - msg_TOP
        db ENOCSI
        dd msg_ENOCSI - msg_TOP
        db EL2HLT
        dd msg_EL2HLT - msg_TOP
        db EBADE
        dd msg_EBADE - msg_TOP
        db EBADR
        dd msg_EBADR - msg_TOP
        db EXFULL
        dd msg_EXFULL - msg_TOP
        db ENOANO
        dd msg_ENOANO - msg_TOP
        db EBADRQC
        dd msg_EBADRQC - msg_TOP
        db EBADSLT
        dd msg_EBADSLT - msg_TOP
;        dd EDEADLOCK      , msg_EDEADLOCK
        db EBFONT
        dq msg_EBFONT - msg_TOP
        db ENOSTR
        dd msg_ENOSTR - msg_TOP
        db ENODATA
        dd msg_ENODATA - msg_TOP
        db ETIME
        dd msg_ETIME - msg_TOP
        db ENOSR
        dd msg_ENOSR - msg_TOP
        db ENONET
        dd msg_ENONET - msg_TOP
        db ENOPKG
        dd msg_ENOPKG - msg_TOP
        db EREMOTE
        dd msg_EREMOTE - msg_TOP
        db ENOLINK
        dd msg_ENOLINK - msg_TOP
        db EADV
        dd msg_EADV - msg_TOP
        db ESRMNT
        dd msg_ESRMNT - msg_TOP
        db ECOMM
        dd msg_ECOMM - msg_TOP
        db EPROTO
        dd msg_EPROTO - msg_TOP
        db EMULTIHOP
        dd msg_EMULTIHOP - msg_TOP
        db EDOTDOT
        dd msg_EDOTDOT - msg_TOP
        db EBADMSG
        dd msg_EBADMSG - msg_TOP
        db EOVERFLOW
        dd msg_EOVERFLOW - msg_TOP
        db ENOTUNIQ
        dd msg_ENOTUNIQ - msg_TOP
        db EBADFD
        dd msg_EBADFD - msg_TOP
        db EREMCHG
        dd msg_EREMCHG - msg_TOP
        db ELIBACC
        dd msg_ELIBACC - msg_TOP
        db ELIBBAD
        dd msg_ELIBBAD - msg_TOP
        db ELIBSCN
        dd msg_ELIBSCN - msg_TOP
        db ELIBMAX
        dd msg_ELIBMAX - msg_TOP
        db ELIBEXEC
        dd msg_ELIBEXEC - msg_TOP
        db EILSEQ
        dd msg_EILSEQ - msg_TOP
        db ERESTART
        dd msg_ERESTART - msg_TOP
        db ESTRPIPE
        dd msg_ESTRPIPE - msg_TOP
        db EUSERS
        dd msg_EUSERS - msg_TOP
        db ENOTSOCK
        dd msg_ENOTSOCK - msg_TOP
        db EDESTADDRREQ
        dd msg_EDESTADDRREQ - msg_TOP
        db EMSGSIZE
        dd msg_EMSGSIZE - msg_TOP
        db EPROTOTYPE
        dd msg_EPROTOTYPE - msg_TOP
        db ENOPROTOOPT
        dd msg_ENOPROTOOPT - msg_TOP
        db EPROTONOSUPPORT
        dd msg_EPROTONOSUPPORT - msg_TOP
        db ESOCKTNOSUPPORT
        dd msg_ESOCKTNOSUPPORT - msg_TOP
        db EOPNOTSUPP
        dd msg_EOPNOTSUPP - msg_TOP
        db EPFNOSUPPORT
        dd msg_EPFNOSUPPORT - msg_TOP
        db EAFNOSUPPORT
        dd msg_EAFNOSUPPORT - msg_TOP
        db EADDRINUSE
        dd msg_EADDRINUSE - msg_TOP
        db EADDRNOTAVAIL
        dd msg_EADDRNOTAVAIL - msg_TOP
        db ENETDOWN
        dd msg_ENETDOWN - msg_TOP
        db ENETUNREACH
        dd msg_ENETUNREACH - msg_TOP
        db ENETRESET
        dd msg_ENETRESET - msg_TOP
        db ECONNABORTED
        dd msg_ECONNABORTED - msg_TOP
        db ECONNRESET
        dd msg_ECONNRESET - msg_TOP
        db ENOBUFS
        dd msg_ENOBUFS - msg_TOP
        db EISCONN
        dd msg_EISCONN - msg_TOP
        db ENOTCONN
        dd msg_ENOTCONN - msg_TOP
        db ESHUTDOWN
        dd msg_ESHUTDOWN - msg_TOP
        db ETOOMANYREFS
        dd msg_ETOOMANYREFS - msg_TOP
        db ETIMEDOUT
        dd msg_ETIMEDOUT - msg_TOP
        db ECONNREFUSED
        dd msg_ECONNREFUSED - msg_TOP
        db EHOSTDOWN
        dd msg_EHOSTDOWN - msg_TOP
        db EHOSTUNREACH
        dd msg_EHOSTUNREACH - msg_TOP
        db EALREADY
        dd msg_EALREADY - msg_TOP
        db EINPROGRESS
        dd msg_EINPROGRESS - msg_TOP
        db ESTALE
        dd msg_ESTALE - msg_TOP
        db EUCLEAN
        dd msg_EUCLEAN - msg_TOP
        db ENOTNAM
        dd msg_ENOTNAM - msg_TOP
        db ENAVAIL
        dd msg_ENAVAIL - msg_TOP
        db EISNAM
        dd msg_EISNAM - msg_TOP
        db EREMOTEIO
        dd msg_EREMOTEIO - msg_TOP
        db EDQUOT
        dd msg_EDQUOT - msg_TOP
        db ENOMEDIUM
        dd msg_ENOMEDIUM - msg_TOP
        db EMEDIUMTYPE
        dd msg_EMEDIUMTYPE - msg_TOP
        db ECANCELED
        dd msg_ECANCELED - msg_TOP
        db ENOKEY
        dd msg_ENOKEY - msg_TOP
        db EKEYEXPIRED
        dd msg_EKEYEXPIRED - msg_TOP
        db EKEYREVOKED
        dd msg_EKEYREVOKED - msg_TOP
        db EKEYREJECTED
        dd msg_EKEYREJECTED - msg_TOP
        db EOWNERDEAD
        dd msg_EOWNERDEAD - msg_TOP
        db ENOTRECOVERABLE
        dd msg_ENOTRECOVERABLE - msg_TOP

num_sys_error   equ  $ - sys_error_tbl
msg_TOP:             db 0
msg_EPERM:           db "[EPERM] Operation not permitted",0
msg_ENOENT:          db "[ENOENT] No such file or directory",0
msg_ESRCH:           db "[ESRCH] No such process",0
msg_EINTR:           db "[EINTR] Interrupted system call",0
msg_EIO:             db "[EIO] I/O error",0
msg_ENXIO:           db "[ENXIO] No such device or address",0
msg_E2BIG:           db "[E2BIG] Argument list too long",0
msg_ENOEXEC:         db "[ENOEXEC] Exec format error",0
msg_EBADF:           db "[EBADF] Bad file number",0
msg_ECHILD:          db "[ECHILD] No child processes",0
msg_EAGAIN:          db "[EAGAIN] Try again",0
msg_ENOMEM:          db "[ENOMEM] Out of memory",0
msg_EACCES:          db "[EACCES] Permission denied",0
msg_EFAULT:          db "[EFAULT] Bad address",0
msg_ENOTBLK:         db "[ENOTBLK] Block device required",0
msg_EBUSY:           db "[EBUSY] Device or resource busy",0
msg_EEXIST:          db "[EEXIST] File exists",0
msg_EXDEV:           db "[EXDEV] Cross-device link",0
msg_ENODEV:          db "[ENODEV] No such device",0
msg_ENOTDIR:         db "[ENOTDIR] Not a directory",0
msg_EISDIR:          db "[EISDIR] Is a directory",0
msg_EINVAL:          db "[EINVAL] Invalid argument",0
msg_ENFILE:          db "[ENFILE] File table overflow",0
msg_EMFILE:          db "[EMFILE] Too many open files",0
msg_ENOTTY:          db "[ENOTTY] Not a typewriter",0
msg_ETXTBSY:         db "[ETXTBSY] Text file busy",0
msg_EFBIG:           db "[EFBIG] File too large",0
msg_ENOSPC:          db "[ENOSPC] No space left on device",0
msg_ESPIPE:          db "[ESPIPE] Illegal seek",0
msg_EROFS:           db "[EROFS] Read-only file system",0
msg_EMLINK:          db "[EMLINK] Too many links",0
msg_EPIPE:           db "[EPIPE] Broken pipe",0
msg_EDOM:            db "[EDOM] Math argument out of domain of func",0
msg_ERANGE:          db "[ERANGE] Math result not representable",0
msg_EDEADLK:         db "[EDEADLK] Resource deadlock would occur",0
msg_ENAMETOOLONG:    db "[ENAMETOOLONG] File name too long",0
msg_ENOLCK:          db "[ENOLCK] No record locks available",0
msg_ENOSYS:          db "[ENOSYS] Function not implemented",0
msg_ENOTEMPTY:       db "[ENOTEMPTY] Directory not empty",0
msg_ELOOP:           db "[ELOOP] Too many symbolic links encountered",0
msg_EWOULDBLOCK:     db "[EWOULDBLOCK]; Operation would block",0
msg_ENOMSG:          db "[ENOMSG] No message of desired type",0
msg_EIDRM:           db "[EIDRM] Identifier removed",0
msg_ECHRNG:          db "[ECHRNG] Channel number out of range",0
msg_EL2NSYNC:        db "[EL2NSYNC] Level 2 not synchronized",0
msg_EL3HLT:          db "[EL3HLT] Level 3 halted",0
msg_EL3RST:          db "[EL3RST] Level 3 reset",0
msg_ELNRNG:          db "[ELNRNG] Link number out of range",0
msg_EUNATCH:         db "[EUNATCH] Protocol driver not attached",0
msg_ENOCSI:          db "[ENOCSI] No CSI structure available",0
msg_EL2HLT:          db "[EL2HLT] Level 2 halted",0
msg_EBADE:           db "[EBADE] Invalid exchange",0
msg_EBADR:           db "[EBADR] Invalid request descriptor",0
msg_EXFULL:          db "[EXFULL] Exchange full",0
msg_ENOANO:          db "[ENOANO] No anode",0
msg_EBADRQC:         db "[EBADRQC] Invalid request code",0
msg_EBADSLT:         db "[EBADSLT] Invalid slot",0
msg_EBFONT:          db "[EBFONT] Bad font file format",0
msg_ENOSTR:          db "[ENOSTR] Device not a stream",0
msg_ENODATA:         db "[ENODATA] No data available",0
msg_ETIME:           db "[ETIME] Timer expired",0
msg_ENOSR:           db "[ENOSR] Out of streams resources",0
msg_ENONET:          db "[ENONET] Machine is not on the network",0
msg_ENOPKG:          db "[ENOPKG] Package not installed",0
msg_EREMOTE:         db "[EREMOTE] Object is remote",0
msg_ENOLINK:         db "[ENOLINK] Link has been severed",0
msg_EADV:            db "[EADV] Advertise error",0
msg_ESRMNT:          db "[ESRMNT] Srmount error",0
msg_ECOMM:           db "[ECOMM] Communication error on send",0
msg_EPROTO:          db "[EPROTO] Protocol error",0
msg_EMULTIHOP:       db "[EMULTIHOP] Multihop attempted",0
msg_EDOTDOT:         db "[EDOTDOT] RFS specific error",0
msg_EBADMSG:         db "[EBADMSG] Not a data message",0
msg_EOVERFLOW:       db "[EOVERFLOW] Value too large for defined data type",0
msg_ENOTUNIQ:        db "[ENOTUNIQ] Name not unique on network",0
msg_EBADFD:          db "[EBADFD] File descriptor in bad state",0
msg_EREMCHG:         db "[EREMCHG] Remote address changed",0
msg_ELIBACC:         db "[ELIBACC] Can not access a needed shared library",0
msg_ELIBBAD:         db "[ELIBBAD] Accessing a corrupted shared library",0
msg_ELIBSCN:         db "[ELIBSCN] .lib section in a.out corrupted",0
msg_ELIBMAX:         db "[ELIBMAX] Attempting to link in too many shared libraries",0
msg_ELIBEXEC:        db "[ELIBEXEC] Cannot exec a shared library directly",0
msg_EILSEQ:          db "[EILSEQ] Illegal byte sequence",0
msg_ERESTART:        db "[ERESTART] Interrupted system call should be restarted",0
msg_ESTRPIPE:        db "[ESTRPIPE] Streams pipe error",0
msg_EUSERS:          db "[EUSERS] Too many users",0
msg_ENOTSOCK:        db "[ENOTSOCK] Socket operation on non-socket",0
msg_EDESTADDRREQ:    db "[EDESTADDRREQ] Destination address required",0
msg_EMSGSIZE:        db "[EMSGSIZE] Message too long",0
msg_EPROTOTYPE:      db "[EPROTOTYPE] Protocol wrong type for socket",0
msg_ENOPROTOOPT:     db "[ENOPROTOOPT] Protocol not available",0
msg_EPROTONOSUPPORT: db "[EPROTONOSUPPORT] Protocol not supported",0
msg_ESOCKTNOSUPPORT: db "[ESOCKTNOSUPPORT] Socket type not supported",0
msg_EOPNOTSUPP:      db "[EOPNOTSUPP] Operation not supported on transport endpoint",0
msg_EPFNOSUPPORT:    db "[EPFNOSUPPORT] Protocol family not supported",0
msg_EAFNOSUPPORT:    db "[EAFNOSUPPORT] Address family not supported by protocol",0
msg_EADDRINUSE:      db "[EADDRINUSE] Address already in use",0
msg_EADDRNOTAVAIL:   db "[EADDRNOTAVAIL] Cannot assign requested address",0
msg_ENETDOWN:        db "[ENETDOWN] Network is down",0
msg_ENETUNREACH:     db "[ENETUNREACH] Network is unreachable",0
msg_ENETRESET:       db "[ENETRESET] Network dropped connection because of reset",0
msg_ECONNABORTED:    db "[ECONNABORTED] Software caused connection abort",0
msg_ECONNRESET:      db "[ECONNRESET] Connection reset by peer",0
msg_ENOBUFS:         db "[ENOBUFS] No buffer space available",0
msg_EISCONN:         db "[EISCONN] Transport endpoint is already connected",0
msg_ENOTCONN:        db "[ENOTCONN] Transport endpoint is not connected",0
msg_ESHUTDOWN:       db "[ESHUTDOWN] Cannot send after transport endpoint shutdown",0
msg_ETOOMANYREFS:    db "[ETOOMANYREFS] Too many references: cannot splice",0
msg_ETIMEDOUT:       db "[ETIMEDOUT] Connection timed out",0
msg_ECONNREFUSED:    db "[ECONNREFUSED] Connection refused",0
msg_EHOSTDOWN:       db "[EHOSTDOWN] Host is down",0
msg_EHOSTUNREACH:    db "[EHOSTUNREACH] No route to host",0
msg_EALREADY:        db "[EALREADY] Operation already in progress",0
msg_EINPROGRESS:     db "[EINPROGRESS] Operation now in progress",0
msg_ESTALE:          db "[ESTALE] Stale NFS file handle",0
msg_EUCLEAN:         db "[EUCLEAN] Structure needs cleaning",0
msg_ENOTNAM:         db "[ENOTNAM] Not a XENIX named type file",0
msg_ENAVAIL:         db "[ENAVAIL] No XENIX semaphores available",0
msg_EISNAM:          db "[EISNAM] Is a named type file",0
msg_EREMOTEIO:       db "[EREMOTEIO] Remote I/O error",0
msg_EDQUOT:          db "[EDQUOT] Quota exceeded",0
msg_ENOMEDIUM:       db "[ENOMEDIUM] No medium found",0
msg_EMEDIUMTYPE:     db "[EMEDIUMTYPE] Wrong medium type",0
msg_ECANCELED:       db "[ECANCELED] Operation Canceled",0
msg_ENOKEY:          db "[ENOKEY] Required key not available",0
msg_EKEYEXPIRED:     db "[EKEYEXPIRED] Key has expired",0
msg_EKEYREVOKED:     db "[EKEYREVOKED] Key has been revoked",0
msg_EKEYREJECTED:    db "[EKEYREJECTED] Key was rejected by service",0
msg_EOWNERDEAD:      db "[EOWNERDEAD] Owner died",0
msg_ENOTRECOVERABLE: db "[ENOTRECOVERABLE] State not recoverable",0

%endif
