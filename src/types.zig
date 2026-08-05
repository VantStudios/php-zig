pub const IS_UNDEF: u8 = 0;
pub const IS_NULL: u8 = 1;
pub const IS_FALSE: u8 = 2;
pub const IS_TRUE: u8 = 3;
pub const IS_LONG: u8 = 4;
pub const IS_DOUBLE: u8 = 5;
pub const IS_STRING: u8 = 6;
pub const IS_ARRAY: u8 = 7;
pub const IS_OBJECT: u8 = 8;
pub const IS_RESOURCE: u8 = 9;
pub const IS_REFERENCE: u8 = 10;

/// Bit flag stored in `zval.u1.v.type_flags` for reference-counted payloads.
pub const Z_TYPE_FLAG_REFCOUNTED: u8 = 1;
/// Bit flag stored in `zval.u1.v.type_flags` for cycle-collectable payloads.
pub const Z_TYPE_FLAG_COLLECTABLE: u8 = 2;

/// `zval.u1.type_info` for a reference zval: IS_REFERENCE with only the
/// REFCOUNTED flag (references are not marked collectable at the zval level).
pub const IS_REFERENCE_EX: u32 = IS_REFERENCE | (@as(u32, Z_TYPE_FLAG_REFCOUNTED) << 8);

pub const MAY_BE_NULL: u32 = 1 << IS_NULL;
pub const MAY_BE_FALSE: u32 = 1 << IS_FALSE;
pub const MAY_BE_TRUE: u32 = 1 << IS_TRUE;
pub const MAY_BE_LONG: u32 = 1 << IS_LONG;
pub const MAY_BE_DOUBLE: u32 = 1 << IS_DOUBLE;
pub const MAY_BE_STRING: u32 = 1 << IS_STRING;
pub const MAY_BE_ARRAY: u32 = 1 << IS_ARRAY;
pub const MAY_BE_OBJECT: u32 = 1 << IS_OBJECT;

pub const zend_refcounted_h = extern struct {
    refcount: u32,
    type_info: u32,
};

pub const zend_string = extern struct {
    gc: zend_refcounted_h,
    h: u64,
    len: usize,
    val: [1]u8,
};

pub const zend_array = extern struct {
    gc: zend_refcounted_h,
    u: extern union {
        flags: u32,
        v: extern struct {
            flags: u8,
            nApplyCount: u8,
            nIteratorsCount: u8,
            consistency: u8,
        },
    },
    nTableMask: u32,
    arData: ?*Bucket,
    nNumUsed: u32,
    nNumOfElements: u32,
    nTableSize: u32,
    nInternalPointer: u32,
    nNextFreeElement: i64,
    pDestructor: ?*anyopaque,
};

pub const Bucket = extern struct {
    val: zval,
    h: u64,
    key: ?*zend_string,
};

pub const zval = extern struct {
    value: extern union {
        lval: i64,
        dval: f64,
        counted: ?*zend_refcounted_h,
        str: ?*zend_string,
        arr: ?*zend_array,
        obj: ?*anyopaque,
        res: ?*anyopaque,
        ref: ?*anyopaque,
        ptr: ?*anyopaque,
    },
    u1: extern union {
        type_info: u32,
        v: extern struct {
            type: u8,
            type_flags: u8,
            extra: u16,
        },
    },
    u2: extern union {
        next: u32,
        cache_slot: u32,
        opline_num: u32,
        lineno: u32,
        num_args: u32,
        fe_pos: u32,
        fe_iter_idx: u32,
        access_flags: u32,
        property_guard: u32,
        extra: u32,
    },
};

pub const zend_type = extern struct {
    ptr: ?*anyopaque,
    type_mask: u32,
};

/// Source bookkeeping for references made from typed properties (PHP 8.0).
pub const zend_property_info_source_list = extern union {
    ptr: ?*anyopaque,
    list: usize,
};

/// A PHP reference (`&`): a refcounted box holding one zval.
///
/// Built by hand with `_emalloc` (no exported `zend_make_ref` in the 8.0
/// binaries), mirroring `ZVAL_NEW_REF`:
///   gc.refcount = 1
///   gc.type_info = GC_REFERENCE = IS_REFERENCE | GC_NOT_COLLECTABLE = 26
///   val = the referenced value (moved, no incref)
///   sources.ptr = null
/// The owning zval then has `value.ref = *zend_reference` and
/// `type_info = IS_REFERENCE_EX`.
pub const zend_reference = extern struct {
    gc: zend_refcounted_h,
    val: zval,
    sources: zend_property_info_source_list,
};

pub const zend_execute_data = opaque {};
