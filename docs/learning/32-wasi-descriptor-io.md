# 32 — WASI Descriptor I/O

WASI Preview 1 models standard input, output, and error as file descriptors:

```text
0 = stdin
1 = stdout
2 = stderr
```

PRD 5 needs `fd_read` for stdin and `fd_write` for stdout and stderr.

## Iovecs

Both calls use an array of I/O vectors. In a 32-bit WASI command module, one
iovec contains:

```text
offset +0: buffer pointer (u32)
offset +4: buffer length  (u32)
```

An iovec is therefore eight bytes. An array allows one call to read into or
write from several separate buffers.

The first SDK can use one iovec per call while still generating the correct
array-based ABI.

## Writing

Conceptually, `fd_write` receives:

```text
fd_write(fd, iovecPointer, iovecCount, bytesWrittenPointer) → errno
```

A write operation should:

1. Put the data pointer and length into an iovec.
2. Set the descriptor to `1` for stdout or `2` for stderr.
3. Call `fd_write`.
4. Check the returned errno.
5. Read the number of bytes written.
6. Repeat for any unwritten suffix when the API promises a complete write.

Success does not guarantee that every requested byte was written. Ignoring the
reported byte count can silently truncate output.

## Reading

Conceptually, `fd_read` receives:

```text
fd_read(fd, iovecPointer, iovecCount, bytesReadPointer) → errno
```

A read operation should:

1. Reserve a bounded destination buffer.
2. Put its pointer and capacity into an iovec.
3. Call `fd_read` with descriptor `0`.
4. Check the returned errno.
5. Read the number of bytes received.
6. Treat zero bytes as end-of-file.
7. Repeat only when the selected SDK operation requires more input.

`readAll` must stop at EOF or at a documented size limit. It must not assume
that one `fd_read` returns all available input.

## Echo flow

The PRD 5 echo fixture should exercise the complete path:

```text
host stdin bytes
→ fd_read
→ guest linear memory
→ runtime byte/text value
→ fd_write on stdout
→ host-captured stdout bytes
```

Copying a constant into output would not test stdin support.

## Errno is not a trap

WASI functions return an errno value for ordinary failures such as an invalid
descriptor. This is different from a WebAssembly trap caused by invalid memory
access or an unreachable instruction.

The SDK must define whether an errno:

- Becomes a guest-visible result.
- Causes a documented guest exit code.
- Becomes a generated trap.

The first version may choose a small policy, but it must not silently discard
errors.

## Binary versus text I/O

Descriptor I/O moves raw bytes. A text operation adds UTF-8 behavior on top.
Keeping those layers separate makes invalid UTF-8 and exact byte echo tests
possible.

## Learning checkpoint

Implement and test in this order:

1. Constant stdout through descriptor `1`.
2. Constant stderr through descriptor `2`.
3. One bounded stdin read through descriptor `0`.
4. EOF handling.
5. Partial write handling.
6. Repeated reads for `readAll`.
7. Non-zero errno behavior.

## Why we need to know this

Descriptor I/O is the first dynamic WASI boundary in the guest compiler. Its
pointer, length, partial-operation, and error rules determine whether echo and
diagnostic output are correct.

## References

- [WASI Preview 1 `fd_read`](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md#-fd_readfd-fd-iovs-iovec_array---resultsize-errno)
- [WASI Preview 1 `fd_write`](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md#-fd_writefd-fd-iovs-ciovec_array---resultsize-errno)
