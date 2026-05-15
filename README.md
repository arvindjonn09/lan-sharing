# Same Network Fast Sharing

A local-network mesh-style Web UI for sending large files and folders between browser devices with chunked, retryable uploads and sender verification codes.

## What It Does

- Lets every browser device choose any other online browser device.
- Shows a one-time verification code on the sender screen.
- Requires the receiving device to enter that code before upload starts.
- Sends files and selected folders from a browser.
- Splits every file into chunks.
- Hashes each chunk with SHA-256 before upload.
- Retries failed chunks instead of restarting the whole file.
- Preserves folder paths.
- Writes incoming files as `.partial`, then renames after assembly.
- Stores transfer manifests and chunks in `transfer-data`.
- Saves completed files into `received/<target-device>/<transfer-id>`.
- Shows completed incoming transfers as download links in the target device inbox.
- Offers receiver-side `Download with progress` plus a normal `Browser download` link.
- Runs cleanup on startup and every 12 hours.

## Run

```powershell
go run .
```

Open the app on the hub device:

```text
http://localhost:8080
```

From every phone, tablet, or computer on the same Wi-Fi/LAN, open the hub's LAN address:

```text
http://HUB_IP:8080
```

The server prints available LAN URLs when it starts.

## Mesh Flow

1. Run the hub on one computer.
2. Open the hub URL on every device.
3. Give each device a clear name.
4. On the sender, select the target device from `Online Devices`.
5. Select files or a folder.
6. Click `Send to selected device`.
7. The sender screen shows a 6-digit code.
8. The receiver enters that code in `Incoming`.
9. Upload starts only after the code matches.
10. The receiver downloads completed files from its inbox.

## Windows Firewall

If another device cannot open the page, allow inbound traffic for port `8080` or allow the Go app through Windows Firewall.

## Recommended Transfer Settings

- Chunk size: `8 MB` for normal Wi-Fi.
- Chunk size: `16 MB` or `32 MB` for wired LAN.
- Parallel chunks: `4` to start.
- Retry limit: `5`.

## Cleanup

The hub cleanup job runs on startup and every 12 hours.

- Completed transfers are kept for 7 days.
- Incomplete transfer chunks are kept for 48 hours.
- Runtime folders are ignored by git:
  - `received`
  - `transfer-data`

## Receiver Downloads

The inbox shows two download options after a transfer completes:

- `Download with progress`: shows progress inside the Web UI, but the browser keeps the file in memory before saving.
- `Browser download`: lets the browser or operating system handle the download, which is better for very large files and background-capable browsers.

## Build A Single Executable

```powershell
go build -o same-network-fast-sharing.exe .
```

Run:

```powershell
.\same-network-fast-sharing.exe
```

Keep the `static` folder beside the executable.

## Notes

This is hub-assisted mesh. iPhone and Android do not need an installed app, but their browser page must stay open while receiving and downloading. For true background receiving on phones, a native mobile app is required because mobile browsers restrict background file access.
