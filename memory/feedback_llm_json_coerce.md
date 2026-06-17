---
name: LLM JSON Coerce — Smart Quote / Em-dash Fix
description: LLMs emit curly quotes and em-dashes inside JSON strings, breaking json.loads. Always use the unicode-normalizer pattern before parsing.
type: feedback
originSessionId: 4e386939-ea33-4152-8408-d3930d2b200e
---
LLMs (Claude, GPT) regularly produce unicode characters inside tool-call / structured-output JSON strings that make `json.loads` fail with `JSONDecodeError`. The most common offenders: curly quotes (`'` `'` `"` `"`), em-dash (`—`), en-dash (`–`), ellipsis (`…`).

**Why:** Hit this in production during eval pipeline — `test_good_cohort_mean` failed with `Expecting ',' delimiter` at a position in the middle of an `issues` JSON string. The LLM had written `"it's"` (curly apostrophe) inside what was supposed to be a plain JSON string.

**How to apply:** Every Pydantic `field_validator` that coerces `str → list` or `str → dict` from LLM output must include the unicode-normalizer fallback:

```python
@field_validator("issues", "strengths", "tags", mode="before")
@classmethod
def _coerce_json_string(cls, v: Any) -> Any:
    if not isinstance(v, str):
        return v
    try:
        return json.loads(v)
    except json.JSONDecodeError:
        cleaned = (
            v
            .replace("‘", "'").replace("’", "'")   # curly single quotes
            .replace("“", '"').replace("”", '"')   # curly double quotes
            .replace("—", "-").replace("–", "-")   # em/en dashes
            .replace("…", "...")                         # ellipsis char
        )
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            return []   # last resort — never crash the pipeline
```

Apply this pattern to every Pydantic model that receives LLM-generated JSON strings, not just models that already failed. The bug is latent in every coerce validator.
