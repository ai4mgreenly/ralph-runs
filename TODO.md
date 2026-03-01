# TODO

- **Smarter attachment delivery**: Instead of inlining attachment contents into the goal body, use document message types — chunk documents and give the LLM the ability to pull them in on demand. Since we can't offer custom tools, this would likely work through bash tool invocations (e.g., a script Ralph can call to fetch a specific attachment). Needs design thought.
