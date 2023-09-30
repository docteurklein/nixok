<?php

namespace Florian\KubenixTest;

class Test {
    function __construct(\PDO $pdo) {
        var_dump($pdo->exec('select 1'));
        sleep(1);
        var_dump($pdo->exec('select 1'));
        sleep(1);
        var_dump($pdo->exec('select 1'));
        sleep(1);
        var_dump($pdo->exec('select 1'));
        sleep(1);
        var_dump($pdo->exec('select 1'));
        sleep(1);
        var_dump($pdo->exec('select 1'));
        sleep(1);
        var_dump($pdo->exec('select 1'));
        sleep(1);
    }
}
