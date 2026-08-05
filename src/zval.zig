const ffi = @import("ffi.zig");
const string = @import("string.zig");

const types = @import("types.zig");
pub const zval = types.zval;

/// Type-flag bits stored in `zval.u1.v.type_flags` (see `types.zig`).
pub const Z_TYPE_FLAG_REFCOUNTED = types.Z_TYPE_FLAG_REFCOUNTED;
pub const Z_TYPE_FLAG_COLLECTABLE = types.Z_TYPE_FLAG_COLLECTABLE;

/// Builds a `zval.u1.type_info` value from a base type and type flags.
///
/// PHP packs both into one u32: `type | (flags << 8)`.
pub fn typeInfo(zv_type: u8, flags: u8) u32 {
    return @as(u32, zv_type) | (@as(u32, flags) << 8);
}

/// Returns the base type of `zv` (`IS_*` constant from `types.zig`).
pub fn getType(zv: *const zval) u8 {
    return zv.u1.v.type;
}

/// Returns true when `zv` holds a reference-counted payload.
pub fn isRefcounted(zv: *const zval) bool {
    return (zv.u1.v.type_flags & Z_TYPE_FLAG_REFCOUNTED) != 0;
}

/// Returns true when `zv` is a reference (`&`).
pub fn isRef(zv: *const zval) bool {
    return getType(zv) == types.IS_REFERENCE;
}

/// Returns a pointer to the zval held by the reference `zv`. Only valid when
/// `isRef(zv)`.
pub fn derefValue(zv: *const zval) *zval {
    const raw = zv.value.ref orelse unreachable;
    const ref: *types.zend_reference = @ptrCast(@alignCast(raw));
    return &ref.val;
}

/// GC type_info for a reference: `GC_REFERENCE = IS_REFERENCE | GC_NOT_COLLECTABLE`.
pub const GC_REFERENCE: u32 = types.IS_REFERENCE | (1 << 4);

/// Converts `zv` in place into a reference wrapping its current value
/// (`ZVAL_MAKE_REF`). No-op if `zv` is already a reference.
///
/// The reference is allocated with `_emalloc` and takes over `zv`'s current
/// value (no incref — `zv` must own its payload). `zv` becomes
/// `type_info = IS_REFERENCE_EX` pointing at the new box.
pub fn makeRef(zv: *zval) void {
    if (isRef(zv)) return;

    const ref_block = ffi._emalloc(@sizeOf(types.zend_reference)) orelse return;
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

/// Sets `zv` to a reference-counted string copied from `s` (binary-safe).
pub fn setString(zv: *zval, s: []const u8) void {
    const str = string.dup(s) orelse {
        setNull(zv);
        return;
    };
    zv.value.str = str;
    zv.u1.type_info = typeInfo(types.IS_STRING, Z_TYPE_FLAG_REFCOUNTED);
}

/// Sets `zv` to a reference-counted array reserving `reserve` slots.
pub fn setArray(zv: *zval, reserve: u32) void {
    const arr = ffi._zend_new_array(reserve) orelse {
        setNull(zv);
        return;
    };
    zv.value.arr = arr;
    zv.u1.type_info = typeInfo(types.IS_ARRAY, Z_TYPE_FLAG_REFCOUNTED | Z_TYPE_FLAG_COLLECTABLE);
}

/// Copies `src` into `dst`, taking a new reference for refcounted payloads.
///
/// `dst` owns the new reference; `src` keeps its own and stays valid.
pub fn copy(dst: *zval, src: *const zval) void {
    dst.* = src.*;
    if (isRefcounted(dst)) addRef(dst);
}

/// Takes a new reference to `zv`'s refcounted payload (no-op otherwise).
pub fn addRef(zv: *zval) void {
    if (!isRefcounted(zv)) return;
    const counted = zv.value.counted orelse return;
    counted.refcount += 1;
}

/// Releases `zv`'s payload reference (no-op for non-refcounted types).
pub fn release(zv: *zval) void {
    ffi.zval_ptr_dtor(zv);
}
