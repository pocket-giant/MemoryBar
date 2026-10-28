# MemoryBar — agent instructions

Preserve all existing project-specific instructions, safeguards and workflows.

## Browser automation

These permanent instructions apply to all future coding-agent sessions in this project. Browser selection depends on the agent provider.

### Codex / OpenAI agents

- Use the Chrome browser extension in Brave for browser interaction and automation, including inspection, visual audits, testing, navigation and web administration.
- This integration is already configured and tested. Do not repeatedly question whether it works, recheck compatibility unnecessarily or switch to Safari.

### Claude Code / Anthropic agents

- Use Safari for browser interaction and automation, using the available Safari automation tools.
- Do not attempt to use Codex's Chrome extension.

## Authentication and sign-in patience

When Simon needs to sign in manually, approve permissions, complete two-factor authentication or interact with a security prompt:

- Give him sufficient time to finish. Do not assume authentication has failed because it takes several minutes.
- Do not repeatedly refresh, navigate away or restart the browser.
- Do not close authentication windows or tabs.
- Do not interrupt an active sign-in flow with unnecessary tool calls.
- Wait for confirmation that authentication has completed before continuing. If necessary, pause and ask Simon to confirm when he is finished.
- Distinguish an automation-tool timeout from an actual authentication failure.
- Never abandon a sign-in process simply because Simon is taking longer than expected.

## General agent behaviour

- Perform tasks autonomously whenever possible; do not give Simon manual instructions for actions the agent can perform itself.
- Avoid unnecessary questions and repeated permission requests. Preserve existing project-specific approval requirements.
- Be patient during browser operations, uploads, downloads and long-running processes. Do not mistake slow progress for failure.
- Preserve existing browser sessions whenever possible.
