<?php
// Exercises the php_zig_arrays extension.
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_arrays.so test/arrays/test.php

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

$arr = build_array();
echo "build_array() => "; var_dump($arr);

check($arr[0], 10, "numeric[0]");
check($arr[1], "first", "numeric[1]");
check($arr[2], true, "numeric[2]");
check($arr[3], null, "numeric[3]");
check($arr["name"], "php-zig", "key name");
check($arr["answer"], 42, "key answer");
check($arr["pi"], 3.14159, "key pi");
check($arr[4], ["nested-a", "nested-b"], "nested array (push)");
check($arr["child2"], [99], "nested array (key)");

check(array_sum_plus([1, 2, 3], 10), 16, "array_sum_plus");
check(array_sum_plus([1, "x", 2.5, 3], 0), 4, "array_sum_plus skips non-longs");
check(array_sum_plus([], 5), 5, "array_sum_plus empty");

check(array_first([7, 8, 9]), 7, "array_first");
check(array_first([]), null, "array_first empty");

check(array_lookup(build_array(), "name"), "php-zig", "array_lookup");
check(array_lookup(["name" => "php-zig"], "name"), "php-zig", "array_lookup direct");
check(array_lookup(["a" => 1], "missing"), null, "array_lookup missing");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);
