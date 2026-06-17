---
name: Learning Style — Visual Code Examples
description: User memorizes by reading code in VS Code. Always teach through complete, runnable code examples, not prose explanations.
type: feedback
originSessionId: 4e386939-ea33-4152-8408-d3930d2b200e
---
User memorizes through visual code patterns — they open examples in VS Code and study them until the pattern is internalized. They do NOT learn well from prose descriptions or pseudocode.

**Why:** They explicitly said "I tend to memorize with images of examples" and "I usually use Visual Studio Code to memorize code operations."

**How to apply:**
- Every concept explanation must include a complete, runnable code example
- Code blocks should be self-contained — no "assume X is defined elsewhere"
- Show the full pattern from import to usage in one block when possible
- Use inline annotation sparingly (one # comment per non-obvious line max)
- When comparing two approaches, show both as side-by-side code blocks, not prose
- For LLMOps/LangGraph topics: always show the actual class/function skeleton, not just the concept
- Prefer a single large, complete example over multiple small fragments
- When explaining architecture, back it with a full working code file, not a diagram description
