# `lib/app/`

App-wide composition: the root widget, the router, the theme builders, and any state that has to be visible everywhere (theme mode, environment).

This layer wires the rest of the codebase together but should not contain feature logic. Feature code lives under [`lib/features/`](../features/), shared infrastructure under [`lib/core/`](../core/), data sources under [`lib/data/`](../data/), and entities/use-cases under [`lib/domain/`](../domain/).
