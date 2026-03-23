---
name: mcp-builder-golang
description: Guide for creating high-quality MCP (Model Context Protocol) servers in Go using the official Go SDK (github.com/modelcontextprotocol/go-sdk). Use this skill when building MCP servers in Go, implementing golang MCP integrations, creating go mcp server projects, or whenever someone asks about "go mcp", "golang mcp", "mcp server in go", "go sdk mcp", or wants to build a Go-based tool server for an LLM. Prefer this skill over the generic mcp-builder skill when the user has specified Go as their language.
---

# MCP Server Development Guide (Go)

## Overview

Create MCP (Model Context Protocol) servers in Go using the official SDK at `github.com/modelcontextprotocol/go-sdk`. Go MCP servers use typed handler functions and struct tags for parameter schemas — there is no Zod or Pydantic equivalent. The SDK infers the JSON schema from your Go structs automatically.

The quality of an MCP server is measured by how well it enables LLMs to accomplish real-world tasks.

---

# Process

## High-Level Workflow

Creating a high-quality Go MCP server involves four main phases:

### Phase 1: Research and Planning

#### 1.1 Understand Modern MCP Design

**API Coverage vs. Workflow Tools:**
Balance comprehensive API endpoint coverage with specialized workflow tools. Workflow tools can be more convenient for specific tasks, while comprehensive coverage gives agents flexibility to compose operations. When uncertain, prioritize comprehensive API coverage.

**Tool Naming and Discoverability:**
Clear, descriptive tool names help agents find the right tools quickly. Use consistent prefixes (e.g., `github_create_issue`, `github_list_repos`) and action-oriented naming.

**Context Management:**
Agents benefit from concise tool descriptions and the ability to filter/paginate results. Design tools that return focused, relevant data.

**Actionable Error Messages:**
Error messages should guide agents toward solutions with specific suggestions and next steps.

#### 1.2 Study MCP Protocol Documentation

Start with the sitemap to find relevant pages: `https://modelcontextprotocol.io/sitemap.xml`

Then fetch specific pages with `.md` suffix for markdown format.

Key pages to review:
- Specification overview and architecture
- Transport mechanisms (streamable HTTP, stdio)
- Tool, resource, and prompt definitions

#### 1.3 Load the Go SDK Documentation

Fetch the official Go SDK README before writing any code:

```
https://raw.githubusercontent.com/modelcontextprotocol/go-sdk/main/README.md
```

Then load the Go implementation guide:
- [Go Implementation Guide](./reference/go_mcp_server.md) — patterns, complete examples, quality checklist
- [MCP Best Practices](./reference/mcp_best_practices.md) — universal MCP guidelines

#### 1.4 Plan Your Implementation

**Understand the API:**
Review the service's API documentation to identify key endpoints, authentication requirements, and data models.

**Tool Selection:**
Prioritize comprehensive API coverage. List endpoints to implement, starting with the most common operations.

---

### Phase 2: Implementation

#### 2.1 Set Up Project Structure

See the [Go Implementation Guide](./reference/go_mcp_server.md) for the standard project layout, `go.mod` contents, and how to organize tools into packages.

Standard layout:
```
{service}-mcp-server/
├── main.go
├── tools/
│   ├── search.go
│   └── create.go
├── client/
│   └── client.go
├── go.mod
└── go.sum
```

#### 2.2 Implement Core Infrastructure

Create shared utilities:
- HTTP client with authentication (`client/client.go`)
- Error handling conventions
- Response formatting helpers (JSON/Markdown)
- Pagination support for list operations

#### 2.3 Implement Tools

For each tool:

**Params Struct:**
- Define a Go struct with `json` tags for each parameter
- The SDK infers the JSON schema from the struct automatically
- Use `omitempty` for optional fields

**Handler Signature:**
```go
func MyTool(ctx context.Context, req *mcp.CallToolRequest, args MyParams) (*mcp.CallToolResult, any, error)
```

**Return value:** The first return is the MCP result, the second is structured content (can be `nil`), the third is an error. Return errors directly — the SDK converts them to MCP error responses.

**Annotations:**
Set `readOnlyHint`, `destructiveHint`, `idempotentHint`, and `openWorldHint` on every tool.

---

### Phase 3: Review and Test

#### 3.1 Code Quality

Review for:
- No duplicated code (DRY principle)
- Consistent error handling
- All tool handlers have the correct three-return signature
- Clear tool descriptions
- No global mutable state — pass config via closures

#### 3.2 Build and Test

```bash
# Verify compilation
go build ./...

# Test with MCP Inspector
npx @modelcontextprotocol/inspector
```

For stdio servers, test by piping JSON-RPC messages directly. See the [Go Implementation Guide](./reference/go_mcp_server.md) for detailed testing approaches and the quality checklist.

---

### Phase 4: Create Evaluations

After implementing your MCP server, create comprehensive evaluations to test its effectiveness.

#### 4.1 Create 10 Evaluation Questions

Follow this process:
1. **Tool Inspection**: List available tools and understand their capabilities
2. **Content Exploration**: Use READ-ONLY operations to explore available data
3. **Question Generation**: Create 10 complex, realistic questions
4. **Answer Verification**: Solve each question yourself to verify answers

Each question must be:
- **Independent**: Not dependent on other questions
- **Read-only**: Only non-destructive operations required
- **Complex**: Requiring multiple tool calls and deep exploration
- **Realistic**: Based on real use cases humans would care about
- **Verifiable**: Single, clear answer verifiable by string comparison
- **Stable**: Answer won't change over time

#### 4.2 Output Format

```xml
<evaluation>
  <qa_pair>
    <question>Your question here</question>
    <answer>The exact answer</answer>
  </qa_pair>
</evaluation>
```

---

# Reference Files

Load these as needed:

- [Go Implementation Guide](./reference/go_mcp_server.md) — Quick reference, project structure, complete code examples, transport setup, quality checklist
- [MCP Best Practices](./reference/mcp_best_practices.md) — Server/tool naming, response formats, pagination, security, annotations

---

# Common Pitfalls

**stdio transport — never write to stdout**
The MCP protocol communicates over stdout. Any `fmt.Println`, `log.Print` (default logger), or direct `os.Stdout` writes will corrupt the protocol stream. Always call `log.SetOutput(os.Stderr)` at the start of `main()`.

**Forgetting `session.Wait()`**
For stdio servers, `server.Connect()` starts the session but `main()` must not return immediately. Call `session.Wait()` to block until the client disconnects.

**Wrong handler signature**
The SDK uses generics to match handler functions. The signature must be exactly:
```go
func(ctx context.Context, req *mcp.CallToolRequest, args YourStruct) (*mcp.CallToolResult, any, error)
```
A mismatch causes a compile error or a panic at registration time.

**Not validating required fields**
The SDK does not enforce required fields from struct tags at the protocol level. Check required parameters explicitly at the top of each handler and return a descriptive error.

**Global state for API clients**
Avoid package-level variables for clients that hold credentials. Use closures or methods on a struct so each server instance is independent and testable.

**Missing timeouts on http.Client**
The default `http.Client` has no timeout. Always set `Timeout: 30 * time.Second` (or appropriate for the API).

**Not setting `mcp.Ptr()` for annotations**
Annotation fields are `*bool`. Use the SDK helper `mcp.Ptr(true)` — do not take the address of a literal directly inside a struct literal.
