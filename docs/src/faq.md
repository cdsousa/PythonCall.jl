# FAQ & Troubleshooting

## Heap corruption when using PyTorch ([issue 215](https://github.com/cjdoris/PythonCall.jl/issues/215))

On some systems, you may see an error like the following when using `torch` and `juliacall`:
```text
Python(65251,0x104cf8580) malloc: Heap corruption detected, free list is damaged at 0x600001c17280
*** Incorrect guard value: 1903002876
Python(65251,0x104cf8580) malloc: *** set a breakpoint in malloc_error_break to debug
[1]    65251 abort      ipython
```

A solution is to ensure that `juliacall` is imported before `torch`.

## Multi-threading

The golden rule is that you **must not** call into Python from any thread other than 1.

Unfortunately, even if you do not explicitly call any Python code, it is still possible for
Julia's garbage collector to try to free a Python object while your multithreaded code is
running. To prevent this from occurring, you must guard any multithreaded code with the
following pattern:
```
PythonCall.GC.disable()
try
    # Some multithreaded code.
    # It is OK to call Python from thread 1 only.
finally
    PythonCall.GC.enable()
end
```
