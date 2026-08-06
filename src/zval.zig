const ffi = @import("ffi.zig");
const string = @import("string.zig");

const types = @import("types.zig");
pub const zval = types.zval;

/// Type-flag bits used in `zval.u1.v.type_flags`.
pub const Z_TYPE_FLAG_REFCOUNTED = types.Z_TYPE_FLAG_REFCOUNTED;
pub const Z_TYPE_FLAG_COLLECTABLE = types.Z_TYPE_FLAG_COLLECTABLE;

/// Packs `type | (flags << 8)` into `zval.u1.type_info`.
pub fn typeInfo(zv_type: u8, flags: u8) u32 {
    return @as(u32, zv_type) | (@as(u32, flags) << 8);
}

pub fn getType(zv: *const zval) u8 {
    return zv.u1.v.type;
}

pub fn isRefcounted(zv: *const zval) bool {
    return (zv.u1.v.type_flags & Z_TYPE_FLAG_REFCOUNTED) != 0;
}

pub fn isRef(zv: *const zval) bool {
    return getType(zv) == types.IS_REFERENCE;
}

/// Pointer to the boxed zval; only valid when `isRef(zv)`.
pub fn derefValue(zv: *const zval) *zval {
    const raw = zv.value.ref orelse unreachable;
    const ref: *types.zend_reference = @ptrCast(@alignCast(raw));
    return &ref.val;
}

/// Reference GC type_info: `IS_REFERENCE | GC_NOT_COLLECTABLE`.
pub const GC_REFERENCE: u32 = types.IS_REFERENCE | (1 << 4);

/// `ZVAL_MAKE_REF`: boxes `zv`'s current value in place. No-op if already a
/// reference. The box takes over the payload (no incref); `zv` must own it.
pub fn makeRef(zv: *zval) void {
    if (isRef(zv)) return;

    const ref_block = ffi._emalloc(@sizeOf(types.zend_reference));
    const ref: *types.zend_reference = @ptrCast(@alignCast(ref_block));
    ref.gc.refcount = 1;
    ref.gc.type_info = GC_REFERENCE;
    ref.val = zv.*;
    ref.sources = .{ .list = 0 };

    zv.value.ref = ref;
    zv.u1.type_info = types.IS_REFERENCE_EX;
}

pub fn setNull(zv: *zval) void {
    zv.u1.type_info = types.IS_NULL;
}

pub fn setTrue(zv: *zval) void {
    zv.u1.type_info = types.IS_TRUE;
}

pub fn setFalse(zv: *zval) void {
    zv.u1.type_info = types.IS_FALSE;
}

pub fn setLong(zv: *zval, val: i64) void {
    zv.value.lval = val;
    zv.u1.type_info = types.IS_LONG;
}

pub fn setDouble(zv: *zval, val: f64) void {
    zv.value.dval = val;
    zv.u1.type_info = types.IS_DOUBLE;
}

/// Sets `zv` to a string copied from `s` (binary-safe).
pub fn setString(zv: *zval, s: []const u8) void {
    const str = string.dup(s);
    zv.value.str = str;
    zv.u1.type_info = typeInfo(types.IS_STRING, Z_TYPE_FLAG_REFCOUNTED);
}

/// Sets `zv` to the interned persistent string `s` (no refcount: interned
/// strings are immortal). Use for class member defaults that PHP copies into
/// persistent storage; regular request strings (from `setString`) are
/// request-scoped and would be freed early.
pub fn setInternedString(zv: *zval, s: []const u8) void {
    const str = string.intern(s);
    zv.value.str = str;
    zv.u1.type_info = types.IS_STRING;
}

/// Sets `zv` to a new array reserving `reserve` slots.
pub fn setArray(zv: *zval, reserve: u32) void {
    zv.value.arr = ffi._zend_new_array(reserve);
    zv.u1.type_info = typeInfo(types.IS_ARRAY, Z_TYPE_FLAG_REFCOUNTED | Z_TYPE_FLAG_COLLECTABLE);
}

/// Copies `src` into `dst`, taking a new reference for refcounted payloads.
pub fn copy(dst: *zval, src: *const zval) void {
    dst.* = src.*;
    if (isRefcounted(dst)) addRef(dst);
}

pub fn addRef(zv: *zval) void {
    if (!isRefcounted(zv)) return;
    const counted = zv.value.counted orelse return;
    counted.refcount += 1;
}

pub fn release(zv: *zval) void {
    ffi.zval_ptr_dtor(zv);
}
