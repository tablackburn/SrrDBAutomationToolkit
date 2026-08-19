# CI/CD Integration with PowerShellBuild

## GitHub Actions

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test
        shell: pwsh
        run: ./build.ps1 -Task Test -Bootstrap

  publish:
    needs: test
    runs-on: windows-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Publish
        shell: pwsh
        run: ./build.ps1 -Task Publish -Bootstrap
        env:
          PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
```

### Key Points

- Always use `./build.ps1` as the entry point, not `Invoke-psake` directly — `build.ps1` handles bootstrapping dependencies and setting up the build environment.
- Use `-Bootstrap` on the first run (or always in CI) to install dependencies from `requirements.psd1`.
- Pass secrets as environment variables, not as parameters.
- Publish job should depend on the test job (`needs: test`) and only run on main branch.
