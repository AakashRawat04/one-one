import assert from "node:assert/strict";
import test from "node:test";
import {
  hashDeveloperRedeemCode,
  isDeveloperRedeemCodeValid
} from "../src/subscriptions/developerAccessService.js";

test("developer code matching is case and surrounding-space insensitive", () => {
  const hash = hashDeveloperRedeemCode("TEAM-ACCESS-0123456789");
  assert.equal(
    isDeveloperRedeemCodeValid("  team-access-0123456789  ", [hash]),
    true
  );
});

test("developer code matching rejects invalid hashes and other codes", () => {
  const hash = hashDeveloperRedeemCode("TEAM-ACCESS-0123456789");
  assert.equal(isDeveloperRedeemCodeValid("OTHER-CODE-0123456789", [hash]), false);
  assert.equal(isDeveloperRedeemCodeValid("TEAM-ACCESS-0123456789", ["invalid"]), false);
});
