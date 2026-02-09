export interface CastlingRights {
    whiteKingside: boolean;
    whiteQueenside: boolean;
    blackKingside: boolean;
    blackQueenside: boolean;
}
export declare function createCastlingRights(whiteKingside?: boolean, whiteQueenside?: boolean, blackKingside?: boolean, blackQueenside?: boolean): CastlingRights;
export declare function allCastlingRights(): CastlingRights;
export declare function noCastlingRights(): CastlingRights;
export declare function copyCastlingRights(rights: CastlingRights): CastlingRights;
export declare function castlingRightsToString(rights: CastlingRights): string;
export declare function parseCastlingRights(str: string): CastlingRights;
//# sourceMappingURL=castling.d.ts.map