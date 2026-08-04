// Public API surface of php-zig.
//
// Two layers are exposed:
//   1. Low-level primitives (visible, no hidden work): `ffi`, `types`, `zval`,
//      `string`, `hash`, `params`, `module`, `constants`. Pointer and
//      refcount tricks live here and are documented at their site.
//   2. High-level ergonomic helpers (`helpers`) plus flat aliases for the most
//      common symbols, matching the README quick start.
//
// Note: the `zval` *type* is `php.types.zval`; `php.zval` is the module of
// operations on it.

pub const ffi = @import("ffi.zig");
pub const types = @import("types.zig");
pub const zval = @import("zval.zig");
pub const string = @import("string.zig");
pub const hash = @import("hash.zig");
pub const params = @import("params.zig");
pub const module = @import("module.zig");
pub const constants = @import("constants.zig");
pub const errors = @import("errors.zig");
pub const helpers = @import("helpers.zig");

// --- Types ---
pub const zend_module_entry = module.zend_module_entry;
pub const zend_function_entry = module.zend_function_entry;
pub const zend_internal_arg_info = module.zend_internal_arg_info;
pub const zend_array = types.zend_array;
pub const zend_string = types.zend_string;
pub const zend_type = types.zend_type;
pub const zend_execute_data = types.zend_execute_data;
pub const zend_refcounted_h = types.zend_refcounted_h;
pub const Bucket = types.Bucket;
pub const Param = params.Param;
pub const ParamType = params.ParamType;
pub const ArrayKey = hash.ArrayKey;
pub const ArrayEntry = hash.ArrayEntry;
pub const ArrayIter = hash.ArrayIter;

// --- Type constants ---
pub const IS_UNDEF = types.IS_UNDEF;
pub const IS_NULL = types.IS_NULL;
pub const IS_FALSE = types.IS_FALSE;
pub const IS_TRUE = types.IS_TRUE;
pub const IS_LONG = types.IS_LONG;
pub const IS_DOUBLE = types.IS_DOUBLE;
pub const IS_STRING = types.IS_STRING;
pub const IS_ARRAY = types.IS_ARRAY;
pub const IS_OBJECT = types.IS_OBJECT;
pub const Z_TYPE_FLAG_REFCOUNTED = zval.Z_TYPE_FLAG_REFCOUNTED;
pub const Z_TYPE_FLAG_COLLECTABLE = zval.Z_TYPE_FLAG_COLLECTABLE;

pub const MAY_BE_NULL = types.MAY_BE_NULL;
pub const MAY_BE_FALSE = types.MAY_BE_FALSE;
pub const MAY_BE_TRUE = types.MAY_BE_TRUE;
pub const MAY_BE_LONG = types.MAY_BE_LONG;
pub const MAY_BE_DOUBLE = types.MAY_BE_DOUBLE;
pub const MAY_BE_STRING = types.MAY_BE_STRING;
pub const MAY_BE_ARRAY = types.MAY_BE_ARRAY;
pub const MAY_BE_OBJECT = types.MAY_BE_OBJECT;

// --- Module ---
pub const createModule = module.createModule;
pub const ModuleOptions = module.ModuleOptions;
pub const returnInfo = module.returnInfo;
pub const paramInfo = module.paramInfo;
pub const paramInfoOptional = module.paramInfoOptional;
pub const function_entry_end = module.function_entry_end;

// --- Constants ---
pub const registerLong = constants.registerLong;
pub const registerDouble = constants.registerDouble;
pub const registerString = constants.registerString;
pub const registerBool = constants.registerBool;
pub const CONST_CS = constants.CONST_CS;
pub const CONST_PERSISTENT = constants.CONST_PERSISTENT;

// --- Errors and exceptions ---
pub const throwException = errors.throwException;
pub const throwError = errors.throwError;
pub const throwTypeError = errors.throwTypeError;
pub const throwValueError = errors.throwValueError;
pub const phpError = errors.phpError;
pub const E_ERROR = errors.E_ERROR;
pub const E_WARNING = errors.E_WARNING;
pub const E_PARSE = errors.E_PARSE;
pub const E_NOTICE = errors.E_NOTICE;
pub const E_CORE_ERROR = errors.E_CORE_ERROR;
pub const E_CORE_WARNING = errors.E_CORE_WARNING;
pub const E_COMPILE_ERROR = errors.E_COMPILE_ERROR;
pub const E_COMPILE_WARNING = errors.E_COMPILE_WARNING;
pub const E_USER_ERROR = errors.E_USER_ERROR;
pub const E_USER_WARNING = errors.E_USER_WARNING;
pub const E_USER_NOTICE = errors.E_USER_NOTICE;
pub const E_RECOVERABLE_ERROR = errors.E_RECOVERABLE_ERROR;
pub const E_DEPRECATED = errors.E_DEPRECATED;
pub const E_USER_DEPRECATED = errors.E_USER_DEPRECATED;
pub const E_ALL = errors.E_ALL;

// --- Parameters ---
pub const getArg = params.getArg;
pub const getArgCount = params.getArgCount;

// --- Hash iteration ---
pub const HashPosition = hash.HashPosition;
pub const HASH_KEY_IS_STRING = hash.HASH_KEY_IS_STRING;
pub const HASH_KEY_IS_LONG = hash.HASH_KEY_IS_LONG;
pub const HASH_KEY_NON_EXISTENT = hash.HASH_KEY_NON_EXISTENT;

// --- High-level helpers ---
pub const returnNull = helpers.returnNull;
pub const returnTrue = helpers.returnTrue;
pub const returnFalse = helpers.returnFalse;
pub const returnLong = helpers.returnLong;
pub const returnDouble = helpers.returnDouble;
pub const returnString = helpers.returnString;
pub const returnStringZ = helpers.returnStringZ;
pub const returnArray = helpers.returnArray;

pub const arrayPushNull = helpers.arrayPushNull;
pub const arrayPushBool = helpers.arrayPushBool;
pub const arrayPushLong = helpers.arrayPushLong;
pub const arrayPushDouble = helpers.arrayPushDouble;
pub const arrayPushString = helpers.arrayPushString;
pub const arrayPushStringZ = helpers.arrayPushStringZ;
pub const arrayPushArray = helpers.arrayPushArray;
pub const arrayPushArrayOwned = helpers.arrayPushArrayOwned;

pub const arraySetNull = helpers.arraySetNull;
pub const arraySetBool = helpers.arraySetBool;
pub const arraySetLong = helpers.arraySetLong;
pub const arraySetDouble = helpers.arraySetDouble;
pub const arraySetString = helpers.arraySetString;
pub const arraySetStringZ = helpers.arraySetStringZ;
pub const arraySetArray = helpers.arraySetArray;
pub const arraySetArrayOwned = helpers.arraySetArrayOwned;

pub const newArrayZval = helpers.newArrayZval;
