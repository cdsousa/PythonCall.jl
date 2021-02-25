@init PyObject_TryConvert_AddRules("juliaaa.As", [
    (Any, PyAs_ConvertRule_tryconvert),
])

PyAs_ConvertRule_tryconvert(o, ::Type{S}) where {S} = begin
    # get the type
    to = PyObject_GetAttrString(o, "type")
    isnull(to) && return -1
    err = PyObject_Convert(to, Type)
    Py_DecRef(to)
    ism1(err) && return -1
    t = takeresult(Type)
    # get the value
    vo = PyObject_GetAttrString(o, "value")
    isnull(vo) && return -1
    err = PyObject_TryConvert(vo, t)
    Py_DecRef(vo)
    err == 1 || return err
    v = takeresult(t)
    # convert
    putresult(tryconvert(S, v))
end
