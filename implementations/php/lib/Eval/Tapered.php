<?php

namespace Chess\Eval;

/**
 * Tapered evaluation interpolation
 */
class Tapered {
    public static function interpolate(int $mgScore, int $egScore, int $phase): int {
        return intval(($mgScore * $phase + $egScore * (256 - $phase * 10 - 16)) / 256);
    }
}
