<?php
// Exercises the php_zig_strings extension.
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_strings.so test/strings/test.php

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

check(str_len("hello"), 5, "str_len");
check(str_len(""), 0, "str_len empty");

$bin = "a\x00b";
check(str_len($bin), 3, "str_len binary");
check(binary_echo($bin), $bin, "binary_echo roundtrip");
check(strlen(binary_echo($bin)), 3, "binary_echo length");

check(repeat_str("ab", 3), "ababab", "repeat_str");
check(repeat_str("x", 0), "", "repeat_str zero");
check(repeat_str("", 5), "", "repeat_str empty");

check(concat3("foo", "-", "bar"), "foo-bar", "concat3");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);
