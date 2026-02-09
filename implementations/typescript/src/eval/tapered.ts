export function interpolate(mgScore: number, egScore: number, phase: number): number {
  return Math.floor((mgScore * phase + egScore * (256 - phase * 10 - 16)) / 256);
}
