# Automated Device Enrollment Web Handoffs

Use for sysdiagnose evidence involving ADE, Setup Assistant, MDM enrollment, browser authentication handoffs, `mdmclient`, Safari authentication sessions or enrollment-profile delivery.

- Reconstruct ADE as distinct stages: cloud-configuration retrieval, MDM enrollment-profile request, browser authentication handoff, profile callback or download, profile installation, and MDM server connection.
- Success at one stage does not prove the next stage completed.
- Correlate `mdmclient`, Setup Assistant, Safari authentication-session, WebKit networking and content, and trust-evaluation events in one bounded window.
- Record the first stage without a matching completion event.
- When `ConfigurationWebURL` invokes `ASWebAuthenticationSession`, verify from logs that the browser received the configured path and session parameters.
- A browser title or compact address display showing only the hostname does not prove the path or query was omitted.
- Treat a successful DNS lookup, TLS trust evaluation or HTTP 200 main document as transport or page-load evidence only.
- Check immediate dependent requests for HTTP errors and confirm the flow ultimately returns the expected enrollment profile, commonly `application/x-apple-aspen-config`.
- Do not treat a presentation-context warning as causal when later events show the authentication session started and network requests ran. Correlate warnings with actual session completion or failure.
- Do not test a session-bound enrollment URL by stripping the query and inferring service health from the resulting status. A bare endpoint may correctly reject requests that lack enrollment context.
- Redact enrollment query values, tokens and device identifiers while preserving hostname, path, timestamp, status code, MIME type and request sequence needed for diagnosis. Use `<mdm-url>` for the MDM host in shared reports.
- If privacy redaction hides the exact failing dependent route, state the limitation and request vendor-side correlation using a narrow timestamp window and the observed status and MIME sequence.
