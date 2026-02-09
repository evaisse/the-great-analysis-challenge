// Re-export all type-safe types
export * from "./square";
export * from "./piece";
export * from "./move";
export * from "./castling";
export * from "./boardState";

// Constants for convenience
export const FILES = ["a", "b", "c", "d", "e", "f", "g", "h"] as const;
export const RANKS = ["1", "2", "3", "4", "5", "6", "7", "8"] as const;
