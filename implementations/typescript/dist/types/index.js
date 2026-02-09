"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RANKS = exports.FILES = void 0;
// Re-export all type-safe types
__exportStar(require("./square"), exports);
__exportStar(require("./piece"), exports);
__exportStar(require("./move"), exports);
__exportStar(require("./castling"), exports);
__exportStar(require("./boardState"), exports);
// Constants for convenience
exports.FILES = ["a", "b", "c", "d", "e", "f", "g", "h"];
exports.RANKS = ["1", "2", "3", "4", "5", "6", "7", "8"];
//# sourceMappingURL=index.js.map