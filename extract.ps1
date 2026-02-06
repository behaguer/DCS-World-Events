<#
.SYNOPSIS
    Splits a large Lua file into smaller individual Lua files based on specific delimiters.

.DESCRIPTION
    This script reads a single large Lua file and splits it into smaller files based on delimiters.
    Any content before the first file delimiter (e.g., a header comment block) will be saved as '_header.lua'.
    Subsequent smaller Lua files are identified by start and end delimiters.
    
    Start delimiter: "-----------------[[ Filename.lua ]]-----------------"
    End delimiter: "-----------------[[ END OF Filename.lua ]]-----------------"
    
    For each identified block, the script extracts the content (including delimiters)
    and saves it to a new .lua file with the corresponding filename in the output directory.
    It also creates a '_compiler_registry.txt' file listing the order of extracted files.

.PARAMETER InputFilePath
    The full path to the large Lua file that needs to be split.
    If only a filename is provided, the script will look for it in the current directory.
    If not provided, the script will prompt the user to enter the filename.

.PARAMETER OutputDirectory
    The name of the directory where the split Lua files and the registry file will be saved.
    This directory will be created if it does not exist. Defaults to "includes".

.EXAMPLE
    # Extract a file with a specific input file (full path)
    .\extract.ps1 -InputFilePath "C:\MyProject\WorldEvents.lua"

    # Extract a file with a filename (assumes file is in the current directory)
    .\extract.ps1 -InputFilePath "WorldEvents.lua"

    # Extract a file without parameters (will prompt for filename)
    .\extract.ps1

    # Extract a file with a custom output directory
    .\extract.ps1 -InputFilePath "WorldEvents.lua" -OutputDirectory "ExtractedLua"

.NOTES
    - The script expects the delimiters to be exactly as shown:
      "-----------------[[ Filename.lua ]]-----------------"
      "-----------------[[ END OF Filename.lua ]]-----------------"
    - If a start tag is found without a corresponding end tag before another start tag
      or the end of the file, the content will still be saved under the last identified filename.
    - Mismatched end tags will be warned about but will not stop processing.
#>

param(
    [string]$InputFilePath = "",
    [string]$OutputDirectory = "includes"
)

# --- Configuration ---
$registryFileName = "_compiler_registry.txt"
$headerFileName = "_header.lua"
# Regex pattern to match the start delimiter and capture the filename
$startDelimiterPattern = "^-----------------\[\[\s*(?<filename>(?:(?!END OF).)*?\.lua)\s*\]\]-----------------$"
# Regex pattern to match the end delimiter and capture the filename
$endDelimiterPattern = "^-----------------\[\[\s*END OF\s*(?<filename>.*?\.lua)\s*\]\]-----------------$"

# --- Input Validation ---
# Determine the directory where the script is running
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

# If InputFilePath is not provided as a parameter, prompt the user for the filename
if ([string]::IsNullOrEmpty($InputFilePath)) {
    $promptMessage = "Please enter the name of the large Lua file to extract (e.g., WorldEvents.lua). It will be looked for in the current directory."
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

# Check if the specified input file exists
if (-not (Test-Path $InputFilePath -PathType Leaf)) {
    Write-Error "Error: The specified input file '$InputFilePath' does not exist or is not a file."
    exit 1
}

# --- Setup Output Directory ---
try {
    # Create the output directory if it doesn't exist
    if (-not (Test-Path $OutputDirectory -PathType Container)) {
        Write-Host "Creating output directory: $OutputDirectory"
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
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
        throw
    }

    # Write the content to the file
    Write-Host "  Saving content to: '$fullOutputPath'"
    [System.IO.File]::WriteAllLines($fullOutputPath, $Content)
}

# --- Main Extraction Logic ---
Write-Host "Starting to extract '$InputFilePath'..."

# --- Initialization ---
$isCapturing = $false
$currentFileName = ""
$contentBuffer = [System.Collections.ArrayList]::new()
$fileOrder = [System.Collections.ArrayList]::new()
$headerBuffer = [System.Collections.ArrayList]::new()
$isHeaderCapturing = $true

try {
    # Read the input file line by line
    Get-Content $InputFilePath | ForEach-Object {
        $line = $_

        if ($isHeaderCapturing) {
            # Check if this line is the start of the first actual Lua file
            if ($line -match $startDelimiterPattern) {
                $isHeaderCapturing = $false

                # If there's content in the header buffer, save it as a special file
                if ($headerBuffer.Count -gt 0) {
                    Save-LuaFileContent -FileName $headerFileName -Content $headerBuffer -BaseOutputDirectory $OutputDirectory
                    $fileOrder.Add($headerFileName) | Out-Null
                }

                # Now, proceed with the first actual Lua file
                $currentFileName = $Matches.filename
                $fileOrder.Add($currentFileName) | Out-Null
                $isCapturing = $true
                $contentBuffer.Clear()
                $contentBuffer.Add($line) | Out-Null
                Write-Host "  Found start of: '$currentFileName'"
            } else {
                # Still in header, add line to header buffer
                $headerBuffer.Add($line) | Out-Null
            }
        }
        elseif ($line -match $startDelimiterPattern) {
            # If we were already capturing content for a previous file, save it
            if ($isCapturing -and $currentFileName) {
                Write-Warning "  Warning: Found new start tag for '$($Matches.filename)' before end tag for '$currentFileName'. Saving content for '$currentFileName'."
                Save-LuaFileContent -FileName $currentFileName -Content $contentBuffer -BaseOutputDirectory $OutputDirectory
            }

            $currentFileName = $Matches.filename
            $fileOrder.Add($currentFileName) | Out-Null
            $isCapturing = $true
            $contentBuffer.Clear()
            $contentBuffer.Add($line) | Out-Null
            Write-Host "  Found start of: '$currentFileName'"
        }
        elseif ($line -match $endDelimiterPattern) {
            $endFileName = $Matches.filename
            if ($isCapturing -and $currentFileName -eq $endFileName) {
                $contentBuffer.Add($line) | Out-Null
                Save-LuaFileContent -FileName $currentFileName -Content $contentBuffer -BaseOutputDirectory $OutputDirectory
                $isCapturing = $false
                $contentBuffer.Clear()
            }
            elseif ($isCapturing -and $currentFileName -ne $endFileName) {
                Write-Warning "  Warning: Mismatched END OF tag found. Expected '$currentFileName', got '$endFileName'. Continuing capture for '$currentFileName'."
                $contentBuffer.Add($line) | Out-Null
            }
            else {
                Write-Warning "  Warning: Found END OF tag ('$endFileName') while not actively capturing a file block. Skipping this line."
            }
        }
        elseif ($isCapturing) {
            $contentBuffer.Add($line) | Out-Null
        }
    }

    # --- Final Check: Handle any remaining content ---
    if ($isHeaderCapturing -and $headerBuffer.Count -gt 0) {
        Write-Warning "  Warning: Input file ended while still capturing header content. Saving remaining header."
        Save-LuaFileContent -FileName $headerFileName -Content $headerBuffer -BaseOutputDirectory $OutputDirectory
        $fileOrder.Add($headerFileName) | Out-Null
    }
    elseif ($isCapturing -and $currentFileName) {
        Write-Warning "  Warning: Input file ended while still capturing content for '$currentFileName'. Saving remaining content."
        Save-LuaFileContent -FileName $currentFileName -Content $contentBuffer -BaseOutputDirectory $OutputDirectory
    }

    # --- Write the file order list ---
    # Ensure header is always first if it exists
    if ($fileOrder.Contains($headerFileName)) {
        $fileOrder.Remove($headerFileName) | Out-Null
        $fileOrder.Insert(0, $headerFileName) | Out-Null
    }
    $registryFilePath = Join-Path $OutputDirectory $registryFileName
    Write-Host "Writing file order to: '$registryFilePath'"
    $fileOrder | Set-Content $registryFilePath

    Write-Host "Extraction finished successfully. Split files and registry list are in '$OutputDirectory'."

} catch {
    Write-Error "An error occurred during extraction: $($_.Exception.Message)"
    exit 1
}