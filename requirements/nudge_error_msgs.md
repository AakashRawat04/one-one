---

### A. Delivery acceptance (after API accepts send) — same 3 you’ve been hitting

| # | Message you see | When |
|---|---|---|
| 1 | **No active friends were found for this nudge.** | `recipientUsers == 0` — no other active group members / accounts |
| 2 | **The recipient has no registered Android device. Ask them to open Duo once.** | Friends exist, but `targetDevices == 0` (no active FCM device) |
| 3 | **Couldn't deliver notification. Please check your connection.** | Devices found, but FCM rejected all (`sent == 0` / FCM-BE-W1) |

Source: `nudge_repository.dart` → `_requireAcceptedDelivery`

---

### B. In-app send sheet — pre-send / local blocks

| Message | When |
|---|---|
| Invite a friend before sending a nudge. | Empty group |
| Everyone is already online. / Everyone is already online — no nudge needed. | All targets already live |
| Mute your mic first to send a voice nudge. | You're unmuted in voice |
| Microphone permission is required. | Mic denied |
| Hold a little longer to record. | Voice clip too short |
| Recording discarded | Swipe-up cancel |
| Recording… swipe up to cancel | Holding to record |
| Release to delete | Cancel armed |
| Release to send… swipe up to cancel | Hit max length, still holding |

---

### C. In-app send sheet — API / network catch-all (`_friendlyError`)

| Message | When |
|---|---|
| Backend rate-limit text (see §E) | `nudge_rate_limited` — uses server message as-is |
| Nudge limit reached. Please wait before trying again. | Rate-limit string detected in error text |
| Recording was too large. Try again. | `voice_nudge_too_large` |
| **Couldn't send the nudge. Check your connection.** | Catch-all (includes `no_recipient_devices`, timeouts, unknown API errors) |
| Couldn't deliver notification. Please check your connection. | Any error containing FCM/worker codes (sanitized) |

---

### D. In-app — after send, delivery confirmation (ring/voice)

| Message | When |
|---|---|
| Delivering ring/voice nudge… / Confirming if they received… / Confirming delivery… | Waiting |
| Nudge wasn't played, try again. | Timed out waiting, no results |
| Nudge wasn't delivered to anyone in this group. | Full FCM/send failure or all recipients failed |
| Nudge wasn't delivered to X of Y people. | Partial failure |
| Nudge did not reach {Name}. | Per-person fail (generic / timeout / no ack) |
| Nudge did not reach {Name} — something went wrong on Duo's end. | `playback_error` / `download_failed` |
| {Names} did not receive the nudge. | Multi fail, nobody played |
| {Names} did not receive the nudge — everyone else did. | Partial |
| Last nudge to {Names} wasn't received. | Persisted partial |
| Played on {Name}'s device / Nudge received on {Name}'s device | Single success |
| Everyone received the nudge ✓ / Nudge sent to {Name} ✓ | Success |
| ⚠️ {Name} is muted | Played but muted |
| ⚠️ {Name}'s volume is very low (&lt;25%) | Played, very low |
| ⚠️ {Name}'s volume is low (&lt;50%) | Played, low |

---

### E. Backend rate-limit / validation (often shown raw on sender)

| Code | Message |
|---|---|
| `nudge_rate_limited` | You're sending nudges too quickly. Try again in N seconds. |
| `nudge_rate_limited` | Nudge limit reached. Try again in N seconds. |
| `nudge_rate_limited` | Please wait N seconds before sending another {push/ring/voice}. |
| `nudge_rate_limited` | Please wait N seconds before nudging this friend again. |
| `nudge_rate_limited` | Ring is temporarily unavailable for the selected recipient. |
| `no_recipient_devices` | At least one recipient device is required. → usually becomes **Couldn't send… Check your connection** |
| `invalid_voice_nudge_duration` | Voice nudges must be between 250ms and 6000ms. |
| `voice_nudge_too_large` | → **Recording was too large. Try again.** |
| `invalid_voice_nudge_audio` | Voice nudge must be an M4A file. |
| `voice_nudge_upload_expired` | Voice nudge upload has expired. |
| `target_user_required` / `target_users_required` | Missing target fields |

---

### F. Android widget / quick-record (native)

| Message | Source |
|---|---|
| They're already live — no voice nudge needed. | QuickRecord |
| Microphone permission is needed to send a voice nudge. | QuickRecord |
| No group selected for this widget. | QuickRecord |
| Couldn't start recording. / Recording failed. | QuickRecord |
| Hold on a little longer to send a nudge. | QuickRecord |
| Couldn't send: {API message} | QuickRecord (raw backend/API text) |
| Couldn't send | Badge |
| Couldn't send ring nudge: {msg} | Widget ring |
| Couldn't send notification: {msg} | Widget push |
| Already notified — try again in a bit | Widget push dedupe |
| Ring sent / Notification sent / Sent | Success toasts |

Widget failures often show raw codes like `not_signed_in`, `HTTP 400 …`, `no_recipient_devices`, `network_error`.

---

### Quick map of the 3 you saw on the same friend

| You saw | Real meaning |
|---|---|
| No active friends… | Backend found **0 people** for that send |
| No registered Android device… | Friend exists, **0 FCM devices** |
| Check your connection / Couldn't send… | FCM rejected tokens **or** catch-all wrapping `no_recipient_devices` |

Same user can flip between #2 and #3 if their device row appears then FCM rejects the token — still not your network.

Want me to tighten those three into clearer, non-network wording next?