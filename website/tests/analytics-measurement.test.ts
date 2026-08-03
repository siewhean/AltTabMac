import assert from "node:assert/strict";
import test from "node:test";

import {
  isComparableOptionalAnalyticsWindow,
  OPTIONAL_ANALYTICS_PRODUCTION_STARTED_AT,
} from "../src/lib/analytics-measurement.js";

test("optional analytics windows do not compare across the production-consent boundary", () => {
  const boundary = new Date(OPTIONAL_ANALYTICS_PRODUCTION_STARTED_AT);

  assert.equal(
    isComparableOptionalAnalyticsWindow(7, new Date(boundary.getTime() + 7 * 24 * 60 * 60 * 1000 - 1)),
    false,
  );
  assert.equal(
    isComparableOptionalAnalyticsWindow(7, new Date(boundary.getTime() + 7 * 24 * 60 * 60 * 1000)),
    true,
  );
});
