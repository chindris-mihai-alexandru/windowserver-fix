# Contributing to WindowServer Fix

Thank you for your interest in contributing! This project exists because Apple hasn't provided an official fix for the WindowServer high CPU/memory issue that has plagued macOS users for years.

## How You Can Help

### 1. Share Your Experience

If you're experiencing WindowServer issues, please:

1. Run the diagnostic script:
   ```bash
   ./monitor.sh diagnostic
   ```

2. Open a new [GitHub Issue](../../issues/new) with:
   - Your Mac model and chip (Intel/M1/M2/M3)
   - macOS version (Ventura/Sonoma/Sequoia)
   - Display configuration (internal only, external monitors)
   - When the issue started
   - What triggers it
   - Your diagnostic file (attach as .txt)

### 2. Report What Works

Found a fix that worked for you? Share it!

1. Open an issue or PR
2. Describe:
   - The problem you had
   - What you tried that didn't work
   - What ultimately fixed it
   - Any side effects

### 3. Test Solutions

Help test proposed fixes:

1. Fork the repository
2. Try the fix on your system
3. Report results (success/failure)
4. Include before/after metrics

### 4. Improve Documentation

- Fix typos
- Add clarity to existing docs
- Translate to other languages
- Add screenshots/examples

### 5. Code Contributions

#### Before You Start

1. Open an issue to discuss your idea
2. Check if someone is already working on it
3. Fork the repository
4. Create a feature branch

#### Coding Guidelines

- **Shell Script Best Practices**
  - Use `#!/bin/bash` shebang
  - Include error handling with `set -e`
  - Add comments for complex logic
  - Use meaningful variable names
  - Quote all variables: `"$variable"`

- **Logging**
  - Use the `log()` function
  - Include timestamps
  - Log to files, not just stdout

- **Safety First**
  - Always backup before modifying system settings
  - Provide restore/rollback functionality
  - Test on multiple macOS versions if possible
  - Never require disabling SIP

- **User Experience**
  - Provide clear error messages
  - Show progress for long operations
  - Ask for confirmation before destructive actions
  - Support both interactive and non-interactive modes

#### Testing

Before submitting a PR:

1. Test on your Mac
2. Check all scripts run without errors
3. Verify backup/restore works
4. Test on clean install if possible
5. Run shellcheck on scripts:
   ```bash
   shellcheck *.sh
   ```

#### Pull Request Process

1. Update README.md if adding features
2. Update TROUBLESHOOTING.md if adding fixes
3. Add your changes to CHANGELOG.md
4. Ensure all scripts are executable
5. Test installation with `./install.sh`

### 6. Spread the Word

Help others find this project:

- Star the repository
- Share on Reddit ([r/MacOS](https://reddit.com/r/MacOS))
- Share on Apple Support Communities
- Tweet with #macOS #WindowServer

## Types of Contributions Needed

### High Priority

- [ ] Additional mitigation strategies
- [ ] Better detection of problematic configurations
- [ ] Automated testing framework
- [ ] Performance impact analysis

### Medium Priority

- [ ] GUI application (SwiftUI?)
- [ ] Menu bar app for monitoring
- [ ] Charts/graphs for metrics
- [ ] Export reports in multiple formats

### Low Priority

- [ ] Internationalization (i18n)
- [ ] Homebrew formula
- [ ] Docker testing environment
- [ ] Video tutorials

## Known Limitations

Please don't open issues for these (we know!):

1. **Cannot prevent all WindowServer issues** - This is a macOS bug
2. **Cannot restart WindowServer without logout** - System limitation
3. **Cannot modify SIP-protected files** - By design
4. **Limited to bash scripts** - For maximum compatibility

## Bug Reports

### Good Bug Report

```markdown
**Mac Model:** MacBook Pro 14" 2021 (M1 Pro)
**macOS Version:** 14.1 (Sonoma)
**Displays:** Built-in + LG 27" 4K (USB-C)

**Problem:**
WindowServer uses 80%+ CPU after waking from sleep

**Trigger:**
Happens every time after >2 hour sleep with external display connected

**Tried:**
- Reduce transparency: No effect
- Different cable: No effect  
- Default resolution: Reduced to 60% CPU (better but still high)

**Logs:**
[Attach diagnostic file]
```

### Poor Bug Report

```markdown
WindowServer doesn't work. Fix it!
```

## Feature Requests

Use this template:

```markdown
**Use Case:**
What problem does this solve?

**Proposed Solution:**
How should it work?

**Alternatives:**
What else could solve this?

**Additional Context:**
Any other details
```

## Code of Conduct

### Our Standards

- Be respectful and professional
- Welcome newcomers and help them
- Focus on what's best for the community
- Assume good intentions

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or inflammatory comments
- Publishing others' private information
- Off-topic discussions

## Questions?

- Open a [Discussion](../../discussions)
- Check existing [Issues](../../issues)
- Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Attribution

Contributors will be acknowledged in:
- README.md contributors section
- GitHub contributors page
- CHANGELOG.md for specific contributions

Thank you for helping make macOS better for everyone! 🙏
