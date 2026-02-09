import { ZobristKey } from "./zobrist";
import { Square } from "./types";

export enum BoundType {
  Exact = "Exact",
  LowerBound = "LowerBound",
  UpperBound = "UpperBound",
}

export interface TTEntry {
  key: ZobristKey;
  depth: number;
  score: number;
  bound: BoundType;
  bestMove: number | null; // Encoded as from | (to << 6)
  age: number;
}

export class TranspositionTable {
  private entries: TTEntry[];
  private age: number;
  private size: number;

  constructor(sizeMB: number = 16) {
    const bytes = sizeMB * 1024 * 1024;
    const entrySize = 32; // Approximate size per entry in bytes
    let numEntries = Math.floor(bytes / entrySize);

    // Round to next power of 2 for fast modulo
    numEntries = this.nextPowerOfTwo(numEntries);

    this.size = numEntries;
    this.age = 0;
    this.entries = new Array(numEntries);

    // Initialize all entries as empty
    for (let i = 0; i < numEntries; i++) {
      this.entries[i] = this.emptyEntry();
    }
  }

  private nextPowerOfTwo(n: number): number {
    let power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  private emptyEntry(): TTEntry {
    return {
      key: 0n,
      depth: 0,
      score: 0,
      bound: BoundType.Exact,
      bestMove: null,
      age: 0,
    };
  }

  private index(key: ZobristKey): number {
    // Convert BigInt to number for indexing
    const keyNum = Number(key & BigInt(this.size - 1));
    return keyNum;
  }

  public probe(key: ZobristKey): TTEntry | null {
    const idx = this.index(key);
    const entry = this.entries[idx];

    if (entry.key !== 0n && entry.key === key) {
      return entry;
    }
    return null;
  }

  public store(
    key: ZobristKey,
    depth: number,
    score: number,
    bound: BoundType,
    bestMove: number | null
  ): void {
    const idx = this.index(key);
    const oldEntry = this.entries[idx];

    // Replacement policy: prefer recent age and greater depth
    const shouldReplace =
      oldEntry.key === 0n ||
      oldEntry.age !== this.age ||
      depth >= oldEntry.depth;

    if (shouldReplace) {
      this.entries[idx] = {
        key,
        depth,
        score,
        bound,
        bestMove,
        age: this.age,
      };
    }
  }

  public clear(): void {
    for (let i = 0; i < this.size; i++) {
      this.entries[i] = this.emptyEntry();
    }
  }

  public newSearch(): void {
    this.age = (this.age + 1) & 0xff; // Wrap at 255
  }

  public getSize(): number {
    return this.size;
  }

  public fillPercentage(): number {
    let filled = 0;
    for (let i = 0; i < this.size; i++) {
      const entry = this.entries[i];
      if (entry.key !== 0n && entry.age === this.age) {
        filled++;
      }
    }
    return (filled / this.size) * 100;
  }
}

export function encodeMove(from: Square, to: Square): number {
  return from | (to << 6);
}

export function decodeMove(encoded: number): [Square, Square] {
  const from = encoded & 0x3f;
  const to = (encoded >> 6) & 0x3f;
  return [from, to];
}
