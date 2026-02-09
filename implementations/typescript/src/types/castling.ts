// Type-safe castling rights
export interface CastlingRights {
  whiteKingside: boolean;
  whiteQueenside: boolean;
  blackKingside: boolean;
  blackQueenside: boolean;
}

export function createCastlingRights(
  whiteKingside: boolean = true,
  whiteQueenside: boolean = true,
  blackKingside: boolean = true,
  blackQueenside: boolean = true
): CastlingRights {
  return { whiteKingside, whiteQueenside, blackKingside, blackQueenside };
}

export function allCastlingRights(): CastlingRights {
  return createCastlingRights(true, true, true, true);
}

export function noCastlingRights(): CastlingRights {
  return createCastlingRights(false, false, false, false);
}

export function copyCastlingRights(rights: CastlingRights): CastlingRights {
  return { ...rights };
}

export function castlingRightsToString(rights: CastlingRights): string {
  let result = "";
  if (rights.whiteKingside) result += "K";
  if (rights.whiteQueenside) result += "Q";
  if (rights.blackKingside) result += "k";
  if (rights.blackQueenside) result += "q";
  return result || "-";
}

export function parseCastlingRights(str: string): CastlingRights {
  if (str === "-") return noCastlingRights();
  return {
    whiteKingside: str.includes("K"),
    whiteQueenside: str.includes("Q"),
    blackKingside: str.includes("k"),
    blackQueenside: str.includes("q"),
  };
}
