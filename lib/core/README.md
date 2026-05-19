# `lib/core/`

Cross-cutting infrastructure that has no domain meaning on its own: environment flags, error types, logging, future extension points (timing, retry policies).

Anything in here MUST be safe to import from any other layer. If something belongs only to a feature, put it under that feature's folder instead.
