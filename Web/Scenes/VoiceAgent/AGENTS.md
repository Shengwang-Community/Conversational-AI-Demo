# VoiceAgent Web

Read the repository [maintainer workflow](../../../AI_ENGINEERING.md) and [AI guidance](../../../AI_WORKFLOW.md). Web changes originate in the internal `convoai-demo/web-next` project, then sync to each applicable public repository and are verified there. This directory contains the Next.js demo; [README.md](README.md) covers setup and runtime configuration.

- Use the published `agora-agent-client-toolkit` package declared in `package.json`. Keep package and lockfile changes together.
- Keep server-only credentials in server code. `NEXT_PUBLIC_*` values are exposed to browsers; never commit `.env.local` or real keys.
- Check RTC/RTM and Toolkit initialization, event subscriptions, transcript state and cleanup when changing a call flow.

From this directory, use the checks relevant to the change:

```bash
bun install --frozen-lockfile
bun run test
bun run typecheck
bun run lint
bun run build
```

Run the affected page or call flow manually when a change depends on browser behavior. Report any environment or service behavior that could not be verified.
