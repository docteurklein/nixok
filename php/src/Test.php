<?php declare(strict_types=1);

namespace Florian\KubenixTest;

function Fibonacci(int $n): int {
    $a = 0;
    $b = 1;
    $tmp = 0;

    for ($i = 0; $i < $n; $i++) {
        $tmp = $a;
        $a = $b;
        $b += $tmp;
    }

    return $a;
}

class Test {
    function __construct(\PDO $pdo) {
        var_dump($pdo->exec('select 1'));
        sleep(1);
        var_dump(Fibonacci(23));
    }
}
