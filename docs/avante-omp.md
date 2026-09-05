# Avante.nvim with OMP ACP

The shared Neovim module configures [Avante.nvim](https://github.com/yetone/avante.nvim) as an Agent Client Protocol (ACP) client for the native OMP server:

```text
Avante.nvim -> ACP over stdio -> omp acp
```

The configured command is the Nix-built `programs.omp.package` executable. This makes GUI-launched Neovim independent of a shell profile path and keeps a downstream `programs.omp.package` override authoritative.

## Use

Open a code file and use:

- `:AvanteToggle` to open or close the sidebar.
- `:AvanteAsk` to ask about the current context.
- `:AvanteStop` to cancel the active request.
- `:AvanteSwitchProvider` to open the provider picker and select `omp`.

OMP is the default provider. This configuration also fixes an Avante bug in the
pinned release: its upstream picker discards the table extension that should
add ACP providers. Remove the local picker replacement once an Avante update
includes ACP providers itself.

OMP owns authentication, model selection, agent configuration, tools, extensions, and persisted state. Complete OMP onboarding and authentication outside Avante when needed. Avante forwards the current file and presents the editor-side ACP interaction.

## Permissions and supported work

Automatic tool approval is disabled. OMP sends its ACP `session/request_permission`
request for Bash and mutating tools; review its Allow/Deny control in Avante before
the tool can run.

OMP normally follows that ACP decision with its own TUI approval for Bash. Avante
0.0.27 cannot render the ACP elicitation required by that second prompt, so its
ACP launch receives a private configuration overlay with only
`tools.approval.bash: allow`. This leaves the ACP Allow/Deny gate intact and does
not alter normal OMP or OMP TUI policy.

Avante 0.0.27 also does not implement ACP terminal delegation. Bash output is
shown as a tool-call result rather than an editor terminal card.

Use Avante + OMP ACP for synchronous editor tasks. Do not rely on it to report work that an agent starts after the prompt has completed, including deliberately detached shell jobs, asynchronous task batches, or long-running subagents. The ACP wake/resume lifecycle is not yet a reliable Avante + OMP contract. Use the native OMP TUI for that work instead.
