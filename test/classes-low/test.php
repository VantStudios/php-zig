<?php
// Exercises the php_zig_classes extension.
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_classes.so test/classes/test.php

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

$g = new Greeter("World");

check(get_class($g), "Greeter", "get_class");
check($g instanceof Greeter, true, "instanceof");
check($g->name, "World", "property from ctor");
check($g->greeting, "Hello", "property default");
check($g->greet(), "Hello World", "greet");

$d = new Greeter();
check($d->name, "world", "ctor default");

check(Greeter::bump(), 1, "static bump 1");
check(Greeter::bump(), 2, "static bump 2");
check(Greeter::kind(), "static", "static method");
check(Greeter::VERSION, 100, "class constant");

$f = make_greeter("Zig");
check($f instanceof Greeter, true, "factory instanceof");
check($f->greet(), "Hello Zig", "factory greet");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);