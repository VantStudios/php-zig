<?php
// Exercises the php_zig_hello extension.
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_hello.so test/hello/test.php

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

if (!function_exists("hello_world")) {
    echo "FAIL extension functions not registered\n";
    exit(1);
}

check(hello_world(), "Hello from Zig!", "hello_world");
check(hello_add(2, 3), 5, "hello_add(2,3)");
check(hello_add(10, -4), 6, "hello_add(10,-4)");
check(hello_add(0, 0), 0, "hello_add(0,0)");
check(hello_truthy(true), true, "hello_truthy(true)");
check(hello_truthy(false), false, "hello_truthy(false)");
check(hello_truthy(null), false, "hello_truthy(null)");

// Arginfo: return type and parameters must be reflected correctly.
$r = new ReflectionFunction("hello_add");
check($r->getNumberOfParameters(), 2, "reflection param count");
check($r->getNumberOfRequiredParameters(), 2, "reflection required count");
check($r->getReturnType()->getName(), "int", "reflection return type");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);
