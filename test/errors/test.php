<?php
// Exercises the php_zig_errors extension.
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_errors.so test/errors/test.php

$failed = 0;

function check($actual, $expected, string $label): void {
    global $failed;
    if ($actual === $expected) {
        echo "PASS $label\n";
    } else {
        echo "FAIL $label (expected: " . var_export($expected, true) .
            ", got: " . var_export($actual, true) . ")\n";
        $failed++;
    }
}

// Exceptions carry message + code.
try {
    throws_exception();
    check(true, false, "throws_exception should not return");
} catch (Exception $e) {
    check($e->getMessage(), "boom from zig", "exception message");
    check($e->getCode(), 42, "exception code");
    check($e instanceof Exception, true, "instanceof Exception");
}

// Errors and their subclasses are thrown as Error-family objects.
try {
    throws_error();
    check(true, false, "throws_error should not return");
} catch (Error $e) {
    check($e->getMessage(), "fatal from zig", "error message");
    check($e instanceof Error, true, "instanceof Error");
}

try {
    throws_type_error();
    check(true, false, "throws_type_error should not return");
} catch (TypeError $e) {
    check($e->getMessage(), "expected int, got string", "type error message");
    check($e instanceof Error, true, "TypeError instanceof Error");
}

try {
    throws_value_error();
    check(true, false, "throws_value_error should not return");
} catch (ValueError $e) {
    check($e->getMessage(), "negative length", "value error message");
    check($e instanceof Error, true, "ValueError instanceof Error");
}

// zend_error levels reach the user error handler.
$captured = [];
set_error_handler(function ($no, $str) use (&$captured) {
    $captured[] = [$no, $str];
    return true;
});

emit_warning("careful");
emit_notice("heads up");
restore_error_handler();

check($captured[0][0], E_WARNING, "warning level");
check($captured[0][1], "careful", "warning message");
check($captured[1][0], E_NOTICE, "notice level");
check($captured[1][1], "heads up", "notice message");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);
