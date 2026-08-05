<?php
// Exercises the php_zig_references extension: by-ref mutation and variadic args.
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_references.so test/references/test.php

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

// ref_inc(&$n) mutates the caller's variable through the reference.
$n = 5;
check(ref_inc($n), true, "ref_inc returns true");
check($n, 6, "ref_inc mutates caller variable");

// ref_swap(&$a, &$b).
$a = 1;
$b = 2;
check(ref_swap($a, $b), true, "ref_swap returns true");
check($a, 2, "ref_swap exchanges a");
check($b, 1, "ref_swap exchanges b");

// ref_append(&$arr) appends inside the caller's array.
$arr = [1, 2, 3];
check(ref_append($arr), 1, "ref_append adds one element");
check(count($arr), 4, "ref_append grew the array");
check($arr[3], "x", "ref_append appended value");

// Variadic arginfo reflects through reflection.
$rf = new ReflectionFunction('ref_inc');
check($rf->getNumberOfParameters(), 1, "ref_inc arity");
check($rf->getParameters()[0]->isPassedByReference(), true, "ref_inc param by-ref");

// nparams(...$args): declared with zero named args, so all of them are
// variadic; sums every argument it receives.
check(nparams(1, 2, 3), 6, "nparams sums variadic args");
check(nparams(), 0, "nparams with no args");
check(nparams(10), 10, "nparams single arg");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);
