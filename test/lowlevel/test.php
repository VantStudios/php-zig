<?php
// Exercises the php_zig_lowlevel extension (raw FFI / refcount demos).
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_lowlevel.so test/lowlevel/test.php

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

$raw = raw_build();
echo "raw_build() => "; var_dump($raw);

check($raw["answer"], 42, "raw answer");
check($raw["data"], "raw bytes", "raw data");
check($raw[0], [7, "seven"], "raw inner array");
check(raw_find($raw), "raw bytes", "raw_find");

// Explicit addRef/release: [1, 2].
check(raw_refcount("hi"), [1, 2], "raw_refcount");

check(raw_manipulate(21), 42, "raw_manipulate");
check(raw_manipulate("nope"), null, "raw_manipulate type check");

check(raw_argcount(1, 2, 3), 3, "raw_argcount");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);
