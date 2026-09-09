# frozen_string_literal: true

# TrakFlow's architecture: a layered gem with pure domain models at the
# bottom, storage and graph services in the middle, and two independent
# interface layers (Thor CLI and MCP server) on top.
#
#   support (id_generator, time_parser)   <- leaf utilities
#   config                                <- leaf, used by everything
#   models                                <- pure domain objects
#   storage                               <- Sequel/JSONL persistence
#   graph                                 <- analysis over an injected db
#   cli | mcp                             <- interfaces, unaware of each other

source "lib/**/*.rb"

component :support, in: %w[lib/trak_flow/id_generator.rb lib/trak_flow/time_parser.rb]
component :config,  in: %w[lib/trak_flow/config.rb lib/trak_flow/config/**/*.rb]
component :models,  in: "lib/trak_flow/models/**/*.rb"
component :storage, in: "lib/trak_flow/storage/**/*.rb"
component :graph,   in: "lib/trak_flow/graph/**/*.rb"
component :cli,     in: %w[lib/trak_flow/cli.rb lib/trak_flow/cli/**/*.rb]
component :mcp,     in: %w[lib/trak_flow/mcp.rb lib/trak_flow/mcp/**/*.rb]

# Leaf utilities depend on nothing above them.
support.cannot_use :config, :models, :storage, :graph, :cli, :mcp
config.cannot_use :support, :models, :storage, :graph, :cli, :mcp

# Models are pure domain objects: attributes, validation, lifecycle. They
# must never reach into persistence or the interface layers.
models.cannot_use :storage, :graph, :cli, :mcp

# Storage maps rows to models. It must not know about the analysis layer
# or the interfaces built on top of it.
storage.cannot_use :graph, :cli, :mcp

# Graph analyses task data through the db handle it is given — it may read
# model constants, but must not construct storage or serve an interface.
graph.cannot_use :storage, :cli, :mcp

# CLI and MCP are peer interfaces over the same core. Neither may depend
# on the other, so either can be extracted or dropped independently.
cli.cannot_use :mcp
mcp.cannot_use :cli

no_cycles among: %i[support config models storage graph cli mcp]
