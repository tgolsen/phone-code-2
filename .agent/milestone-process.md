# General Application Milestone Lock-in Process

## Overview
This document defines the standardized process for "locking in" a milestone for general applications - ensuring code quality, documentation, and proper version control before moving to the next development phase.

**Suitable for:** CLI tools, desktop applications, mobile apps, libraries, frameworks, and any non-web projects.

## Checklist

### Phase 0: Core Validation
**ALWAYS RUN FIRST** - Validates system integrity before milestone lock-in

- [ ] **Run core functionality tests**: Execute project-specific test suite (unit tests, integration tests)
- [ ] **Verify all critical functionality**: Core features work as expected
- [ ] **Dependency verification**: Check all dependencies install and function correctly
- [ ] **Platform compatibility check**: Test on target operating systems/environments
- [ ] **Update test suite if needed**: Add tests for new features or components
- [ ] **Fix any regressions**: Address failing tests before proceeding

**CRITICAL**: Do not proceed with milestone lock-in if core functionality tests fail.

### Pre-Milestone Development Guidelines
**Apply these principles during feature development to ensure milestone readiness**

#### Test-Driven Feature Development
- [ ] **Create test with every new feature**: No feature is complete without corresponding test coverage
- [ ] **Test before commit**: Ensure feature tests pass before checking in code
- [ ] **Update test documentation**: Document test coverage for new features
- [ ] **Validate feature completeness**: Use tests to verify feature meets requirements

#### Milestone-Aware Development
- [ ] **Review milestone objectives**: Before starting any feature, understand current milestone goals
- [ ] **Plan for milestone integration**: Consider how new features support milestone completion
- [ ] **Anticipate milestone requirements**: Plan implementation to meet quality gates and documentation needs
- [ ] **Avoid milestone conflicts**: Don't implement features that will require significant rework before milestone

**Principle**: Every commit should move the project closer to milestone completion, not create obstacles for it.

### Phase 1: Code Cleanup
- [ ] Run linting and fix code style issues
- [ ] Remove prototype/example code not in production use
- [ ] Remove debug logging and console.log statements
- [ ] Clean up commented-out code
- [ ] Consolidate duplicate code/functions
- [ ] Remove unused imports and dependencies
- [ ] Verify no hardcoded secrets or credentials

### Phase 1.5: Data Protection Strategy
**CRITICAL**: Always secure data before proceeding with milestone activities

- [ ] **Review data sources**: Identify all data stores used by the project (local files, databases, external APIs)
- [ ] **Assess backup requirements**: Consider data size, criticality, and storage constraints
- [ ] **Local data backup**: Create milestone backup of critical local data/configuration
- [ ] **Remote data verification**: Confirm existing backup strategy is current and functional
- [ ] **External service review**: Document any third-party services and their data policies
- [ ] **Update backup documentation**: Record any changes to backup procedures since last milestone
- [ ] **Test backup integrity**: Verify at least one backup can be restored successfully

**Backup Strategy Guidelines:**
- **Configuration files**: Backup to `backups/milestone-vX.X.X/config/`
- **Local data files**: Full backup for critical data, document restore procedure
- **User data**: Export/backup user-generated content and settings
- **External services**: Confirm backup SLA, export critical configurations if possible

### Phase 2: Documentation Update
- [ ] Update main README.md with current feature set
- [ ] Update command documentation (CLI commands, options, examples)
- [ ] Update configuration documentation (settings, environment variables)
- [ ] Document any new dependencies or requirements
- [ ] Update example configurations with new options
- [ ] Document breaking changes since last milestone
- [ ] Update installation/setup instructions

### Phase 3: Additional Testing (Progressive)
**Note**: Core testing is now handled in Phase 0 with the comprehensive test suite

- [ ] **Manual workflow testing**: Test critical user workflows end-to-end
- [ ] **Cross-platform testing**: Verify functionality works on target operating systems
- [ ] **Performance validation**: Check execution times and resource usage
- [ ] **Security verification**: Test credential handling and data protection
- [ ] **Installation simulation**: Test installation process on clean system
- [ ] **Rollback verification**: Ensure rollback procedures work if needed

### Phase 4: Quality Assurance
- [ ] Check for security vulnerabilities (hardcoded secrets, unsafe file operations, etc.)
- [ ] Verify input validation and sanitization
- [ ] Check error handling in critical paths
- [ ] Test with invalid/malicious inputs and edge cases
- [ ] Verify proper permission handling for files and directories
- [ ] Performance check (command execution times, memory usage)

### Phase 5: Version Control
- [ ] Stage specific files (`git add filename` for each file, never use `git add .`)
- [ ] Review staged changes (`git diff --staged`)
- [ ] Create descriptive commit message following format:
  ```
  Milestone [X]: [Brief Description]

  ## New Features
  - Feature 1
  - Feature 2

  ## Improvements
  - Improvement 1
  - Improvement 2

  ## Technical Changes
  - Technical change 1
  - Technical change 2

  ## Documentation
  - Updated README
  - Added command documentation

  ## Testing
  - Added unit tests for X
  - Manual testing completed

  ## Data Safety
  - Data backups completed and verified
  - Backup strategy reviewed and updated
  ```
- [ ] Commit changes
- [ ] Create and push milestone tag: `git tag -a v0.[X].0 -m "Milestone [X]: [Description]"`
- [ ] Push to remote: `git push origin main --tags`

### Phase 6: Milestone Summary
- [ ] Update project status in main README
- [ ] Document lessons learned
- [ ] Note any technical debt created
- [ ] Plan next milestone priorities
- [ ] Update project roadmap/timeline

## Testing Strategy by Milestone

### **Early Milestones (1-3): Manual Testing**
- Create manual testing checklist
- Test critical user flows manually
- Document test cases for future automation

### **Mid Milestones (4-6): Unit Testing**
- Add unit tests for new services/functions
- Aim for >70% coverage on new code
- Use appropriate testing framework for your language

### **Later Milestones (7+): Full Test Suite**
- Integration tests for core functionality
- E2E tests for user workflows
- Performance testing for production readiness

## Commands Reference

### Node.js/TypeScript Applications
```bash
# Run unit tests
npm test

# Run tests with coverage
npm run test:coverage

# Run type checking
npx tsc --noEmit

# CLI testing
npm install -g .

# TypeScript linting
npm run lint

# Security check
npm audit
```

### Python Applications
```bash
# Run tests
python -m pytest

# Run with coverage
python -m pytest --cov=src

# Linting
flake8 src/
black src/

# Security check
pip-audit

# Type checking
mypy src/

# Install for testing
pip install -e .
```

### Rust Applications
```bash
# Run tests
cargo test

# Run with coverage
cargo tarpaulin --out Html

# Linting
cargo clippy

# Format code
cargo fmt

# Security audit
cargo audit

# Build release
cargo build --release
```

### Go Applications
```bash
# Run tests
go test ./...

# Run with coverage
go test -cover ./...

# Linting
golangci-lint run

# Format code
go fmt ./...

# Security check
gosec ./...

# Build
go build
```

### Data/Configuration Backup
```bash
# Create backup directory structure
mkdir -p backups/milestone-v0.X.X/{config,data,logs}

# Backup configuration files
cp .env backups/milestone-v0.X.X/config/
cp package.json backups/milestone-v0.X.X/config/

# Backup user data (if applicable)
cp -r ~/.app-name/ backups/milestone-v0.X.X/data/

# Create backup manifest
echo "Backup created: $(date)" > backups/milestone-v0.X.X/backup_info.txt
echo "Version: $(git describe --tags)" >> backups/milestone-v0.X.X/backup_info.txt
```

### Remote Data Backup Verification
```bash
# Git repository backup (if using git for data)
git bundle create backups/milestone-v0.X.X/repo-backup.bundle --all

# Cloud storage sync (example)
rsync -av data/ user@remote:/backup/milestone-v0.X.X/data/

# Verify cloud backups (generic examples)
# - Check cloud storage dashboard
# - Verify automated backup jobs completed
# - Test restore procedure on non-production data
```

## Milestone Naming Convention
*Example for CLI tools - adapt to your project needs:*
- **v0.1.0** - Basic CLI structure and core commands
- **v0.2.0** - Enhanced functionality and user experience
- **v0.3.0** - Advanced features and integrations
- **v0.4.0** - Optimization and performance improvements
- **v0.5.0** - Production readiness and distribution

## Notes
- Each milestone should represent a cohesive set of features
- Milestones should be deployable and demonstrable
- Focus on stability over speed
- Document any shortcuts taken for future cleanup
- Adapt commands to your specific technology stack
- Remove sections that don't apply to your project type