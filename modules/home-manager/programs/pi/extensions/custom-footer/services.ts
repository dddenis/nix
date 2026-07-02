import { Clock, Context, Effect, Layer, Random } from "effect";
import {
  EnvironmentService,
  FileSystemService,
  HomeDirectoryService,
  ProcessService,
} from "../shared/services";
import { readOpenAIRateLimitsEffect } from "./codex-json-rpc";
import type { AccountRateLimitsResponse } from "./helpers";

type RateLimitClientDependencies =
  | ProcessService
  | EnvironmentService
  | HomeDirectoryService
  | FileSystemService
  | Clock.Clock;

type RateLimitClientServiceShape = {
  readonly read: () => Effect.Effect<
    AccountRateLimitsResponse,
    Error,
    RateLimitClientDependencies
  >;
};

type JitterServiceShape = {
  readonly nextMultiplier: () => Effect.Effect<number>;
};

export class RateLimitClientService extends Context.Tag(
  "ddd-pi-extensions/RateLimitClientService",
)<RateLimitClientService, RateLimitClientServiceShape>() {}
export class JitterService extends Context.Tag(
  "ddd-pi-extensions/JitterService",
)<JitterService, JitterServiceShape>() {}

export const RateLimitClientLiveLayer = Layer.succeed(RateLimitClientService, {
  read: () => readOpenAIRateLimitsEffect(),
});

export const JitterLiveLayer = Layer.succeed(JitterService, {
  nextMultiplier: () =>
    Random.next.pipe(Effect.map((value) => 1 + value * 0.25)),
});

export const CustomFooterLiveLayer = Layer.mergeAll(
  RateLimitClientLiveLayer,
  JitterLiveLayer,
);
