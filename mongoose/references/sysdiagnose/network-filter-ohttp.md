# Network Content Filters And OHTTP Privacy-Proxy Flows

Use when a symptom involves Apple privacy-proxy or Oblivious HTTP (OHTTP) traffic, such as a sign-in or service call that fails with a network error or a credential-fetch error, while a third-party Network Extension content filter, DNS proxy or VPN is present.

## Measure Outcomes Before Judging Cause

- Measure OHTTP outcomes across full unified-log coverage, not only the incident window. Report success / total per boot and per process.
- Pair each inner `ohttp transaction summary` or `Privacy proxy used` line with the outer `http3 transaction summary` logged by the same PID for the same root connection. An inner record alone does not show what happened on the relay stream.
- Separate DNS-stage failures from relay-stage failures. Requests that hit `resolver:dns_stall` or a DNS-proxy delay never reached a relay; exclude them from the relay-stage ratio and report them as their own item.
- Treat QUIC connection establishment and acknowledged keep-alives as transport health only. A healthy QUIC connection can carry a stalled HTTP/3 stream.

## Relay-Stream Stall Signature

Treat these together as one signature. One line alone is weak evidence.

- Outer `http3 transaction summary` shows an empty `request_method` and zero outbound body bytes.
- `nw_http3_remove_stream [C<n>…] … stream setup stalls incremented` on the outer relay stream.
- Relay sends `APPLICATION_CLOSE code 0` a few seconds after the inner request header. Relay operators can differ: some close after about 5 s, others let the request run to the client timeout.
- Client then logs `[-1005]`, POSIX 57 or a credential-fetch failure.

Pitfall: `stream setup stalls incremented` is also logged by `nw_protocol_http_joining_remove_input_handler` on the top-level connection during successful requests. Count only the outer relay-stream variant.

Success looks like an outer `request_method="POST"` with nonzero outbound body bytes and `response_status=200`, followed by the client's own success message.

## Content-Filter Attachment Evidence

- `nesessionmanager` lines with `NESMFilterSession[<filter-name>]` and `status changed`: when the filter connected or disconnected.
- `nesessionmanager` `Got a new agent client connection from <process>(<pid>)`: the client process opened the content-filter agent connection at flow start.
- The filter provider's own log lines showing it accepted an XPC peer from that PID, and the closed-flow events it received.
- `sysctl.txt`: `net.cfil.active_count`.
- `network-info/com.apple.networkextension.plist`, decoded read-only with `plutil -p`: filter configuration, enabled state, and `FilterSockets` / `FilterPackets`.
- `systemextensionsctl_diagnose.txt`: extension activation and enabled state.

Attached is not the same as acting. A filter can stay connected and receive every flow while the failure comes and goes. A vendor policy setting can change how the provider handles flows without detaching it. Name the provider's data-path components (socket filter, packet filter, DNS proxy, transparent proxy, VPN) before inferring where a stall comes from.

## Comparison Method

- Build a comparison table with one column per configuration: filter present, filter absent, and each setting change. Use the same signature rows in every column, from attachment through outcome.
- A transition within one boot, with no reboot, version change, network change or filter-configuration change in between, is strong evidence for whatever else changed in that window.
- A background client that uses the same path (for example `com.apple.Safari.SafeBrowsing.Service`) can stand in for an uncaptured user action. Label it as a stand-in signal.
- When a vendor console setting is not visible in the capture, state the observed transition window and ask for the console audit timestamp to match it.

## Example Predicates

Run each with `/usr/bin/log show --archive "$logarchive" --timezone '<Area/City>' --style compact --info --debug`, bounded by `--start` and `--end`. See [Archive And Log Commands](archive-and-log-commands.md).

```text
eventMessage CONTAINS "ohttp transaction summary" OR eventMessage CONTAINS "Privacy proxy used" OR eventMessage CONTAINS "http3 transaction summary"
process == "nesessionmanager" AND eventMessage CONTAINS "NESMFilterSession"
process == "nesessionmanager" AND eventMessage CONTAINS "agent client"
eventMessage CONTAINS "received APPLICATION_CLOSE" OR eventMessage CONTAINS "stream setup stalls" OR eventMessage CONTAINS "[-1005]"
eventMessage CONTAINS "dns_stall"
```

Redact QUIC connection IDs, account identifiers and SSIDs in reports unless a vendor needs them for server-side correlation.
