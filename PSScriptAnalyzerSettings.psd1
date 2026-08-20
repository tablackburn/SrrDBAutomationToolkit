@{
    # Scope analysis to actionable severities, dropping Information-level noise.
    #
    # ParseError must be listed. It is how PSScriptAnalyzer reports a file it
    # could not parse at all, and naming Severity without it silently hides
    # syntax-broken files: a file with a missing brace reports zero findings
    # under @('Error', 'Warning'). Microsoft's documentation states this
    # directly -- "To suppress ParseErrors, don't include it as a value in the
    # Severity parameter" -- which is exactly what must not happen to a lint gate.
    Severity = @('ParseError', 'Error', 'Warning')
}
