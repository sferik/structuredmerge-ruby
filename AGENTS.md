# Repository guidance

## TSLP specs on Ruby head

Tree-sitter Language Pack (TSLP) uses native gems with a released Ruby ABI. Ruby head is permanently unsupported by that policy. Every spec that would invoke a TSLP-backed grammar must skip on Ruby head with:

```ruby
skip_for(engine: "ruby", versions: "head", reason: "Ruby head is permanently unsupported by tree_sitter_language_pack's released-ABI-only native gem policy")
```

Apply this to every TSLP-backed grammar and backend across the entire StructuredMerge Ruby family, including specs that select TSLP indirectly through a provider's default backend.

The `kreuzberg-language-pack` backend is an alias for TSLP and follows this same rule.
