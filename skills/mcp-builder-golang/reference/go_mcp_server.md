# Go MCP Server Implementation Guide

## Quick Reference

### Key Imports

```go
import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/modelcontextprotocol/go-sdk/mcp"
)
```

### Server Initialization

```go
server := mcp.NewServer(&mcp.Implementation{
    Name:    "myservice-mcp-server",
    Version: "v1.0.0",
}, nil)
```

### Tool Registration

```go
mcp.AddTool(server, &mcp.Tool{
    Name:        "my_tool",
    Description: "Does something useful",
}, MyToolHandler)
```

`mcp.AddTool` is generic — it infers the params struct type from the handler signature and automatically generates a JSON schema for it.

---

## Server Naming Convention

Go MCP servers follow the same convention as TypeScript:

```
{service}-mcp-server
```

Examples: `github-mcp-server`, `slack-mcp-server`, `stripe-mcp-server`

Use lowercase with hyphens. No version numbers in the name.

---

## Project Structure

```
{service}-mcp-server/
├── main.go           # Entry point: server init, transport setup
├── tools/
│   ├── search.go     # One file per logical group of tools
│   └── create.go
├── client/
│   └── client.go     # HTTP client for the upstream API
├── go.mod
└── go.sum
```

Keep `main.go` thin: initialize the server, register tools, start the transport. Put tool logic in `tools/` and HTTP client code in `client/`.

---

## Tool Implementation

### Handler Signature

Every tool handler must have this exact signature:

```go
func HandlerName(ctx context.Context, req *mcp.CallToolRequest, args ParamsStruct) (*mcp.CallToolResult, any, error)
```

- `ctx` — request context; respect cancellation
- `req` — raw MCP request (usually not needed directly)
- `args` — your typed params struct, populated by the SDK from the JSON input
- First return — the MCP result with content
- Second return — structured content (pass `nil` unless you need structured output)
- Third return — error; return a non-nil error and the SDK converts it to an MCP error response

### Params Structs

Define a Go struct with `json` tags. The SDK generates the JSON schema automatically.

```go
type GetWeatherParams struct {
    Location string `json:"location"`
    Unit     string `json:"unit,omitempty"`
}
```

Use `omitempty` for optional fields. Add a description using the `jsonschema` tag if your version of the SDK supports it; otherwise document parameters in the tool's `Description` field.

### Complete Tool Example

```go
type GetWeatherParams struct {
    Location string `json:"location"`
    Unit     string `json:"unit,omitempty"` // "celsius" or "fahrenheit"
}

func GetWeather(ctx context.Context, req *mcp.CallToolRequest, args GetWeatherParams) (*mcp.CallToolResult, any, error) {
    if args.Location == "" {
        return nil, nil, fmt.Errorf("location is required")
    }

    unit := args.Unit
    if unit == "" {
        unit = "fahrenheit"
    }

    // Call your API here...
    result := fmt.Sprintf("Weather in %s: 72°F and sunny", args.Location)

    return &mcp.CallToolResult{
        Content: []mcp.Content{
            &mcp.TextContent{Text: result},
        },
    }, nil, nil
}

// Registration in main.go or tools package:
func RegisterWeatherTools(server *mcp.Server) {
    mcp.AddTool(server, &mcp.Tool{
        Name:        "get_weather",
        Description: "Get current weather conditions for a location. Returns temperature and conditions. Unit defaults to fahrenheit; pass unit=celsius for metric.",
        Annotations: &mcp.ToolAnnotations{
            ReadOnlyHint:   mcp.Ptr(true),
            IdempotentHint: mcp.Ptr(true),
        },
    }, GetWeather)
}
```

---

## Tool Annotations

Set annotations on every tool so clients can reason about safety and caching:

```go
Annotations: &mcp.ToolAnnotations{
    ReadOnlyHint:    mcp.Ptr(true),   // true: tool does not modify state
    DestructiveHint: mcp.Ptr(false),  // true: may delete or overwrite data
    IdempotentHint:  mcp.Ptr(false),  // true: calling twice has same effect as once
    OpenWorldHint:   mcp.Ptr(true),   // true: interacts with external systems
}
```

Always use `mcp.Ptr(value)` — annotation fields are `*bool`, not `bool`.

**Decision guide:**
- Read operations (GET, list, search): `ReadOnly=true, Destructive=false, Idempotent=true`
- Create operations (POST): `ReadOnly=false, Destructive=false, Idempotent=false`
- Update operations (PUT/PATCH): `ReadOnly=false, Destructive=false, Idempotent=true` (PUT) or `false` (PATCH)
- Delete operations: `ReadOnly=false, Destructive=true, Idempotent=true`

---

## Error Handling

Return errors from the handler function. The SDK wraps them into a proper MCP error response automatically.

```go
func MyTool(ctx context.Context, req *mcp.CallToolRequest, args MyParams) (*mcp.CallToolResult, any, error) {
    resp, err := http.Get(url)
    if err != nil {
        return nil, nil, fmt.Errorf("API request failed: %w", err)
    }
    defer resp.Body.Close()

    switch resp.StatusCode {
    case http.StatusNotFound:
        return nil, nil, fmt.Errorf("resource not found: verify the ID %q is correct", args.ID)
    case http.StatusTooManyRequests:
        return nil, nil, fmt.Errorf("rate limit exceeded: wait a moment before retrying")
    case http.StatusUnauthorized:
        return nil, nil, fmt.Errorf("authentication failed: check that MYSERVICE_API_KEY is set correctly")
    }

    if resp.StatusCode >= 400 {
        return nil, nil, fmt.Errorf("API error (HTTP %d): check the request parameters", resp.StatusCode)
    }

    // ... parse body and return result
}
```

**Write actionable error messages.** Tell the agent what to do next — not just what went wrong.

---

## Transport: stdio (Local Tools)

Use stdio when the server runs as a subprocess of the MCP client (e.g., Claude Desktop, VS Code extensions).

```go
func main() {
    // CRITICAL: redirect all logging to stderr before anything else
    log.SetOutput(os.Stderr)

    apiKey := os.Getenv("MYSERVICE_API_KEY")
    if apiKey == "" {
        fmt.Fprintln(os.Stderr, "ERROR: MYSERVICE_API_KEY environment variable is required")
        os.Exit(1)
    }

    server := mcp.NewServer(&mcp.Implementation{
        Name:    "myservice-mcp-server",
        Version: "v1.0.0",
    }, nil)

    client := NewClient(apiKey)
    client.RegisterTools(server)

    ctx := context.Background()
    transport, err := mcp.NewStdioTransport()
    if err != nil {
        log.Fatal(err)
    }

    session, err := server.Connect(ctx, transport, nil)
    if err != nil {
        log.Fatal(err)
    }

    // Block until client disconnects
    session.Wait()
}
```

**Never write to `os.Stdout` in a stdio server.** The entire stdout stream is the MCP protocol. Use `log.Printf` (after `log.SetOutput(os.Stderr)`) or `fmt.Fprintln(os.Stderr, ...)` for diagnostic output.

---

## Transport: Streamable HTTP (Remote Servers)

Use streamable HTTP when deploying as a service that multiple clients connect to.

```go
func main() {
    log.SetOutput(os.Stderr)

    apiKey := os.Getenv("MYSERVICE_API_KEY")
    if apiKey == "" {
        fmt.Fprintln(os.Stderr, "ERROR: MYSERVICE_API_KEY environment variable is required")
        os.Exit(1)
    }

    server := mcp.NewServer(&mcp.Implementation{
        Name:    "myservice-mcp-server",
        Version: "v1.0.0",
    }, nil)

    client := NewClient(apiKey)
    client.RegisterTools(server)

    mcpHandler := mcp.NewStreamableHTTPHandler(func(r *http.Request) *mcp.Server {
        return server
    }, nil)

    mux := http.NewServeMux()
    mux.HandleFunc("/mcp", func(w http.ResponseWriter, r *http.Request) {
        mcpHandler.ServeHTTP(w, r)
    })

    addr := ":8080"
    log.Printf("MCP server listening on %s", addr)
    log.Fatal(http.ListenAndServe(addr, mux))
}
```

For production deployments, bind to a specific interface and add authentication middleware before the MCP handler.

---

## Environment Variables and API Keys

Always load and validate credentials at startup, before registering any tools:

```go
func main() {
    log.SetOutput(os.Stderr)

    apiKey := os.Getenv("MYSERVICE_API_KEY")
    if apiKey == "" {
        fmt.Fprintln(os.Stderr, "ERROR: MYSERVICE_API_KEY environment variable is required")
        fmt.Fprintln(os.Stderr, "Set it with: export MYSERVICE_API_KEY=your_key_here")
        os.Exit(1)
    }

    baseURL := os.Getenv("MYSERVICE_BASE_URL")
    if baseURL == "" {
        baseURL = "https://api.example.com/v1" // sensible default
    }

    // proceed with server setup...
}
```

Fail fast with a clear message. The agent or operator needs to know exactly which variable is missing and how to fix it.

---

## Passing Config to Tools (Closures Pattern)

Do not use package-level variables for clients. Pass configuration via closures using a client struct with methods:

```go
// client/client.go

package client

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "time"

    "github.com/modelcontextprotocol/go-sdk/mcp"
)

type Client struct {
    apiKey  string
    baseURL string
    http    *http.Client
}

func NewClient(apiKey, baseURL string) *Client {
    return &Client{
        apiKey:  apiKey,
        baseURL: baseURL,
        http:    &http.Client{Timeout: 30 * time.Second},
    }
}

func (c *Client) RegisterTools(server *mcp.Server) {
    mcp.AddTool(server, &mcp.Tool{
        Name:        "example_search",
        Description: "Search for items in the service",
        Annotations: &mcp.ToolAnnotations{
            ReadOnlyHint:   mcp.Ptr(true),
            IdempotentHint: mcp.Ptr(true),
        },
    }, c.Search)

    mcp.AddTool(server, &mcp.Tool{
        Name:        "example_create",
        Description: "Create a new item in the service",
        Annotations: &mcp.ToolAnnotations{
            ReadOnlyHint:    mcp.Ptr(false),
            DestructiveHint: mcp.Ptr(false),
        },
    }, c.Create)
}

type SearchParams struct {
    Query  string `json:"query"`
    Limit  int    `json:"limit,omitempty"`
    Cursor string `json:"cursor,omitempty"`
}

func (c *Client) Search(ctx context.Context, req *mcp.CallToolRequest, args SearchParams) (*mcp.CallToolResult, any, error) {
    if args.Query == "" {
        return nil, nil, fmt.Errorf("query is required")
    }
    limit := args.Limit
    if limit == 0 {
        limit = 20
    }
    // use c.apiKey, c.http, c.baseURL...
    _ = limit
    return &mcp.CallToolResult{
        Content: []mcp.Content{
            &mcp.TextContent{Text: "results here"},
        },
    }, nil, nil
}

type CreateParams struct {
    Name        string `json:"name"`
    Description string `json:"description,omitempty"`
}

func (c *Client) Create(ctx context.Context, req *mcp.CallToolRequest, args CreateParams) (*mcp.CallToolResult, any, error) {
    if args.Name == "" {
        return nil, nil, fmt.Errorf("name is required")
    }
    // use c.apiKey, c.http, c.baseURL...
    return &mcp.CallToolResult{
        Content: []mcp.Content{
            &mcp.TextContent{Text: fmt.Sprintf("Created item: %s", args.Name)},
        },
    }, nil, nil
}
```

This approach makes each tool handler a method on `*Client`, so it naturally captures the API key and HTTP client without global state. It also makes the code easy to test by substituting a test client.

---

## Pagination

Implement cursor-based or offset-based pagination for all list tools:

```go
type ListItemsParams struct {
    Limit  int    `json:"limit,omitempty"`  // default 20, max 100
    Cursor string `json:"cursor,omitempty"` // opaque pagination cursor
}

type ListResult struct {
    Items      []Item `json:"items"`
    Total      int    `json:"total"`
    HasMore    bool   `json:"has_more"`
    NextCursor string `json:"next_cursor,omitempty"`
}

func (c *Client) ListItems(ctx context.Context, req *mcp.CallToolRequest, args ListItemsParams) (*mcp.CallToolResult, any, error) {
    limit := args.Limit
    if limit == 0 {
        limit = 20
    }
    if limit > 100 {
        limit = 100
    }

    // ... call API with limit and cursor ...

    result := ListResult{
        Items:      items,
        Total:      total,
        HasMore:    len(items) == limit,
        NextCursor: nextCursor,
    }

    b, err := json.MarshalIndent(result, "", "  ")
    if err != nil {
        return nil, nil, fmt.Errorf("failed to serialize response: %w", err)
    }

    return &mcp.CallToolResult{
        Content: []mcp.Content{
            &mcp.TextContent{Text: string(b)},
        },
    }, nil, nil
}
```

---

## Response Formats (JSON and Markdown)

Support both JSON and Markdown output when tools return structured data. JSON is useful for programmatic processing; Markdown is easier for agents to read and present.

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

func buildTextResult(text string) *mcp.CallToolResult {
    return &mcp.CallToolResult{
        Content: []mcp.Content{
            &mcp.TextContent{Text: text},
        },
    }
}

func (c *Client) Search(ctx context.Context, req *mcp.CallToolRequest, args SearchParams) (*mcp.CallToolResult, any, error) {
    // ... fetch results ...
    results := []SearchResult{} // populated from API

    if args.ResponseFormat == FormatJSON {
        b, err := json.MarshalIndent(results, "", "  ")
        if err != nil {
            return nil, nil, fmt.Errorf("failed to serialize response: %w", err)
        }
        return buildTextResult(string(b)), nil, nil
    }

    // Default: Markdown
    var sb strings.Builder
    sb.WriteString(fmt.Sprintf("## Search Results for %q\n\n", args.Query))
    for _, r := range results {
        sb.WriteString(fmt.Sprintf("- **%s** — %s\n", r.Title, r.Summary))
    }
    if len(results) == 0 {
        sb.WriteString("No results found.")
    }
    return buildTextResult(sb.String()), nil, nil
}
```

---

## go.mod

```
module github.com/yourorg/myservice-mcp-server

go 1.23

require (
    github.com/modelcontextprotocol/go-sdk v0.2.0
)
```

Run `go mod tidy` after adding the dependency to populate `go.sum`.

---

## Complete Minimal Example

A fully working `main.go` with one real tool demonstrating all the patterns:

```go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/modelcontextprotocol/go-sdk/mcp"
)

// --- Client ---

type Client struct {
    apiKey  string
    baseURL string
    http    *http.Client
}

func NewClient(apiKey string) *Client {
    return &Client{
        apiKey:  apiKey,
        baseURL: "https://jsonplaceholder.typicode.com",
        http:    &http.Client{Timeout: 30 * time.Second},
    }
}

func (c *Client) RegisterTools(server *mcp.Server) {
    mcp.AddTool(server, &mcp.Tool{
        Name:        "get_post",
        Description: "Fetch a blog post by its numeric ID. Returns title and body text.",
        Annotations: &mcp.ToolAnnotations{
            ReadOnlyHint:   mcp.Ptr(true),
            IdempotentHint: mcp.Ptr(true),
        },
    }, c.GetPost)
}

// --- Tool ---

type GetPostParams struct {
    ID int `json:"id"`
}

type Post struct {
    ID    int    `json:"id"`
    Title string `json:"title"`
    Body  string `json:"body"`
}

func (c *Client) GetPost(ctx context.Context, req *mcp.CallToolRequest, args GetPostParams) (*mcp.CallToolResult, any, error) {
    if args.ID <= 0 {
        return nil, nil, fmt.Errorf("id must be a positive integer")
    }

    url := fmt.Sprintf("%s/posts/%d", c.baseURL, args.ID)
    httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return nil, nil, fmt.Errorf("failed to build request: %w", err)
    }

    resp, err := c.http.Do(httpReq)
    if err != nil {
        return nil, nil, fmt.Errorf("API request failed: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode == http.StatusNotFound {
        return nil, nil, fmt.Errorf("post with ID %d not found: valid IDs are 1-100", args.ID)
    }
    if resp.StatusCode != http.StatusOK {
        return nil, nil, fmt.Errorf("API error (HTTP %d)", resp.StatusCode)
    }

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, nil, fmt.Errorf("failed to read response: %w", err)
    }

    var post Post
    if err := json.Unmarshal(body, &post); err != nil {
        return nil, nil, fmt.Errorf("failed to parse response: %w", err)
    }

    text := fmt.Sprintf("# %s\n\n%s", post.Title, post.Body)
    return &mcp.CallToolResult{
        Content: []mcp.Content{
            &mcp.TextContent{Text: text},
        },
    }, nil, nil
}

// --- Main ---

func main() {
    log.SetOutput(os.Stderr)

    apiKey := os.Getenv("EXAMPLE_API_KEY")
    if apiKey == "" {
        // This API doesn't actually require a key, but we show the pattern.
        apiKey = "demo"
    }

    server := mcp.NewServer(&mcp.Implementation{
        Name:    "example-mcp-server",
        Version: "v1.0.0",
    }, nil)

    client := NewClient(apiKey)
    client.RegisterTools(server)

    ctx := context.Background()
    transport, err := mcp.NewStdioTransport()
    if err != nil {
        log.Fatal(err)
    }

    session, err := server.Connect(ctx, transport, nil)
    if err != nil {
        log.Fatal(err)
    }

    session.Wait()
}
```

Build and verify:

```bash
go build ./...
```

---

## Quality Checklist (Go-specific)

Before shipping, confirm every item:

- [ ] Server name follows `{service}-mcp-server` format
- [ ] All tool handlers have the correct three-return signature: `func(ctx, req, args) (*CallToolResult, any, error)`
- [ ] Params structs use `json` struct tags on every field
- [ ] Required fields are validated at the top of each handler with actionable error messages
- [ ] `log.SetOutput(os.Stderr)` called at the very start of `main()`
- [ ] No writes to `os.Stdout` anywhere (no `fmt.Println`, no default `log.Print` before redirect)
- [ ] `session.Wait()` called for stdio servers
- [ ] API keys loaded from environment variables and validated at startup with clear error messages
- [ ] Config and HTTP client passed via closures (client struct methods), not global variables
- [ ] `http.Client` has a `Timeout` set (30s recommended)
- [ ] Tool annotations set on every tool (`readOnlyHint`, `destructiveHint`, `idempotentHint`)
- [ ] Error messages tell the agent what to do next, not just what failed
- [ ] Pagination implemented for all list operations (`limit`, `cursor`/`offset`, `has_more`)
- [ ] Both JSON and Markdown `response_format` supported for data-returning tools
- [ ] `go build ./...` completes with zero errors
- [ ] `go vet ./...` completes with zero warnings
