import {
  LegalMove,
  Move,
  Square,
  legalMove,
  square,
  uncheckedMove,
} from "../src/types";

const from = square(12);
const to = square(28);

const parsed = uncheckedMove({ from, to });
const validated: Move<"legal"> = legalMove({ from, to, piece: "P" });

export const legalOnlyMove: LegalMove = validated;
export const parsedStage = parsed.stage;

// @ts-expect-error Unchecked moves must not flow into legal move application paths.
export const illegalPromotionPath: LegalMove = parsed;

// @ts-expect-error Raw integers must not be treated as branded squares.
export const rawSquareAssignment: Square = 12;
