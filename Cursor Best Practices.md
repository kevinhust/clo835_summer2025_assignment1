# Cursor Best Practices

## 1. Planning and Collaboration

- **Before using Cursor**, let Claude create a clear and detailed plan in Markdown (let it ask clarifying questions, then critique its own plan, then regenerate). Add this to `Instructions.md` so you can reference it often in Cursor.

- **Let ChatGPT plan, Cursor code**:
  Tell ChatGPT what you want to create, let it provide instructions for another coding AI, then paste everything into Cursor Composer Agent.
  ChatGPT adds another layer of planning, reducing the chance of issues.

- **When you encounter problems**, let Cursor write a report listing all files and their functions, and describing the problem. Send it to Claude or ChatGPT for solutions.

## 2. Rules and Incremental Development

- **Use `.cursorrules`** (always in AI context) to define general rules.
  Reference: https://cursor.directory

- **Incremental development process**:
  1. Define a small incremental task.
  2. Write (or let AI write) a failing test case for this increment.
  3. Instruct AI (usually in agent mode) to write code to pass the test.
  4. If the test fails, AI analyzes the failure and tries to fix the code, looping back to step 3.
  5. Once the test passes, the developer reviews the changes.

- **Example**:
  Write tests first, then code, then run tests and update code until tests pass.
  Let the agent write code in small "edit-test" cycles.

## 3. Prompting and Context Management

- **Encourage chain-of-thought** in prompts.

- **Keep context short**:
  Use @ to explicitly add files to keep context short. The longer the context, the more detail AI provides.
  When context gets long, start a new chat.

- **Resync / index code frequently**.

- **Use `.cursorsignore`** to exclude irrelevant files.

- **Use / Reference** in the editor to quickly add files to context.

## 4. Tools and Resources

- **Use gitinsect.com** to aggregate all scripts, configs, and related files (filterable by extension) into one page.

- **https://context7.com/** for referencing the latest documentation.

- **Use git for version control frequently** to avoid too many uncommitted changes.

## 5. Notepad and Commands

- Notepad is a common prompt tool.

- **Example**: Enable Yolo mode so it writes tests
  Allow any test, such as vitest, npm test, nr test, etc. Also allow basic build commands like build, tsc, etc.
  Always allow creating files and directories, such as touch, mkdir, etc.

## 6. System Prompts and Expression

- Optional: Set system prompts in "AI Rules" in Cursor settings.

- Keep prompts concise and clear:
  - Use alternative vocabulary
  - Avoid unnecessary explanations
  - Prioritize technical details over generic advice
