# Verification record

## Automated / local build

- Model suite: PASS (`scripts/test.sh`).
- Info.plist syntax: PASS.
- Native Swift app compilation: PASS on Apple Silicon.
- Screenshot preview uses a synthetic three-tab fixture; not evidence of actual Chrome capture.

## Manual acceptance (pending permissions)

Use a separate Chrome window with three disposable test tabs A, B, C. Avoid changing existing browsing work.

- [ ] Visit A → B → C, wait at least 0.6 s per page. Short Control–Tab goes to B; next gesture returns to C.
- [ ] Hold Control, press Tab twice: overlay appears, Chrome stays on C, selection advances; releasing Control activates A.
- [ ] Control–Shift–Tab cycles backwards, including wrap at both ends.
- [ ] Esc cancels; releasing Control afterward does not switch.
- [ ] Address bar, normal webpage, chrome://settings and full-screen all support the gesture.
- [ ] Command–Control–C copies the actual URL; verify by pasting into a disposable address bar, then Escape without navigating.
- [ ] Permission granted: visited pages get window previews. No permission: domain placeholders work.
- [ ] Incognito window never populates screenshot previews.
- [ ] Close/reorder selected tab while overlay is open: resolve by ID or fail safely.
- [ ] Change app/window during gesture: no activation in an unrelated window.
- [ ] Pause/quit restores Chrome's native shortcuts.
- [ ] Revoke accessibility/automation permission: app remains usable through menu and reports status.

Known precision limitation: history is polled every 300 ms; native Chromium integration would be required for exact browser-internal timing. Screenshot cache is not a live DOM or live background-tab preview.
