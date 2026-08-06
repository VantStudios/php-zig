<?php
// Exercises the php_zig_interface extension: an interface with method
// signatures implemented both by a Zig class (internal) and by a PHP userland
// class (external).
// Run from the repo root:
//   php -n -d extension=./zig-out/lib/libphp_zig_interface.so test/interface/test.php

// PHP engine rules for interface implementation (verified against the bundled
// PHP 8.0 binary, and identical for Zig-declared interfaces):
//
// 1. An interface WITH methods imposes a compile-time contract: a concrete
//    class that implements it but does not define every abstract method fails
//    with a Fatal error before any code runs:
//      "Class X contains N abstract method and must therefore be declared
//       abstract or implement the remaining methods (Iface::m)"
//    The class may instead declare itself abstract to defer the bodies. This
//    is enforced by the engine, so a Zig class omitted implementation is also
//    rejected at module registration.
//
// 2. An interface WITHOUT methods (a "marker interface") can be implemented
//    by any class with no obligations: `class B implements Marker {}` loads
//    fine and `$obj instanceof Marker` is true, for both PHP and Zig classes.

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

$ze = new ZigGreeter();

check(interface_exists("GreeterContract"), true, "interface_exists");
check(class_implements("GreeterContract"), [], "interface implements nothing");
check($ze instanceof GreeterContract, true, "Zig instanceof contract");
check(isset(class_implements("ZigGreeter")["GreeterContract"]), true, "Zig class_implements");
check($ze->greet("Nexxii"), "Hello, Nexxii", "Zig greet typed return");
check($ze->version(), 2, "Zig version");

$rc = new ReflectionClass("GreeterContract");
check($rc->getMethod("greet")->isAbstract(), true, "interface greet is abstract");
check($rc->getMethod("version")->getNumberOfParameters(), 0, "interface version no params");
check($rc->getMethod("greet")->getNumberOfParameters(), 1, "interface greet one param");

// A PHP userland class implements the same external interface. PHP enforces
// the interface's declared types, so the parameters and return are typed to
// match the signature declared in Zig (string $arg): string / int.
class PhpGreeter implements GreeterContract {
    public function greet(string $arg): string { return "Php " . $arg; }
    public function version(): int { return 9; }
}

$pg = new PhpGreeter();
check($pg instanceof GreeterContract, true, "Php instanceof interface");
check(isset(class_implements("PhpGreeter")["GreeterContract"]), true, "Php class_implements");
check($pg->greet("x"), "Php x", "Php greet");
check($pg->version(), 9, "Php version");

echo $failed === 0 ? "ALL PASS\n" : "$failed FAILED\n";
exit($failed === 0 ? 0 : 1);