/**
 * Deno port of functions/test/orders.test.ts — pure logic, no emulator.
 * Mirrors Flutter FeeConfig + order status graph so Supabase edges and
 * the Dart client agree on fees/transitions. Run: deno test --allow-read supabase/functions/place-order/index.test.ts
 */

import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeFees,
  FEE_CONFIG,
  canTransition,
  TERMINAL_STATUSES,
  isCashPayment,
  validateOptionalText,
  FIELD_LIMITS,
} from "../_shared/constants.ts";
import {
  validateQuantity,
  isAllowedTransition,
  withinCancelWindow,
} from "../_shared/orders.ts";

Deno.test("computeFees — base delivery when no coordinates", () => {
  assertEquals(computeFees("delivery", false), {
    deliveryFee: FEE_CONFIG.deliveryBaseCharge,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: 0,
    deliveryDistanceKm: undefined,
  });
});

Deno.test("computeFees — distance-based fee with valid coordinates", () => {
  const result = computeFees("delivery", false, 13.5975, 121.1848); // ~1km from mall
  assertEquals(result.serviceFee, FEE_CONFIG.serviceFee);
  assertEquals(result.priorityFee, 0);
  assert(result.deliveryDistanceKm !== undefined && result.deliveryDistanceKm > 0);
  assertEquals(
    result.deliveryFee,
    FEE_CONFIG.deliveryBaseCharge + result.deliveryDistanceKm! * FEE_CONFIG.deliveryPerKm,
  );
});

Deno.test("computeFees — priority fee only for priority delivery", () => {
  assertEquals(computeFees("delivery", true), {
    deliveryFee: FEE_CONFIG.deliveryBaseCharge,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: FEE_CONFIG.priorityFee,
    deliveryDistanceKm: undefined,
  });
});

Deno.test("computeFees — waives delivery+priority for pickup", () => {
  assertEquals(computeFees("pickup", true), {
    deliveryFee: 0,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: 0,
    deliveryDistanceKm: undefined,
  });
});

Deno.test("computeFees — mirrors Flutter FeeConfig", () => {
  assertEquals(FEE_CONFIG.serviceFee, 15.0);
  assertEquals(FEE_CONFIG.priorityFee, 29.0);
  assertEquals(FEE_CONFIG.deliveryBaseCharge, 30.0);
  assertEquals(FEE_CONFIG.deliveryPerKm, 10.0);
});

Deno.test("computeFees — ignores invalid coordinates", () => {
  assertEquals(computeFees("delivery", false, NaN, 121.1848), {
    deliveryFee: FEE_CONFIG.deliveryBaseCharge,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: 0,
    deliveryDistanceKm: undefined,
  });
  assertEquals(computeFees("delivery", false, 13.5864, Infinity), {
    deliveryFee: FEE_CONFIG.deliveryBaseCharge,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: 0,
    deliveryDistanceKm: undefined,
  });
  assertEquals(computeFees("delivery", false, null as unknown as number, 121.1848), {
    deliveryFee: FEE_CONFIG.deliveryBaseCharge,
    serviceFee: FEE_CONFIG.serviceFee,
    priorityFee: 0,
    deliveryDistanceKm: undefined,
  });
});

Deno.test("isCashPayment — cod/cop are cash", () => {
  assertEquals(isCashPayment("cod"), true);
  assertEquals(isCashPayment("cop"), true);
});

Deno.test("isCashPayment — online methods are non-cash", () => {
  assertEquals(isCashPayment("gcash"), false);
  assertEquals(isCashPayment("paymaya"), false);
  assertEquals(isCashPayment("card"), false);
  assertEquals(isCashPayment(undefined), false);
  assertEquals(isCashPayment(42 as unknown as string), false);
});

Deno.test("validateOptionalText — accepts absent/within-limit", () => {
  assertEquals(validateOptionalText(undefined, 100, "x"), null);
  assertEquals(validateOptionalText(null, 100, "x"), null);
  assertEquals(validateOptionalText("ok", 100, "x"), null);
});

Deno.test("validateOptionalText — rejects over-limit", () => {
  const err = validateOptionalText("a".repeat(501), FIELD_LIMITS.notes, "notes");
  assert(err !== null && err.includes("notes") && err.includes("500"));
});

Deno.test("order status graph — vendor workflow + customer cancel", () => {
  assertEquals(canTransition("pending", "confirmed"), true);
  assertEquals(canTransition("confirmed", "preparing"), true);
  assertEquals(canTransition("preparing", "ready"), true);
  assertEquals(canTransition("ready", "completed"), true);
  assertEquals(canTransition("pending", "cancelled"), true);
});

Deno.test("order status graph — rejects illegal/terminal", () => {
  assertEquals(canTransition("pending", "completed"), false);
  assertEquals(canTransition("completed", "cancelled"), false);
  assertEquals(canTransition("cancelled", "pending"), false);
});

Deno.test("TERMINAL_STATUSES — completed/cancelled/rejected", () => {
  for (const s of ["completed", "cancelled", "rejected"]) {
    assert((TERMINAL_STATUSES as ReadonlySet<string>).has(s));
  }
});

// Extra coverage for the new _shared/orders.ts helpers
Deno.test("validateQuantity — stock checks", () => {
  assertEquals(validateQuantity(1, 10), null);
  assertEquals(validateQuantity(0, 10), "Quantity must be a positive number");
  assertEquals(validateQuantity(11, 10), "Insufficient stock");
  assertEquals(validateQuantity(NaN, 10), "Quantity must be a positive number");
});

Deno.test("isAllowedTransition — terminal + re-record", () => {
  assertEquals(isAllowedTransition("completed", "cancelled"), false);
  assertEquals(isAllowedTransition("preparing", "preparing"), true); // re-record
  assertEquals(isAllowedTransition("pending", "confirmed"), true);
});

Deno.test("withinCancelWindow — respects 5-min window", () => {
  const now = Date.now();
  const fresh = { toMillis: () => now - 60_000 } as unknown as { toMillis(): number };
  const stale = { toMillis: () => now - 10 * 60_000 } as unknown as { toMillis(): number };
  assertEquals(withinCancelWindow(fresh), true);
  assertEquals(withinCancelWindow(stale), false);
  assertEquals(withinCancelWindow(null), false);
});
