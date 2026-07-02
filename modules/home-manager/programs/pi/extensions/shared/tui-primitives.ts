import {
  Input,
  Key,
  matchesKey,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
import { Context, Effect, Layer } from "effect";

export interface TuiInputLike {
  focused: boolean;
  setValue(value: string): void;
  getValue(): string;
  handleInput(data: string): void;
  render(width: number): string[];
  invalidate(): void;
}

export interface TuiKeyPrimitives {
  readonly escape: string;
  readonly up: string;
  readonly down: string;
  readonly enter: string;
  readonly return: string;
  readonly ctrl: (key: string) => string;
}

export interface TuiPrimitives {
  readonly createInput: () => Effect.Effect<TuiInputLike>;
  readonly key: TuiKeyPrimitives;
  readonly matchesKey: (data: string, key: string) => boolean;
  readonly truncateToWidth: (
    value: string,
    width: number,
    ellipsis?: string,
  ) => string;
  readonly visibleWidth: (value: string) => number;
}

export class TuiPrimitivesService extends Context.Tag(
  "ddd-pi-extensions/TuiPrimitivesService",
)<TuiPrimitivesService, TuiPrimitives>() {}

export const TuiPrimitivesLiveLayer = Layer.succeed(TuiPrimitivesService, {
  createInput: () => Effect.sync(() => new Input()),
  key: Key,
  matchesKey,
  truncateToWidth,
  visibleWidth,
});
