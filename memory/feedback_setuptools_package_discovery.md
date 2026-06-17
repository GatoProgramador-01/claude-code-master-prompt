---
name: setuptools Flat-Layout Multi-Package Discovery Error
description: Adding evals/, scripts/, or tools/ next to app/ breaks setuptools auto-discovery. Always pin include=["app*"] in pyproject.toml.
type: feedback
originSessionId: 4e386939-ea33-4152-8408-d3930d2b200e
---
setuptools flat-layout auto-discovery fails with `Multiple top-level packages discovered` when any non-distributable directory (evals/, scripts/, tools/, tests/) sits as a sibling of the main package directory.

**Why:** Hit this when adding `evals/` next to `app/` in a FastAPI project. CI pip install failed immediately. The error message is clear but the fix is non-obvious if you don't know where to look.

**How to apply:** Any `pyproject.toml` that uses a flat layout (app/ at repo root level, no src/ wrapper) MUST include:

```toml
[tool.setuptools.packages.find]
include = ["app*"]   # only distribute app/; evals/, scripts/, tools/ are not packages
```

Add this the moment you create any sibling directory next to the main package — don't wait for CI to catch it. If using a different package name, substitute accordingly: `include = ["mypackage*"]`.

This pattern applies to any project structure where non-package dirs live at the same level as the installable package.
