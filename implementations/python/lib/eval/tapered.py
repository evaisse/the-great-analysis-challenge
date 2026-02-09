"""Tapered evaluation interpolation between middlegame and endgame."""


def interpolate(mg_score: int, eg_score: int, phase: int) -> int:
    """
    Interpolate between middlegame and endgame scores based on game phase.
    
    Args:
        mg_score: Middlegame score
        eg_score: Endgame score
        phase: Game phase (0 = endgame, 24 = middlegame)
    
    Returns:
        Interpolated score
    """
    return (mg_score * phase + eg_score * (256 - phase * 10 - 16)) // 256
