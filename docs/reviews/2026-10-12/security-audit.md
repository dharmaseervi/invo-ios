# Security review — 12 October 2026

Current backend: `357a042`; iOS: `2fc3c93`. This is local source review and targeted regression testing, not a production penetration test. All executable security checks used synthetic records in a temporary local PostgreSQL database. No production account, credential or business data was used.

## S1 — P1: delivery challans allow cross-company references

[CreateChallan](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/challan_handler.go:31>) verifies access to the requested company, then inserts the supplied client, invoice and item IDs without verifying that they belong to that same company. [GetChallanByID](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/challan_handler.go:153>) authorizes the challan but joins the referenced client and items without additional tenant constraints.

**Reproduced:** a user with access only to company A created a challan in A referencing company B's customer, item and invoice. Creation returned 201. Reading the new challan returned B's customer name and item name. This demonstrates unauthorized disclosure and invalid cross-company associations; it does not demonstrate arbitrary access to all of B's records.

Prerequisite: a signed-in user who can create a challan and supplies valid foreign IDs. The mobile UI hiding such IDs is not a server protection.

Fix: validate every reference against the authorized company, including invoice/client relationship, before any write. Backstop relationships with appropriate database constraints where practical. Validate dates, quantities and allowed state transitions separately. Audit existing records for invalid references before assuming old data is clean.

Acceptance: foreign-company client/item/invoice IDs are rejected atomically; valid same-company references work; mixed-company arrays cannot partly insert. This matches the object authorization class described by [OWASP](https://api-security.owasp.org/editions/2023/en/0xa1-broken-object-level-authorization/).

## S2 — P1: a refresh credential survives logout and password reset

[Logout](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/auth.go:417>) and [ResetPassword](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/auth.go:640>) invalidate access tokens by incrementing the user's session version. They do not revoke the corresponding rows in `sessions`. [RefreshTokens](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/session_handler.go:92>) checks a refresh hash and expiry, then mints a token using the **new current user session version** at line 127.

**Reproduced:** an old access token correctly returned 401 after logout. A copied pre-logout refresh credential then obtained a new access token, and that token accessed a protected probe successfully. The same sequence succeeded after an actual password-reset handler call.

Prerequisite: possession of a valid refresh credential. This is persistence after credential compromise, not a demonstrated way to steal that credential.

Fix: revoke affected refresh sessions and invalidate access in the same security transition. Define whether ordinary logout affects one device or all devices and make copy/UI match. Password reset must invalidate prior credentials, with any replacement session created only afterward. Bind refresh sessions to an authentication version or equivalent revocation state; make rotation atomic and test concurrent attempts.

Acceptance: both the old access and refresh credentials fail after reset/logout under the declared policy; newly authenticated credentials work. Test concurrent refresh/reset and refresh/logout, rather than only sequential requests.

## S3 — P1: device revocation does not revoke that device's access JWT

[RevokeSession](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/session_handler.go:185>) deletes a refresh-session row. Access JWTs contain no session identifier, and [AuthMiddleware](</Users/dharmaseervi/Desktop/invo-server/internal/middleware/auth.go:122>) checks user-wide state rather than that session. The configured access-token lifetime is seven days in [route setup](</Users/dharmaseervi/Desktop/invo-server/internal/routes/route.go:61>).

**Reproduced:** minted an access token by refreshing a particular synthetic device session, deleted that exact session, then confirmed its rotated refresh credential returned 401 while its access token still returned 200 on the protected probe.

Fix: make device/session identity enforceable by the API and shorten access lifetime as appropriate. A short expiry reduces exposure but is not immediate revocation. Plan compatibility for existing shipped clients instead of unexpectedly invalidating all sessions without a rollout. UI must accurately describe revocation behavior.

Acceptance: a revoked device cannot use either credential; another retained device continues to work; revoke-all-others preserves only the intended session; revocation handles concurrent requests consistently.

## S4 — P1: new cost-report routes bypass the role policy

These registered routes have no entry in [the permission table](</Users/dharmaseervi/Desktop/invo-server/internal/middleware/permissions.go:137>):

- `GET /api/v1/companies/:companyId/reports/supplier-aging`
- `GET /api/v1/purchase-returns/:id/pdf`

[Permissions](</Users/dharmaseervi/Desktop/invo-server/internal/middleware/permissions.go:225>) lets unlisted routes pass through. [Supplier aging](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/aging_report_handler.go:59>) and [debit-note PDF](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/purchase_handler.go:762>) check company membership, which includes staff, but do not enforce the cost permission themselves. Ordinary staff can therefore reach financial information that their normal supplier screens deny.

Verification: executable policy lookup confirmed both omissions; handler inspection confirmed membership-only checks. This particular finding was not exercised as a complete PDF/report HTTP request.

Fix: register the correct permission and company resolver for every route. Add a coverage test that every authenticated business route is either explicitly governed or explicitly exempted. An existing check that named policies point to routes does not catch routes with no policy.

Acceptance: owner/allowed roles succeed and staff/foreign members fail on both endpoints, including conflicting path/query IDs. Cover newly added challan and public-share management routes in the policy inventory too.

## Improvements present in current code

- Production-style same-origin web authentication uses an HttpOnly cookie and removes old localStorage access tokens. The earlier blanket statement that production web auth uses localStorage is stale. See [api.ts](</Users/dharmaseervi/Desktop/invo-server/web/src/lib/api.ts:43>) and [cookie creation](</Users/dharmaseervi/Desktop/invo-server/internal/handlers/auth.go:707>).
- The cross-origin development path still stores a bearer token when `NEXT_PUBLIC_API_ORIGIN` is nonempty. Production build configuration must keep that development path disabled; this review did not inspect deployed environment variables.
- iOS credentials use Keychain, and the release API uses HTTPS. Debug-local HTTP configuration is not a release vulnerability.
- Company checks, role checks, request deadlines, decimal calculations, and transaction/row locking already exist in substantial parts of the backend. The new paths need to uphold those existing protections.

## Proof and limits

The temporary Go overlay test invoked current handlers and middleware against a local PostgreSQL schema. It confirmed S1–S3 and the policy-table part of S4. Passing here means the test successfully reproduced the defect; it does not mean the code is secure.

No production deployment version, TLS configuration, dependency vulnerability feed, hosting permissions, backup restore, external attack surface, or Apple distribution binary was independently verified. There is no evidence from this review of a past compromise, arbitrary remote code execution, or an unauthenticated complete-account takeover.

The accurate answer to “is it easy to hack?” is: **there are concrete authorization and session-revocation weaknesses that should block a release of this code; overall exploitability depends on which version is deployed and the attacker's access.**
