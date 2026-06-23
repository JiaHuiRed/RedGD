# Remote & Cloud Access

The MCP server starts on localhost by default. Remote access is only needed when the MCP client runs outside the same machine as Godot: a cloud IDE, another workstation, or a hosted AI tool.

## Mental model

```text
Remote MCP client ── public HTTPS URL ── tunnel ── localhost:9080 ── Godot MCP server
```

The public URL should point to the local MCP endpoint with `/mcp` appended.

## Before exposing the server

1. Enable `auth_enabled` in the MCP panel.
2. Set a long random `auth_token`.
3. Keep `security_level = 1`.
4. Enable only the advanced tool groups needed for the task.
5. Stop the tunnel when the remote session is done.

## Option A — Built-in Cloudflare Quick Tunnel

The MCP panel can manage a Cloudflare Quick Tunnel through `cloudflared`.

1. Start the local MCP server.
2. Enable auth if the tunnel will be shared.
3. Use the tunnel control in the MCP panel.
4. Copy the generated `https://*.trycloudflare.com` URL.
5. Configure the client with `<public-url>/mcp`.

Example client config:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "https://example.trycloudflare.com/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

### Manual Cloudflare fallback

If you manage `cloudflared` yourself:

```bash
cloudflared tunnel --url http://localhost:9080
```

Use the generated public base URL plus `/mcp`.

## Option B — Tailscale Funnel

Tailscale Funnel is useful when both machines are already in a Tailscale workflow.

```bash
tailscale funnel 9080
```

Then configure the client with the Funnel URL plus `/mcp` and the auth header.

## Option C — ngrok

ngrok works well for short-lived manual sessions:

```bash
ngrok http 9080
```

Use the HTTPS forwarding URL plus `/mcp`.

## stdio-only clients over a public URL

If the client only supports stdio but can run a local command, bridge with `mcp-remote`:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://example.trycloudflare.com/mcp",
        "--header",
        "Authorization: Bearer your-secret-token-here"
      ]
    }
  }
}
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Public URL opens but MCP calls fail | Ensure the client URL ends with `/mcp`. |
| 401/403 responses | Confirm the Bearer token exactly matches `auth_token`. |
| Tunnel starts but no URL appears | Check the MCP panel logs or run the tunnel command manually. |
| Client connects but tools are missing | Enable the required advanced groups with the MCP panel or `enable_tools`. |
| Connection is slow | Prefer a tunnel geographically close to the client and avoid enabling all advanced tools. |

## Shutdown checklist

- Stop the remote client session.
- Stop the tunnel.
- Rotate the token if it was shared outside your machine.
- Disable any advanced tool groups no longer needed.
