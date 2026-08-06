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

/// Opaque handle returned by `zend_declare_typed_property`. Its full layout is
/// only needed by callers that manipulate typed-property metadata, which v1
/// does not expose.
pub const zend_property_info = opaque {};

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

pub const ZEND_INTERNAL_CLASS: u8 = 1;

/// Instance of an internal/user class. `properties_table` is flexible in C;
/// the 1-element array fixes the trailing-part size (56 bytes).
pub const zend_object = extern struct {
    gc: zend_refcounted_h,
    handle: u32,
    ce: ?*zend_class_entry,
    handlers: ?*const anyopaque,
    properties: ?*zend_array,
    properties_table: [1]zval,
};

/// PHP 8.0 `_zend_class_entry`. On ZTS builds the engine forces
/// `ZEND_MAP_PTR_KIND_PTR_OR_OFFSET`, but `static_members_table` remains a
/// single pointer either way, so this layout is stable. Registration
/// (`zend_register_internal_class`) copies the struct; the temp entry only
/// needs `type`, `name`, `ce_flags` and `info.internal`.
pub const zend_class_entry = extern struct {
    type: u8,
    name: ?*zend_string,
    parent: ?*zend_class_entry,
    refcount: c_int,
    ce_flags: u32,
    default_properties_count: c_int,
    default_static_members_count: c_int,
    default_properties_table: ?*zval,
    default_static_members_table: ?*zval,
    static_members_table: ?*zval,
    function_table: zend_array,
    properties_info: zend_array,
    constants_table: zend_array,
    properties_info_table: ?*?*anyopaque,
    constructor: ?*anyopaque,
    destructor: ?*anyopaque,
    clone: ?*anyopaque,
    __get: ?*anyopaque,
    __set: ?*anyopaque,
    __unset: ?*anyopaque,
    __isset: ?*anyopaque,
    __call: ?*anyopaque,
    __callstatic: ?*anyopaque,
    __tostring: ?*anyopaque,
    __debugInfo: ?*anyopaque,
    __serialize: ?*anyopaque,
    __unserialize: ?*anyopaque,
    iterator_funcs_ptr: ?*anyopaque,
    create_object: ?*anyopaque,
    get_iterator: ?*anyopaque,
    get_static_method: ?*anyopaque,
    serialize: ?*anyopaque,
    unserialize: ?*anyopaque,
    num_interfaces: u32,
    num_traits: u32,
    interfaces: ?*anyopaque,
    trait_names: ?*anyopaque,
    trait_aliases: ?*anyopaque,
    trait_precedences: ?*anyopaque,
    attributes: ?*anyopaque,
    info: extern union {
        user: extern struct {
            filename: ?*zend_string,
            line_start: u32,
            line_end: u32,
            doc_comment: ?*zend_string,
        },
        internal: extern struct {
            builtin_functions: ?*const anyopaque,
            module: ?*anyopaque,
        },
    },
};

/// The `zend_execute_data` struct (PHP 8.0). Single source of truth: the
/// argument-offset math in `src/params.zig` derives from `@sizeOf(this)`.
///
/// Zend stores a call's argument zvals immediately after the struct in the
/// same allocation, so argument N (1-based) sits at
/// `execute_data + @sizeOf(zend_execute_data) + (N-1)`. The first fields up to
/// `this` match the C layout exactly; the trailing pointers are the remaining
/// public members of PHP 8.0's `_zend_execute_data`.
pub const zend_execute_data = extern struct {
    opline: ?*anyopaque,
    call: ?*anyopaque,
    return_value: ?*zval,
    func: ?*anyopaque,
    this: zval,
    prev_execute_data: ?*anyopaque,
    symbol_table: ?*anyopaque,
    run_time_cache: ?*anyopaque,
    extra_named_params: ?*anyopaque,
};
