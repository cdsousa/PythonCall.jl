"""
Garbarge collection of Python objects.

See `disable` and `enable`.
"""
module GC

import ..PythonCall.C

const LOCK = Threads.SpinLock()
const ENABLED = Ref(true)
const QUEUE = C.PyPtr[]

"""
    PythonCall.GC.enable(on::Bool=true)

Enable or disable the PythonCall garbage collector.

Any Python objects which are finalized while the GC is disabled, or from a thread other than
1, are not actually freed until either the GC is re-enabled or a Python object is finalized
on thread 1.

Must only be called from thread 1.
"""
function enable(on::Bool=true)
    ans = ENABLED[]
    ENABLED[] = on
    on && gc()
    return ans
end

@deprecate disable() enable(false) export_old=false

"""
    PythonCall.GC.disable()

Deprecated. Equivalent to `PythonCall.GC.enable(false)`.
"""
disable


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

These are Python objects which were GC'd from a thread other than 1, or were GC'd while
PythonCall's GC is disabled.

You do not normally need to call this, since it will happen automatically when a Python
object is freed on the main thread or PythonCall's GC is enabled.

Must only be called from thread 1.
"""
function gc()
    if Threads.nthreads() > 1
        @lock LOCK _gc()
    else
        _gc()
    end
end

function enqueue(ptr::C.PyPtr)
    if ptr != C.PyNULL && C.CTX.is_initialized
        if ENABLED[] && Threads.threadid() == 1
            C.with_gil(false) do
                C.Py_DecRef(ptr)
            end
            gc()
        else
            if Threads.nthreads() > 1
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
        if ENABLED[] && Threads.threadid() == 1
            C.with_gil(false) do
                for ptr in ptrs
                    if ptr != C.PyNULL
                        C.Py_DecRef(ptr)
                    end
                end
            end
            gc()
        else
            if Threads.nthreads() > 1
                @lock LOCK append!(QUEUE, ptrs)
            else
                append!(QUEUE, ptrs)
            end
        end
    end
    return
end

end # module GC
