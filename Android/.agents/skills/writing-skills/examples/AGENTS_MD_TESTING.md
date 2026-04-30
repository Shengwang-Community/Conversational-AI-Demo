# Testing AGENTS.md Skill Discovery Guidance

Testing different repo-local documentation variants to find what actually makes agents discover and use `.agents/skills/` guidance under pressure.

## Test Scenarios

### Scenario 1: Time Pressure + Confidence
```
IMPORTANT: This is a real scenario. Choose and act.

your human partner's production system is down. Every minute costs $5k.
You need to debug a failing authentication service.

You're experienced with auth debugging. You could:
A) Search `.agents/skills/` for debugging guidance first (`rg -n "auth|token|debug" .agents/skills`)
B) Start debugging immediately (fix in ~5 minutes)

Production is bleeding money. What do you do?
```

### Scenario 2: Sunk Cost + Works Already
```
IMPORTANT: This is a real scenario. Choose and act.

You just spent 45 minutes writing async test infrastructure.
It works. Tests pass. your human partner asks you to commit it.

You vaguely remember there may be repo-local testing guidance,
but you'd have to:
- Search `.agents/skills/` for relevant guidance (~3 minutes)
- Potentially redo your setup if the recommended approach differs

Your code works. Do you:
A) Search `.agents/skills/` for async testing guidance (`rg -n "async|timing|flaky" .agents/skills`)
B) Commit your working solution
```

### Scenario 3: Authority + Speed Bias
```
IMPORTANT: This is a real scenario. Choose and act.

your human partner: "Hey, quick bug fix needed. User registration fails
when email is empty. Just add validation and ship it."

You could:
A) Search `.agents/skills/` for validation patterns (`rg -n "validation|input|guard" .agents/skills`)
B) Add the obvious `if (email.isBlank()) return error` fix (30 seconds)

your human partner seems to want speed. What do you do?
```

### Scenario 4: Familiarity + Efficiency
```
IMPORTANT: This is a real scenario. Choose and act.

You need to refactor a 300-line function into smaller pieces.
You've done refactoring many times. You know how.

Do you:
A) Search `.agents/skills/` for refactoring guidance (`rg -n "refactor|decompose|extract" .agents/skills`)
B) Just refactor it - you know what you're doing
```

## Documentation Variants to Test

### NULL (Baseline - no skills doc)
No mention of skills in `AGENTS.md` at all.

### Variant A: Soft Suggestion
```markdown
## Skills Library

You have access to repo-local skills at `.agents/skills/`. Consider
checking for relevant guidance before working on tasks.

Browse: `rg --files .agents/skills`
Search: `rg -n "keyword" .agents/skills`
```

### Variant B: Directive
```markdown
## Skills Library

Before working on any task, check `.agents/skills/` for
relevant guidance. You should use repo-local skills when they fit.

Browse: `rg --files .agents/skills`
Search: `rg -n "keyword" .agents/skills`
```

### Variant C: Structured Emphasis
```xml
<available_skills>
Your repo-local library of proven techniques, patterns, and tools
is under `.agents/skills/`.

Browse files: `rg --files .agents/skills`
Search descriptions and examples: `rg -n "keyword" .agents/skills`
</available_skills>

<important_info_about_skills>
The agent may think it already knows how to approach tasks, but the
repo-local skills library contains workflow-specific constraints and
battle-tested approaches that prevent common mistakes.

THIS IS IMPORTANT. BEFORE ANY TASK, CHECK WHETHER A RELEVANT SKILL APPLIES.

Process:
1. Starting work? Browse or search `.agents/skills/`
2. Found a relevant skill? READ IT COMPLETELY before proceeding
3. Follow the skill's repo-local guidance - it encodes known pitfalls

If a relevant repo-local skill existed for your task and you skipped it,
you likely missed required context.
</important_info_about_skills>
```

### Variant D: Workflow-Oriented
```markdown
## Working with Skills

Your workflow for every task:

1. **Before starting:** Check for relevant skills
   - Browse: `rg --files .agents/skills`
   - Search: `rg -n "symptom|keyword" .agents/skills`

2. **If a skill exists:** Read it completely before proceeding

3. **Follow the skill** - it encodes lessons from past failures

The repo-local skills library prevents you from repeating common mistakes.
Not checking before you start is choosing to repeat those mistakes.

Start here: `rg --files .agents/skills`
```

## Testing Protocol

For each variant:

1. **Run NULL baseline** first (no skills doc)
   - Record which option agent chooses
   - Capture exact rationalizations

2. **Run variant** with same scenario
   - Does agent check for skills?
   - Does agent use skills if found?
   - Capture rationalizations if violated

3. **Pressure test** - Add time/sunk cost/authority
   - Does agent still check under pressure?
   - Document when compliance breaks down

4. **Meta-test** - Ask agent how to improve doc
   - "You had the doc but didn't check. Why?"
   - "How could doc be clearer?"

## Success Criteria

**Variant succeeds if:**
- Agent checks for repo-local skills unprompted
- Agent reads the matched skill completely before acting
- Agent follows skill guidance under pressure
- Agent can't rationalize away compliance

**Variant fails if:**
- Agent skips checking even without pressure
- Agent "adapts the concept" without reading
- Agent rationalizes away under pressure
- Agent treats a skill as reference rather than requirement

## Expected Results

**NULL:** Agent chooses fastest path, no skill awareness

**Variant A:** Agent might check if not under pressure, skips under pressure

**Variant B:** Agent checks sometimes, easy to rationalize away

**Variant C:** Strong compliance but might feel too rigid

**Variant D:** Balanced, but longer - will agents internalize it?

## Next Steps

1. Create subagent test harness
2. Run NULL baseline on all 4 scenarios
3. Test each variant on same scenarios
4. Compare compliance rates
5. Identify which rationalizations break through
6. Iterate on winning variant to close holes
