<?php
// Exercises the php_zig_constants extension.
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_constants.so test/constants/test.php

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

// Constants registered from module_startup.
check(PHP_ZIG_HELLO, "php-zig", "string constant");
check(PHP_ZIG_VERSION, 100, "long constant");
check(PHP_ZIG_PI, 3.14159, "double constant");
check(PHP_ZIG_READY, true, "bool constant");
check(defined("PHP_ZIG_HELLO"), true, "constant defined");

// Optional parameter with default.
check(greet(), "Hello, world", "greet() default");
check(greet("php"), "Hello, php", "greet(name)");

// Startup/shutdown hooks wired correctly (module loads and unloads cleanly).
check(in_array("PHP_ZIG_HELLO", constant_report(), true), true, "constant_report");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);
