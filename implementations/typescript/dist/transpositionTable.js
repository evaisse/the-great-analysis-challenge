"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TranspositionTable = exports.BoundType = void 0;
exports.encodeMove = encodeMove;
exports.decodeMove = decodeMove;
var BoundType;
(function (BoundType) {
    BoundType["Exact"] = "Exact";
    BoundType["LowerBound"] = "LowerBound";
    BoundType["UpperBound"] = "UpperBound";
})(BoundType || (exports.BoundType = BoundType = {}));
class TranspositionTable {
    constructor(sizeMB = 16) {
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
    nextPowerOfTwo(n) {
        let power = 1;
        while (power < n) {
            power *= 2;
        }
        return power;
    }
    emptyEntry() {
        return {
            key: 0n,
            depth: 0,
            score: 0,
            bound: BoundType.Exact,
            bestMove: null,
            age: 0,
        };
    }
    index(key) {
        // Convert BigInt to number for indexing
        const keyNum = Number(key & BigInt(this.size - 1));
        return keyNum;
    }
    probe(key) {
        const idx = this.index(key);
        const entry = this.entries[idx];
        if (entry.key !== 0n && entry.key === key) {
            return entry;
        }
        return null;
    }
    store(key, depth, score, bound, bestMove) {
        const idx = this.index(key);
        const oldEntry = this.entries[idx];
        // Replacement policy: prefer recent age and greater depth
        const shouldReplace = oldEntry.key === 0n ||
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
    clear() {
        for (let i = 0; i < this.size; i++) {
            this.entries[i] = this.emptyEntry();
        }
    }
    newSearch() {
        this.age = (this.age + 1) & 0xff; // Wrap at 255
    }
    getSize() {
        return this.size;
    }
    fillPercentage() {
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
exports.TranspositionTable = TranspositionTable;
function encodeMove(from, to) {
    return from | (to << 6);
}
function decodeMove(encoded) {
    const from = encoded & 0x3f;
    const to = (encoded >> 6) & 0x3f;
    return [from, to];
}
//# sourceMappingURL=transpositionTable.js.map