"""
Garbarge collection of Python objects.

See `disable` and `enable`.
"""
module GC

import ..PythonCall.C

const LOCK = Base.Threads.SpinLock()
const ENABLED = Ref(true)
const QUEUE = C.PyPtr[]

"""
    PythonCall.GC.disable()

Disable the PythonCall garbage collector.

This means that whenever a Python object owned by Julia is finalized, it is not immediately
freed but is instead added to a queue of objects to free later when `enable()` is called.

Like most PythonCall functions, you must only call this from the main thread.
"""
function disable()
    ENABLED[] = false
    return
end

"""
    PythonCall.GC.enable()

Re-enable the PythonCall garbage collector.

This frees any Python objects which were finalized while the GC was disabled, and allows
objects finalized in the future to be freed immediately.

Like most PythonCall functions, you must only call this from the main thread.
"""
function enable()
    ENABLED[] = true
    gc()
    return
end

function _gc()
    if !isempty(QUEUE)
        C.with_gil(false) do
            for ptr in QUEUE
                if ptr != C.PyNULL
                    C.Py_DecRef(ptr)
                end
            end
        end
        empty!(QUEUE)
    end
    return
end

"""
    PythonCall.GC.gc()

Free any Python objects waiting to be freed.

These are Python objects which were GC'd but not from the main thread, or were GC'd while
PythonCall's GC is disabled.

You do not normally need to call this, since it will happen automatically when a Python
object is freed on the main thread or PythonCall's GC is enabled.

Like most PythonCall functions, you must only call this from the main thread.
"""
function gc()
    if Base.Threads.nthreads() > 1
        @lock LOCK _gc()
    else
        _gc()
    end
end

function enqueue(ptr::C.PyPtr)
    if ptr != C.PyNULL && C.CTX.is_initialized
        if ENABLED[] && Base.Threads.threadid() == 1
            C.with_gil(false) do
                C.Py_DecRef(ptr)
            end
            gc()
        else
            if Base.Threads.nthreads() > 1
                @lock LOCK push!(QUEUE, ptr)
            else
                push!(QUEUE, ptr)
            end
        end
    end
    return
end

function enqueue_all(ptrs)
    if C.CTX.is_initialized
        if ENABLED[] && Base.Threads.threadid() == 1
            C.with_gil(false) do
                for ptr in ptrs
                    if ptr != C.PyNULL
                        C.Py_DecRef(ptr)
                    end
                end
            end
            gc()
        else
            if Base.Threads.nthreads() > 1
                @lock LOCK append!(QUEUE, ptrs)
            else
                append!(QUEUE, ptrs)
            end
        end
    end
    return
end

end # module GC
