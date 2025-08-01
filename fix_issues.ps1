# PowerShell script to fix Flutter analyze issues

function Fix-ConstConstructors {
    param([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    
    # Fix const constructors
    $content = $content -replace '(\s+)Icon\(', '$1const Icon('
    $content = $content -replace '(\s+)Text\(', '$1const Text('
    $content = $content -replace '(\s+)SizedBox\(', '$1const SizedBox('
    $content = $content -replace '(\s+)EdgeInsets\.', '$1const EdgeInsets.'
    $content = $content -replace '(\s+)Padding\(', '$1const Padding('
    $content = $content -replace '(\s+)Center\(', '$1const Center('
    $content = $content -replace '(\s+)Spacer\(\s*\)', '$1const Spacer()'
    $content = $content -replace '(\s+)Divider\(\s*\)', '$1const Divider()'
    $content = $content -replace '(\s+)CircularProgressIndicator\(\s*\)', '$1const CircularProgressIndicator()'
    
    # Fix withOpacity to withValues
    $content = $content -replace '\.withOpacity\(([0-9.]+)\)', '.withValues(alpha: $1)'
    
    # Remove unnecessary const
    $content = $content -replace 'const const ', 'const '
    
    Set-Content $FilePath $content -Encoding UTF8
}

# Get all Dart files
$dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    Write-Host "Fixing $($file.FullName)..."
    Fix-ConstConstructors $file.FullName
}

Write-Host "Fixed $($dartFiles.Count) files"
