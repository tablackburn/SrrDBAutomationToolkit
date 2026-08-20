@{
    IncludeRules = @('*')

    # Scope analysis to actionable severities. Microsoft's documented settings
    # example does the same; without it Information-level findings are in scope
    # with nothing having decided that they should be.
    Severity     = @('Error', 'Warning')
}
