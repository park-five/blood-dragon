.arch armv8-a

.macro string name, value
	string.\name: .ascii "\value"
	string.length.\name = . - string.\name
.endm

.macro string.length string, length, character
	set \length, 0
	0:
		load.byte \character, \string, \length
		if eq \character, 0, 0f
		increment \length, 1
		branch 0b
	0:
.endm

.macro data y, x
	adr \y, \x
.endm

.macro branch x
	b \x
.endm

.macro set y, x
	mov \y, \x
.endm

.macro increment y, a, b=undefined
	.ifc \b,undefined
		increment \y, \y, \a
	.else
		add \y, \a, \b
	.endif
.endm

.macro decrement y, a, b=undefined
	.ifc \b,undefined
		decrement \y, \y, \a
	.else
		sub \y, \a, \b
	.endif
.endm

.macro multiply y, a, b=undefined
	.ifc \b,undefined
		multiply \y, \y, \a
	.else
		mul \y, \a, \b
	.endif
.endm

.macro divide.unsigned y, a, b=undefined
	.ifc \b,undefined
		udiv \y, \y, \a
	.else
		udiv \y, \a, \b
	.endif
.endm

.macro divide.signed y, a, b=undefined
	.ifc \b,undefined
		sdiv \y, \y, \a
	.else
		sdiv \y, \a, \b
	.endif
.endm


.macro load y, x, i=0
	ldr \y, [\x, \i]
.endm

.macro load.byte y, x, i=0
	ldrb \y, [\x, \i]
.endm

.macro store y, x, i=0
	str \y, [\x, \i]
.endm

.macro store.byte y, x, i=0
	str \y, [\x, \i]
.endm

alignment.stack = 16
alignment.heap = 4096

.macro push x
	increment sp, alignment.stack
	store \x, sp
.endm

.macro pop x
	load \x, sp
	decrement sp, alignment.stack
.endm

.macro if f a, b, c
	cmp \a, \b
	b\f \c
.endm

.macro linux.overload x
	set x8, \x
.endm

.macro linux.call x=undefined
	.ifnc \x,undefined
		linux.overload \x
	.endif
	svc 0
.endm

linux.openat = 56
linux.close = 57
linux.lseek = 62
linux.read = 63
linux.write = 64
linux.exit = 93
linux.munmap = 215
linux.mmap = 222

linux.STDIN_FILENO = 0
linux.STDOUT_FILENO = 1
linux.STDERR_FILENO = 2

linux.AT_FDCWD = -100

linux.O_RDONLY = 0

linux.SEEK_SET = 0
linux.SEEK_END = 2

linux.PROT_READ = 1
linux.PROT_WRITE = 2

linux.MAP_PRIVATE = 2
linux.MAP_ANONYMOUS = 32

.macro linux.write.data file, value, error
	set x0, \file
	data x1, string.\value
	set x2, string.length.\value
	linux.call linux.write
	if ne x0, x2, \error
.endm

success = 0
failure = 1

.section .rodata
	string space, " "
	string line, "\n"
	string colon, ":"
	string error, "error"
	string no, "no"
	string invalid, "invalid"
	string file, "file"
	string arguments, "arguments"
	string memory, "memory"

.section .text
	.global stack
	stack:
		load x0, sp
		if lt x0, 2, error.no_arguments
		set x0, linux.AT_FDCWD
		load x1, sp, 16
		set x2, linux.O_RDONLY
		set x3, 0
		linux.call linux.openat
		if lt x0, 0, error.no_file
		store x0, sp, -8
		linux.overload linux.lseek
		set x1, 0
		set x2, linux.SEEK_END
		linux.call
		if lt x0, 0, error.invalid_file
		store x0, sp, -16
		load x0, sp, -8
		set x1, 0
		set x2, linux.SEEK_SET
		linux.call
		if lt x0, 0, error.invalid_file
		load x0, sp, -16
		set x1, alignment.heap
		divide.unsigned x0, x1
		multiply x0, x1
		decrement x1, x0
		load x0, sp, -16
		increment x1, x0
		set x0, 0
		set x2, linux.PROT_READ | linux.PROT_WRITE
		set x3, linux.MAP_PRIVATE | linux.MAP_ANONYMOUS
		set x4, -1
		set x5, 0
		linux.call linux.mmap
		if lt x0, 0, error.no_memory
		store x0, sp, -24
		store x1, sp, -32
		set x1, x0
		load x0, sp, -8
		load x2, sp, -16
		linux.call linux.read
		if ne x0, x2, error.invalid_file
		load x0, sp, -8
		linux.call linux.close
		if lt x0, 0, error.invalid_file
		load x0, sp, -24
		store x0, sp, -8
		load x0, sp, -32
		store x0, sp, -24
		set x0, linux.STDOUT_FILENO
		linux.call linux.write
		if ne x0, x2, error.invalid_file
		load x0, sp, -8
		load x1, sp, -24
		linux.call linux.munmap
		if ne x0, 0, error.invalid_memory
		set x0, success
		linux.call linux.exit

	.macro error.file.string
		load x1, sp, 16
		string.length x1, x2, w0
		set x0, linux.STDERR_FILENO
		linux.call linux.write
		if ne x0, x2, error.undefined
	.endm
	error.undefined:
		b error.undefined
	error.no_arguments:
		linux.write.data linux.STDERR_FILENO, error, error.undefined
		linux.write.data linux.STDERR_FILENO, colon, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, no, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, arguments, error.undefined
		linux.write.data linux.STDERR_FILENO, line, error.undefined
		branch error.exit
	error.no_file:
		linux.write.data linux.STDERR_FILENO, error, error.undefined
		linux.write.data linux.STDERR_FILENO, colon, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, no, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, file, error.undefined
		linux.write.data linux.STDERR_FILENO, colon, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		error.file.string
		linux.write.data linux.STDERR_FILENO, line, error.undefined
		branch error.exit
	error.invalid_file:
		linux.write.data linux.STDERR_FILENO, error, error.undefined
		linux.write.data linux.STDERR_FILENO, colon, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, invalid, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, file, error.undefined
		linux.write.data linux.STDERR_FILENO, colon, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		error.file.string
		linux.write.data linux.STDERR_FILENO, line, error.undefined
		branch error.file
	error.no_memory:
		linux.write.data linux.STDERR_FILENO, error, error.undefined
		linux.write.data linux.STDERR_FILENO, colon, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, no, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, memory, error.undefined
		linux.write.data linux.STDERR_FILENO, line, error.undefined
		branch error.file
	error.invalid_memory:
		linux.write.data linux.STDERR_FILENO, error, error.undefined
		linux.write.data linux.STDERR_FILENO, colon, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, invalid, error.undefined
		linux.write.data linux.STDERR_FILENO, space, error.undefined
		linux.write.data linux.STDERR_FILENO, memory, error.undefined
		linux.write.data linux.STDERR_FILENO, line, error.undefined
		branch error.file
	error.file:
		load x0, sp, -8
		linux.call linux.close
		if lt x0, 0, error.undefined
		branch error.exit
	error.exit:
	set x0, failure
	linux.call linux.exit
