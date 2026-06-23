// homelab-glance — Scriptable Keychain setup
// Run this script ONCE inside Scriptable to store your secrets securely.
// After running, you can delete this script — the values persist in the Keychain.
//
// Usage:
//   1. Open Scriptable on your iPhone
//   2. Create a new script and paste this entire file
//   3. Fill in your WIDGET_TOKEN and AGGREGATOR_URL below
//   4. Tap Run — you'll see a confirmation alert
//   5. Delete this script (the Keychain entries survive)

const WIDGET_TOKEN = "PASTE_YOUR_WIDGET_TOKEN_HERE"
const AGGREGATOR_URL = "http://YOUR_SERVER_IP:8765/api/dashboard"

Keychain.set("homelab_glance_token", WIDGET_TOKEN)
Keychain.set("homelab_glance_url", AGGREGATOR_URL)

const alert = new Alert()
alert.title = "Keychain setup complete"
alert.message = `Stored:\n• homelab_glance_token\n• homelab_glance_url\n\nYou can now delete this script.`
alert.addAction("OK")
await alert.present()
