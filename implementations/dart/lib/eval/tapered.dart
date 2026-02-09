int interpolate(int mgScore, int egScore, int phase) {
  return (mgScore * phase + egScore * (256 - phase * 10 - 16)) ~/ 256;
}
