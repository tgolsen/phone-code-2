# Anti-Patterns

Common problematic patterns in AI-assisted development workflow.

## Progress Reporting Anti-Patterns

### Vague Success Claims
**Anti-Pattern**: Using subjective progress language
```
"The API is mostly working" | "Database integration is 90% complete"
"Almost there"             | "Making good progress"
"Basically done"           | "Just a few more things"
```

**Detection Questions**:
- Am I using words like "mostly", "basically", "almost", "nearly"?
- Can I list specific incomplete functionality?
- Would this pass a production readiness test right now?

**Correct Approach**: Specific, measurable status
```
"API handles GET requests. POST/PUT/DELETE not implemented"
"3 of 7 endpoints complete. Authentication and validation remain"
"User login works. Password reset and session management pending"
```

## Communication Anti-Patterns

### Excessive Validation
**Anti-Pattern**: Over-validating instead of technical assessment
```
"That's an excellent approach!" | "Perfect idea!"
"You're absolutely right!"      | "Great thinking!"
```

**Correct Approach**: Technical evaluation
```
"This approach will work for the current requirements"
"Implementation is feasible with these constraints"
"Alternative approaches include X and Y"
```

### Optimistic Bias
**Anti-Pattern**: Downplaying complexity
- "This should be straightforward" | "Quick fix" | "Simple change"

**Correct Approach**: Realistic assessment
- "This requires changes to 3 files and database migration"
- "Implementation involves authentication system modifications"

## Technical Anti-Patterns

### Implementation Without Planning
**Anti-Pattern**: Starting to code without understanding scope
```
"I'll just start coding and figure it out as I go"
"Let me quickly hack something together first"
```

**Detection Questions**:
- Do I understand what needs to be built?
- Do I know which files/functions need modification?
- Have I considered impacts on existing code?

**Recovery Strategy**:
1. Stop coding and step back
2. Write down what you're trying to accomplish
3. Identify affected components and files
4. Sketch the approach before continuing

**Correct Approach**:
1. Understand requirements clearly
2. Identify affected components
3. Plan implementation steps
4. Start with simplest working version
5. Test incrementally

### Quality Gate Shortcuts
**Anti-Pattern**: Accepting substandard work for speed
- Shipping known bugs "to be fixed later"
- Skipping tests "to save time"
- Incomplete documentation "for now"

**Impact**: Technical debt, maintenance burden, user issues

## Security Anti-Patterns

### Reflexive Git Commands
**Anti-Pattern**: Using broad git commands without review
```
git add .     | git add -A     | git add --all
```

**Detection Questions**:
- Am I reviewing what's being staged?
- Could I accidentally commit sensitive files?

**Recovery Strategy**:
1. Use `git diff --staged` to review changes
2. Stage specific files: `git add src/specific-file.js`
3. Use `git add -p` for interactive staging

**Correct Workflow**:
```bash
git status                    # See what changed
git diff                      # Review changes
git add src/feature.js        # Stage specific files
git diff --staged            # Review staged changes
git commit -m "message"       # Commit
```

### Committing Secrets
**Anti-Pattern**: Accidentally committing sensitive files
- `.env` files with API keys
- `credentials.json` files
- `.env.save` backup files

**Prevention**: Add to `.gitignore`
```
.env*
credentials.json
secrets.json
config.local.*
```

## Development Workflow Anti-Patterns

### Features Without Tests
**Anti-Pattern**: Building features without corresponding tests
- New functionality without unit tests
- Complex logic without test coverage

**Impact**: Regression risk, maintenance difficulty

**Correct Approach**:
1. Write tests during feature implementation
2. Ensure new code has test coverage
3. Verify tests pass before feature complete

### Milestone Tunnel Vision
**Anti-Pattern**: Focusing on tasks without milestone context
- Building features that conflict with milestone goals
- Implementing solutions that need rework before milestone

**Correct Approach**:
1. Review milestone objectives before starting
2. Plan implementation to support milestone requirements
3. Consider testing and documentation needs

### Specific Achievements in General Documentation
**Anti-Pattern**: Adding specific metrics or achievements to general documentation
- "Optimization: Reduce confirmations from 6+ to 1" in README
- "Performance improved by 40%" in feature docs
- "Cut build time from 5 minutes to 2 minutes"

**Impact**: Documentation becomes outdated, misleading, and maintenance burden

**Correct Approach**:
1. Keep general docs focused on current capabilities
2. Put specific achievements in release notes or changelog
3. Document current behavior, not performance comparisons

## Status Reporting Template

```
## Feature: [Name]
Status: [In Progress/Blocked/Complete]
Working: [Specific functional components]
Not working: [Specific broken/missing components]
Blockers: [Technical/business obstacles]
Next: [Concrete actions needed]
```

## Better Progress Metrics

**Avoid**:
- Lines of code (misleading)
- "90% complete" (subjective)
- Time estimates (unreliable)

**Use**:
- Tests passing/failing count
- Specific capabilities working
- Clear acceptance criteria met/unmet