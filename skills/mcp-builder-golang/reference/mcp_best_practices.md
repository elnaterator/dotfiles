# MCP Server Best Practices

## Quick Reference

### Server Naming
- **Python**: `{service}_mcp` (e.g., `slack_mcp`)
- **Node/TypeScript**: `{service}-mcp-server` (e.g., `slack-mcp-server`)
- **Go**: `{service}-mcp-server` (e.g., `slack-mcp-server`)

### Tool Naming
- Use snake_case with service prefix
- Format: `{service}_{action}_{resource}`
- Example: `slack_send_message`, `github_create_issue`

### Response Formats
- Support both JSON and Markdown formats
- JSON for programmatic processing
- Markdown for human readability

### Pagination
- Always respect `limit` parameter
- Return `has_more`, `next_cursor`/`next_offset`, `total`
- Default to 20-50 items

### Transport
- **Streamable HTTP**: For remote servers, multi-client scenarios
- **stdio**: For local integrations, command-line tools
- Avoid SSE (deprecated in favor of streamable HTTP)

---

## Server Naming Conventions

Follow these standardized naming patterns:

**Python**: Use format `{service}_mcp` (lowercase with underscores)
- Examples: `slack_mcp`, `github_mcp`, `jira_mcp`

**Node/TypeScript**: Use format `{service}-mcp-server` (lowercase with hyphens)
- Examples: `slack-mcp-server`, `github-mcp-server`, `jira-mcp-server`

**Go**: Use format `{service}-mcp-server` (lowercase with hyphens)
- Examples: `slack-mcp-server`, `github-mcp-server`, `jira-mcp-server`

The name should be general, descriptive of the service being integrated, easy to infer from the task description, and without version numbers.

---

## Tool Naming and Design

### Tool Naming

1. **Use snake_case**: `search_users`, `create_project`, `get_channel_info`
2. **Include service prefix**: Anticipate that your MCP server may be used alongside other MCP servers
   - Use `slack_send_message` instead of just `send_message`
   - Use `github_create_issue` instead of just `create_issue`
3. **Be action-oriented**: Start with verbs (get, list, search, create, update, delete)
4. **Be specific**: Avoid generic names that could conflict with other servers

### Tool Design

- Tool descriptions must narrowly and unambiguously describe functionality
- Descriptions must precisely match actual functionality
- Provide tool annotations (readOnlyHint, destructiveHint, idempotentHint, openWorldHint)
- Keep tool operations focused and atomic

---

## Response Formats

All tools that return data should support multiple formats:

### JSON Format (`response_format="json"`)
- Machine-readable structured data
- Include all available fields and metadata
- Consistent field names and types
- Use for programmatic processing

### Markdown Format (`response_format="markdown"`, typically default)
- Human-readable formatted text
- Use headers, lists, and formatting for clarity
- Convert timestamps to human-readable format
- Show display names with IDs in parentheses
- Omit verbose metadata

### Go Example

```go
type ResponseFormat string

const (
    FormatMarkdown ResponseFormat = "markdown"
    FormatJSON     ResponseFormat = "json"
)

type SearchParams struct {
    Query          string         `json:"query"`
    Limit          int            `json:"limit,omitempty"`
    ResponseFormat ResponseFormat `json:"response_format,omitempty"`
}

func (c *Client) Search(ctx context.Context, req *mcp.CallToolRequest, args SearchParams) (*mcp.CallToolResult, any, error) {
    results := fetchResults(args.Query, args.Limit)

    if args.ResponseFormat == FormatJSON {
        b, _ := json.MarshalIndent(results, "", "  ")
        return textResult(string(b)), nil, nil
    }

    // Default: Markdown
    var sb strings.Builder
    for _, r := range results {
        sb.WriteString(fmt.Sprintf("- **%s**: %s\n", r.Name, r.Description))
    }
    return textResult(sb.String()), nil, nil
}

func textResult(text string) *mcp.CallToolResult {
    return &mcp.CallToolResult{
        Content: []mcp.Content{&mcp.TextContent{Text: text}},
    }
}
```

---

## Pagination

For tools that list resources:

- **Always respect the `limit` parameter**
- **Implement pagination**: Use `cursor` or `offset`-based pagination
- **Return pagination metadata**: Include `has_more`, `next_cursor`/`next_offset`, `total`
- **Never load all results into memory**: Especially important for large datasets
- **Default to reasonable limits**: 20-50 items is typical

Example pagination response (JSON):
```json
{
  "total": 150,
  "count": 20,
  "has_more": true,
  "next_cursor": "eyJpZCI6MjB9",
  "items": [...]
}
```

### Go Pagination Pattern

```go
type ListParams struct {
    Limit  int    `json:"limit,omitempty"`
    Cursor string `json:"cursor,omitempty"`
}

func (c *Client) ListItems(ctx context.Context, req *mcp.CallToolRequest, args ListParams) (*mcp.CallToolResult, any, error) {
    limit := args.Limit
    if limit == 0 {
        limit = 20
    }
    if limit > 100 {
        limit = 100
    }
    // pass limit and args.Cursor to your API call
    // include has_more and next_cursor in the response
}
```

---

## Transport Options

### Streamable HTTP

**Best for**: Remote servers, web services, multi-client scenarios

**Characteristics**:
- Bidirectional communication over HTTP
- Supports multiple simultaneous clients
- Can be deployed as a web service
- Enables server-to-client notifications

**Use when**:
- Serving multiple clients simultaneously
- Deploying as a cloud service
- Integration with web applications

### stdio

**Best for**: Local integrations, command-line tools

**Characteristics**:
- Standard input/output stream communication
- Simple setup, no network configuration needed
- Runs as a subprocess of the client

**Use when**:
- Building tools for local development environments
- Integrating with desktop applications
- Single-user, single-session scenarios

**Critical for Go stdio servers**: Call `log.SetOutput(os.Stderr)` at the very start of `main()`. Never write to `os.Stdout` — that stream is exclusively for MCP protocol messages.

### Transport Selection

| Criterion | stdio | Streamable HTTP |
|-----------|-------|-----------------|
| **Deployment** | Local | Remote |
| **Clients** | Single | Multiple |
| **Complexity** | Low | Medium |
| **Real-time** | No | Yes |

---

## Security Best Practices

### Authentication and Authorization

**OAuth 2.1**:
- Use secure OAuth 2.1 with certificates from recognized authorities
- Validate access tokens before processing requests
- Only accept tokens specifically intended for your server

**API Keys**:
- Store API keys in environment variables, never in code
- Validate keys on server startup with clear error messages
- Fail immediately if a required key is missing

### Input Validation

- Validate required fields explicitly in each handler
- Sanitize file paths to prevent directory traversal
- Validate URLs and external identifiers
- Check parameter sizes and ranges (enforce max `limit` values)
- Prevent command injection in any system calls

### Error Handling

- Do not expose internal errors or stack traces to clients
- Log security-relevant errors server-side (to stderr)
- Provide helpful but not revealing error messages
- Clean up resources after errors (use `defer` in Go)

### DNS Rebinding Protection

For streamable HTTP servers running locally:
- Validate the `Origin` header on all incoming connections
- Bind to `127.0.0.1` rather than `0.0.0.0`

---

## Tool Annotations

Provide annotations to help clients understand tool behavior:

| Annotation | Type | Default | Description |
|-----------|------|---------|-------------|
| `readOnlyHint` | bool | false | Tool does not modify its environment |
| `destructiveHint` | bool | true | Tool may perform destructive updates |
| `idempotentHint` | bool | false | Repeated calls with same args have no additional effect |
| `openWorldHint` | bool | true | Tool interacts with external entities |

In Go, all annotation fields are `*bool`. Use `mcp.Ptr(true)` / `mcp.Ptr(false)`.

**Annotations are hints, not security guarantees.** Clients should not make security-critical decisions based solely on annotations.

---

## Error Handling

- Use standard JSON-RPC error codes
- Report tool errors by returning a non-nil `error` from the handler (Go SDK handles the wrapping)
- Provide helpful, specific error messages with suggested next steps
- Do not expose internal implementation details
- Clean up resources properly on errors

**Good error message:**
```
resource not found: verify that ID "abc123" exists and you have permission to access it
```

**Bad error message:**
```
404
```

---

## Testing Requirements

Comprehensive testing should cover:

- **Functional testing**: Verify correct execution with valid and invalid inputs
- **Integration testing**: Test interaction with external systems
- **Security testing**: Validate auth, input sanitization, rate limiting
- **Performance testing**: Check behavior under load, timeouts
- **Error handling**: Ensure proper error reporting and cleanup

For Go:
```bash
go test ./...
go vet ./...
go build ./...
```

---

## Documentation Requirements

- Provide clear descriptions for all tools
- Document all parameters in the tool's `Description` field (or use `jsonschema` description tags)
- Document required vs. optional parameters
- Specify required environment variables and how to obtain credentials
- Document rate limits and performance characteristics
