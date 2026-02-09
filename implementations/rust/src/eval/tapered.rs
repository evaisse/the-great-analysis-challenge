pub fn interpolate(mg_score: i32, eg_score: i32, phase: i32) -> i32 {
    (mg_score * phase + eg_score * (256 - phase * 10 - 16)) / 256
}
