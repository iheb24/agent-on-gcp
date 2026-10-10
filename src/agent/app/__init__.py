"""BigQuery Data Assistant Agent package."""

# ADK loaders (adk eval/conformance) import this package's __init__ and then
# look up the `agent` submodule attribute; without this import the lookup fails.
from . import agent as agent
