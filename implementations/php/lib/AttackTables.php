<?php

namespace Chess;

final class AttackTables {
    private static ?self $instance = null;

    private array $knightAttacks = [];
    private array $kingAttacks = [];
    private array $rayTables = [];
    private array $chebyshevDistance = [];
    private array $manhattanDistance = [];

    private function __construct() {
        $this->knightAttacks = $this->buildAttackTable([
            [-2, -1], [-2, 1], [-1, -2], [-1, 2],
            [1, -2], [1, 2], [2, -1], [2, 1],
        ]);
        $this->kingAttacks = $this->buildAttackTable([
            [-1, -1], [-1, 0], [-1, 1],
            [0, -1], [0, 1],
            [1, -1], [1, 0], [1, 1],
        ]);

        foreach ([
            '-1,-1' => [-1, -1],
            '0,-1' => [0, -1],
            '1,-1' => [1, -1],
            '-1,0' => [-1, 0],
            '1,0' => [1, 0],
            '-1,1' => [-1, 1],
            '0,1' => [0, 1],
            '1,1' => [1, 1],
        ] as $key => [$drow, $dcol]) {
            $this->rayTables[$key] = $this->buildRayTable($drow, $dcol);
        }

        $this->chebyshevDistance = $this->buildDistanceTable(
            static fn(int $rowDistance, int $colDistance): int => max($rowDistance, $colDistance)
        );
        $this->manhattanDistance = $this->buildDistanceTable(
            static fn(int $rowDistance, int $colDistance): int => $rowDistance + $colDistance
        );
    }

    public static function getInstance(): self {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    public function knightAttacks(int $row, int $col): array {
        return $this->knightAttacks[$row][$col];
    }

    public function kingAttacks(int $row, int $col): array {
        return $this->kingAttacks[$row][$col];
    }

    public function rayAttacks(int $row, int $col, int $drow, int $dcol): array {
        return $this->rayTables["{$drow},{$dcol}"][$row][$col];
    }

    public function chebyshevDistance(array $from, array $to): int {
        return $this->chebyshevDistance[$this->squareIndex($from[0], $from[1])][$this->squareIndex($to[0], $to[1])];
    }

    public function manhattanDistance(array $from, array $to): int {
        return $this->manhattanDistance[$this->squareIndex($from[0], $from[1])][$this->squareIndex($to[0], $to[1])];
    }

    private function buildAttackTable(array $deltas): array {
        $table = [];
        for ($row = 0; $row < 8; $row++) {
            $table[$row] = [];
            for ($col = 0; $col < 8; $col++) {
                $attacks = [];
                foreach ($deltas as [$drow, $dcol]) {
                    $newRow = $row + $drow;
                    $newCol = $col + $dcol;
                    if ($this->isValidSquare($newRow, $newCol)) {
                        $attacks[] = [$newRow, $newCol];
                    }
                }
                $table[$row][$col] = $attacks;
            }
        }
        return $table;
    }

    private function buildRayTable(int $drow, int $dcol): array {
        $table = [];
        for ($row = 0; $row < 8; $row++) {
            $table[$row] = [];
            for ($col = 0; $col < 8; $col++) {
                $ray = [];
                $newRow = $row + $drow;
                $newCol = $col + $dcol;
                while ($this->isValidSquare($newRow, $newCol)) {
                    $ray[] = [$newRow, $newCol];
                    $newRow += $drow;
                    $newCol += $dcol;
                }
                $table[$row][$col] = $ray;
            }
        }
        return $table;
    }

    private function buildDistanceTable(callable $metric): array {
        $table = [];
        for ($from = 0; $from < 64; $from++) {
            [$fromRow, $fromCol] = $this->indexToSquare($from);
            $table[$from] = [];
            for ($to = 0; $to < 64; $to++) {
                [$toRow, $toCol] = $this->indexToSquare($to);
                $rowDistance = abs($fromRow - $toRow);
                $colDistance = abs($fromCol - $toCol);
                $table[$from][$to] = $metric($rowDistance, $colDistance);
            }
        }
        return $table;
    }

    private function squareIndex(int $row, int $col): int {
        return $row * 8 + $col;
    }

    private function indexToSquare(int $index): array {
        return [intdiv($index, 8), $index % 8];
    }

    private function isValidSquare(int $row, int $col): bool {
        return $row >= 0 && $row < 8 && $col >= 0 && $col < 8;
    }
}
