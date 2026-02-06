<#
.SYNOPSIS
    Builds a single Lua file from previously split files.

.DESCRIPTION
    This script reads the '_compiler_registry.txt' file from the specified directory to determine
    the order of files. It then concatenates the content of these individual Lua files
    (which are expected to already contain their respective start and end delimiters,
    and '_header.lua' if it exists) into a single, combined Lua file. The output file
    will be named based on the original input file (e.g., 'WorldEvents.lua').

.PARAMETER InputFilePath
    This is used to derive the name of the compiled output file.
    If only a filename is provided, the script will look for it in the current directory.
    If not provided, the script will prompt the user to enter the filename.

.PARAMETER OutputDirectory
    The directory where the individual Lua files are read from.
    This directory should contain the split Lua files and the registry. Defaults to "includes".

.EXAMPLE
    # Build a combined file from previously split files
    # Assumes the split files are in 'includes'.
    # The output will be 'WorldEvents.lua' in the script's directory.
    .\build.ps1 -InputFilePath "WorldEvents.lua"

    # Build without specifying input (will prompt)
    .\build.ps1

    # Build with a custom input directory
    .\build.ps1 -InputFilePath "WorldEvents.lua" -OutputDirectory "ExtractedLua"

.NOTES
    - The script requires a '_compiler_registry.txt' file in the OutputDirectory
    - The registry file should list the files in the order they should be combined
    - If '_header.lua' exists, it will be added first regardless of its position in the registry
#>

param(
    [string]$InputFilePath = "",
    [string]$OutputDirectory = "includes"
)

# --- Configuration ---
$registryFileName = "_compiler_registry.txt"
$headerFileName = "_header.lua"

# --- Input Validation ---
# Determine the directory where the script is running
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

# If InputFilePath is not provided as a parameter, prompt the user for the filename
if ([string]::IsNullOrEmpty($InputFilePath)) {
    $promptMessage = "Please enter the original name of the large Lua file that was split (e.g., WorldEvents.lua). This is used for naming the compiled file."
    $fileNameOnly = Read-Host $promptMessage
    
    # If no name was entered, default to WorldEvents.lua
    if ([string]::IsNullOrEmpty($fileNameOnly)) {
        $fileNameOnly = "WorldEvents.lua"
        Write-Host "No filename specified, defaulting to: $fileNameOnly"
    }
    
    # Construct the full path using the script's directory and the provided filename
    $InputFilePath = Join-Path $ScriptDirectory $fileNameOnly
}
# If InputFilePath was provided, but it's just a filename (no directory separators),
# assume it's in the current script's directory.
elseif (-not (Test-Path $InputFilePath -PathType Leaf) -and -not $InputFilePath.Contains('\') -and -not $InputFilePath.Contains('/')) {
    $InputFilePath = Join-Path $ScriptDirectory $InputFilePath
}

# --- Setup Output Directory ---
try {
    # Ensure the output directory (where split files reside) exists
    if (-not (Test-Path $OutputDirectory -PathType Container)) {
        Write-Error "Error: The specified OutputDirectory '$OutputDirectory' does not exist. It should contain the split Lua files and the registry."
        exit 1
    }
} catch {
    Write-Error "Error setting up output directory '$OutputDirectory': $($_.Exception.Message)"
    exit 1
}

# --- Helper function to save content ---
function Save-LuaFileContent {
    param(
        [string]$FileName,
        [System.Collections.ArrayList]$Content,
        [string]$BaseOutputDirectory
    )
    # Construct the full output path for the file
    $fullOutputPath = Join-Path $BaseOutputDirectory $FileName

    # Get the directory part of the full output path
    $fileDirectory = Split-Path -Parent $fullOutputPath

    # Create the directory if it doesn't exist (including nested directories)
    try {
        if (-not (Test-Path $fileDirectory -PathType Container)) {
            Write-Host "  Creating subdirectory: '$fileDirectory'"
            New-Item -ItemType Directory -Path $fileDirectory -Force | Out-Null
        }
    } catch {
        Write-Error "Error creating subdirectory '$fileDirectory': $($_.Exception.Message)"
        throw # Re-throw the exception to stop script execution if directory creation fails
    }

    # Write the content to the file
    Write-Host "  Saving content to: '$fullOutputPath'"
    [System.IO.File]::WriteAllLines($fullOutputPath, $Content)
}

# --- Main Building Logic ---
Write-Host "Starting to build combined Lua file..."

$registryFilePath = Join-Path $OutputDirectory $registryFileName
if (-not (Test-Path $registryFilePath -PathType Leaf)) {
    Write-Error "Error: Registry file '$registryFilePath' not found. Cannot build combined file."
    exit 1
}

# Determine the name for the compiled file
$originalFileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($InputFilePath)
$rebuiltFileName = "${originalFileNameWithoutExtension}.lua"
$rebuiltFilePath = Join-Path $ScriptDirectory $rebuiltFileName

$combinedContent = [System.Collections.ArrayList]::new()

Write-Host "Reading file order from: '$registryFilePath'"
$fileNamesToBuild = Get-Content $registryFilePath

# Check for and prepend header if it exists in the registry and is the first entry
if ($fileNamesToBuild.Count -gt 0 -and $fileNamesToBuild[0] -eq $headerFileName) {
    $headerFilePath = Join-Path $OutputDirectory $headerFileName
    if (Test-Path $headerFilePath -PathType Leaf) {
        Write-Host "  Adding header file '$headerFileName' to combined file."
        Get-Content $headerFilePath | ForEach-Object { $combinedContent.Add($_) | Out-Null }
    } else {
        Write-Warning "  Warning: Header file '$headerFilePath' listed in registry but not found. Skipping."
    }
    # Remove header from the list to process remaining files
    $fileNamesToBuild = $fileNamesToBuild | Select-Object -Skip 1
}

foreach ($fileName in $fileNamesToBuild) {
    $individualFilePath = Join-Path $OutputDirectory $fileName
    if (Test-Path $individualFilePath -PathType Leaf) {
        Write-Host "  Adding '$fileName' to combined file."
        # Read content and add to buffer. The split files already contain delimiters.
        Get-Content $individualFilePath | ForEach-Object { $combinedContent.Add($_) | Out-Null }
    } else {
        Write-Warning "  Warning: Individual file '$individualFilePath' not found as listed in registry. Skipping."
    }
}

try {
    Write-Host "Writing combined file to: '$rebuiltFilePath'"
    [System.IO.File]::WriteAllLines($rebuiltFilePath, $combinedContent)
    Write-Host "Build finished successfully. Combined file is: '$rebuiltFilePath'."
} catch {
    Write-Error "An error occurred while writing the combined file: $($_.Exception.Message)"
    exit 1
}