const ffi = @import("ffi.zig");
const zval_mod = @import("zval.zig");

const types = @import("types.zig");
const zval = types.zval;
const zend_class_entry = types.zend_class_entry;
const zend_object = types.zend_object;

/// Creates a new instance of `ce` in `zv` (via `object_init_ex`, which uses
/// the class's create_object handler). Only valid for instantiable classes.
pub fn init(zv: *zval, ce: *zend_class_entry) void {
    _ = ffi.object_init_ex(zv, ce);
}

/// Returns the `zend_object` behind an object zval, or null.
pub fn getObject(zv: *const zval) ?*zend_object {
    if (zval_mod.getType(zv) != types.IS_OBJECT) return null;
    const raw = zv.value.obj orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// Returns the class entry of an object zval, or null.
pub fn classOf(zv: *const zval) ?*zend_class_entry {
    const obj = getObject(zv) orelse return null;
    return obj.ce;
}

/// True when the object is an instance of `ce` (walks the parent chain).
pub fn instanceof(zv: *const zval, ce: *zend_class_entry) bool {
    var cur = classOf(zv);
    while (cur) |c| {
        if (c == ce) return true;
        cur = c.parent;
    }
    return false;
}

/// Reads instance property `name` from an object zval, returning a *borrowed*
/// pointer (do not release). Scope is the object's own class. `rv` is scratch
/// for unset/dynamic cases; check `zval.getType(rv) != IS_UNDEF`.
pub fn readProperty(zv: *const zval, name: []const u8, rv: *zval) ?*zval {
    const obj = getObject(zv) orelse return null;
    const scope = obj.ce;
    return ffi.zend_read_property(scope, obj, name.ptr, name.len, true, rv);
}

/// Assigns instance property `name` on an object zval.
pub fn updateProperty(zv: *zval, name: []const u8, value: *const zval) void {
    const obj = getObject(zv) orelse return;
    const scope = obj.ce;
    ffi.zend_update_property(scope, obj, name.ptr, name.len, @constCast(value));
}

/// Reads static property `name` of a class, returning a *borrowed* pointer.
pub fn readStaticProperty(ce: *zend_class_entry, name: []const u8) ?*zval {
    return ffi.zend_read_static_property(ce, name.ptr, name.len, true);
}

/// Assigns static property `name` on a class.
pub fn updateStaticProperty(ce: *zend_class_entry, name: []const u8, value: *const zval) void {
    ffi.zend_update_static_property(ce, name.ptr, name.len, @constCast(value));
}
