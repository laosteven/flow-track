# Versioning Strategy

This project uses **Semantic Versioning** (SemVer) with automated version management through GitHub Actions.

## Version Format

Versions follow the format: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR**: Breaking changes or significant new features
- **MINOR**: New features that are backwards compatible
- **PATCH**: Bug fixes and minor improvements
- **BUILD**: Automatically incremented build number

Example: `1.2.3+42`

## Automatic Versioning

Version bumps are triggered automatically based on commit messages:

### Commit Message Prefixes

- `major:` or `BREAKING CHANGE:` → Bumps MAJOR version (e.g., 1.0.0 → 2.0.0)
- `feat:` or `feature:` or `minor:` → Bumps MINOR version (e.g., 1.0.0 → 1.1.0)
- Any other commit → Bumps PATCH version (e.g., 1.0.0 → 1.0.1)

### Examples

```bash
# Patch version bump
git commit -m "fix: resolve bluetooth connection issue"
# Results in: 1.0.0 → 1.0.1

# Minor version bump
git commit -m "feat: add stroke asymmetry detection"
# Results in: 1.0.1 → 1.1.0

# Major version bump
git commit -m "BREAKING CHANGE: redesign session storage format"
# Results in: 1.1.0 → 2.0.0
```

## Manual Version Bump

You can also manually trigger a version bump:

1. Go to **Actions** tab in GitHub
2. Select **Version Management** workflow
3. Click **Run workflow**
4. Choose version bump type (major, minor, or patch)

## Build Releases

When a version tag is created, the **Build and Release** workflow automatically:

1. Builds Android APK and App Bundle
2. Builds iOS IPA (unsigned)
3. Builds Windows executable
4. Creates a GitHub Release with all artifacts

## Current Version

Current version is defined in `dragon_paddle_app/pubspec.yaml`:

```yaml
version: 1.0.0+1
```

## Workflow Files

- `.github/workflows/version.yml` - Automatic version management
- `.github/workflows/release.yml` - Build and release artifacts

## Best Practices

1. **Use meaningful commit messages** with proper prefixes
2. **Test locally** before pushing to main/master branch
3. **Review changelog** in generated releases
4. **Tag releases** follow the pattern `v1.2.3`
5. **Monitor Actions tab** for workflow status

## Troubleshooting

If versioning fails:

1. Check that you have write permissions to the repository
2. Ensure `pubspec.yaml` exists at `dragon_paddle_app/pubspec.yaml`
3. Verify branch name is `main` or `master`
4. Check Actions logs for detailed error messages
