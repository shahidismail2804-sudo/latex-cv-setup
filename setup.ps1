# ============================================
# LaTeX CV Setup
# ============================================

Write-Host "============================================"
Write-Host "       LaTeX CV Setup"
Write-Host "============================================"
Write-Host ""

# --------------------------------------------
# Operating System Detection
# --------------------------------------------

if ($env:OS -eq "Windows_NT") {
    Write-Host "Operating System: Windows"
}
elseif ($IsMacOS) {
    Write-Host "Operating System: macOS"
}
elseif ($IsLinux) {
    Write-Host "Operating System: Linux"
}
else {
    Write-Host "Unsupported operating system."
    exit 1
}

Write-Host ""

# --------------------------------------------
# WinGet Detection
# --------------------------------------------

if ($env:OS -eq "Windows_NT") {

    Write-Host "Checking for WinGet..."

    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if ($null -eq $winget) {
        Write-Host ""
        Write-Host "ERROR: WinGet was not found."
        Write-Host "Please install or enable WinGet and run this setup again."
        exit 1
    }

    Write-Host "WinGet found."
    Write-Host "WinGet path: $($winget.Source)"

    $wingetVersion = winget --version

    Write-Host "WinGet version: $wingetVersion"
}

Write-Host ""

# --------------------------------------------
# Required Software
# --------------------------------------------

$requiredSoftware = @(
    @{
        Name = "Git"
        Id = "Git.Git"
        Command = "git"
    },
    @{
        Name = "Visual Studio Code"
        Id = "Microsoft.VisualStudioCode"
        Command = "code"
    },
    @{
        Name = "MiKTeX"
        Id = "MiKTeX.MiKTeX"
        Command = "pdflatex"
    }
)

# --------------------------------------------
# Ask User For Permission
# --------------------------------------------

function Confirm-YesNo {
    param(
        [string]$Question
    )

    while ($true) {

        $answer = Read-Host "$Question [Y/N]"

        if ($answer -match '^[Yy]$') {
            return $true
        }

        if ($answer -match '^[Nn]$') {
            return $false
        }

        Write-Host "Please enter Y or N."
    }
}

# --------------------------------------------
# Installation Function
# --------------------------------------------

function Install-WingetPackage {
    param(
        [string]$Name,
        [string]$Id
    )

    Write-Host ""
    Write-Host "Installing $Name..."
    Write-Host ""

    try {

        winget install `
            --id $Id `
            --exact `
            --source winget `
            --accept-source-agreements `
            --accept-package-agreements

        if ($LASTEXITCODE -eq 0) {

            Write-Host ""
            Write-Host "$Name installation completed successfully."

            return $true
        }
        else {

            Write-Host ""
            Write-Host "$Name installation failed."
            Write-Host "WinGet exit code: $LASTEXITCODE"

            return $false
        }

    }
    catch {

        Write-Host ""
        Write-Host "An error occurred while installing $Name."
        Write-Host $_.Exception.Message

        return $false
    }
}

# --------------------------------------------
# Update Environment PATH
# --------------------------------------------

function Update-EnvironmentPath {

    Write-Host ""
    Write-Host "Refreshing environment PATH..."

    $userPath = [Environment]::GetEnvironmentVariable(
        "Path",
        "User"
    )

    $machinePath = [Environment]::GetEnvironmentVariable(
        "Path",
        "Machine"
    )

    if ($null -eq $userPath) {
        $userPath = ""
    }

    if ($null -eq $machinePath) {
        $machinePath = ""
    }

    # Update PATH for the current PowerShell process
    $env:Path = "$userPath;$machinePath"

    Write-Host "PATH refreshed."
}

# --------------------------------------------
# Initialize MiKTeX
# --------------------------------------------

function Initialize-MiKTeX {

    Write-Host ""
    Write-Host "Checking MiKTeX / pdflatex..."

    # ----------------------------------------
    # Check if pdflatex is already available
    # ----------------------------------------

    $pdflatexCommand = Get-Command `
        pdflatex `
        -ErrorAction SilentlyContinue

    if ($null -ne $pdflatexCommand) {

        Write-Host "[OK] pdflatex found:"
        Write-Host "     $($pdflatexCommand.Source)"

        return $true
    }

    Write-Host "pdflatex is not currently available in PATH."
    Write-Host "Searching for MiKTeX installation..."

    # ----------------------------------------
    # Possible MiKTeX installation locations
    # ----------------------------------------

    $possiblePaths = @()

    # User installation
    if ($env:LOCALAPPDATA) {

        $possiblePaths += Join-Path `
            $env:LOCALAPPDATA `
            "Programs\MiKTeX\miktex\bin\x64"
    }

    # Program Files installation
    if ($env:ProgramFiles) {

        $possiblePaths += Join-Path `
            $env:ProgramFiles `
            "MiKTeX\miktex\bin\x64"
    }

    # Program Files x86 installation
    if (${env:ProgramFiles(x86)}) {

        $possiblePaths += Join-Path `
            ${env:ProgramFiles(x86)} `
            "MiKTeX\miktex\bin\x64"
    }

    # ----------------------------------------
    # Search for pdflatex.exe
    # ----------------------------------------

    $foundPath = $null

    foreach ($path in $possiblePaths) {

        $candidate = Join-Path `
            $path `
            "pdflatex.exe"

        if (Test-Path $candidate) {

            $foundPath = $path
            break
        }
    }

    # ----------------------------------------
    # Refresh PATH if necessary
    # ----------------------------------------

    if ($null -eq $foundPath) {

        Update-EnvironmentPath

        $pdflatexCommand = Get-Command `
            pdflatex `
            -ErrorAction SilentlyContinue

        if ($null -ne $pdflatexCommand) {

            Write-Host "[OK] pdflatex found after PATH refresh:"
            Write-Host "     $($pdflatexCommand.Source)"

            return $true
        }
    }

    # ----------------------------------------
    # Add MiKTeX directory to current PATH
    # ----------------------------------------

    if ($null -ne $foundPath) {

        Write-Host "[OK] MiKTeX found:"
        Write-Host "     $foundPath"

        if ($env:Path -notlike "*$foundPath*") {

            Write-Host "Adding MiKTeX to current PATH..."

            $env:Path = "$foundPath;$env:Path"
        }

        # ------------------------------------
        # Verify pdflatex
        # ------------------------------------

        $pdflatexCommand = Get-Command `
            pdflatex `
            -ErrorAction SilentlyContinue

        if ($null -ne $pdflatexCommand) {

            Write-Host "[OK] pdflatex is now available:"
            Write-Host "     $($pdflatexCommand.Source)"

            return $true
        }
    }

    # ----------------------------------------
    # MiKTeX not found
    # ----------------------------------------

    Write-Host ""
    Write-Host "[ERROR] MiKTeX was detected/installed,"
    Write-Host "but pdflatex.exe could not be located."
    Write-Host ""

    Write-Host "Expected MiKTeX locations:"

    foreach ($path in $possiblePaths) {
        Write-Host "  $path"
    }

    return $false
}

# --------------------------------------------
# Check And Install Software
# --------------------------------------------

Write-Host "Checking required software..."
Write-Host ""

$installed = @()
$skipped = @()
$failed = @()

foreach ($software in $requiredSoftware) {

    # ----------------------------------------
    # Special handling for MiKTeX
    # ----------------------------------------

    if ($software.Name -eq "MiKTeX") {

        $pdflatexCommand = Get-Command `
            pdflatex `
            -ErrorAction SilentlyContinue

        if ($null -ne $pdflatexCommand) {

            Write-Host "[INSTALLED] MiKTeX"
            $installed += "MiKTeX"

        }
        else {

            Write-Host ""
            Write-Host "[MISSING] MiKTeX"
            Write-Host "WinGet ID: $($software.Id)"

            $permission = Confirm-YesNo `
                "Install MiKTeX using WinGet?"

            if ($permission) {

                $result = Install-WingetPackage `
                    -Name $software.Name `
                    -Id $software.Id

                if ($result) {

                    # WinGet may update PATH only for
                    # future processes.
                    #
                    # Initialize MiKTeX immediately
                    # for this PowerShell process.

                    $miktexReady = Initialize-MiKTeX

                    if ($miktexReady) {
                        $installed += "MiKTeX"
                    }
                    else {
                        $failed += "MiKTeX"
                    }

                }
                else {

                    $failed += "MiKTeX"
                }

            }
            else {

                Write-Host "Skipped MiKTeX."
                $skipped += "MiKTeX"
            }
        }

        continue
    }

    # ----------------------------------------
    # Normal software handling
    # ----------------------------------------

    $command = Get-Command `
        $software.Command `
        -ErrorAction SilentlyContinue

    if ($null -ne $command) {

        Write-Host "[INSTALLED] $($software.Name)"
        $installed += $software.Name

    }
    else {

        Write-Host ""
        Write-Host "[MISSING] $($software.Name)"
        Write-Host "WinGet ID: $($software.Id)"

        $permission = Confirm-YesNo `
            "Install $($software.Name) using WinGet?"

        if ($permission) {

            $result = Install-WingetPackage `
                -Name $software.Name `
                -Id $software.Id

            if ($result) {

                $installed += $software.Name

            }
            else {

                $failed += $software.Name
            }

        }
        else {

            Write-Host "Skipped $($software.Name)."
            $skipped += $software.Name
        }
    }
}

# --------------------------------------------
# Final MiKTeX Verification
# --------------------------------------------

$miktexReady = Initialize-MiKTeX

if (-not $miktexReady) {

    Write-Host ""
    Write-Host "ERROR: pdflatex is required to compile the CV."
    Write-Host "Please install MiKTeX and run setup again."

    exit 1
}

# --------------------------------------------
# LaTeX Workshop Extension
# --------------------------------------------

Write-Host ""
Write-Host "Checking LaTeX Workshop extension..."

$latexWorkshopId = "james-yu.latex-workshop"

$codeCommand = Get-Command `
    code `
    -ErrorAction SilentlyContinue

if ($null -eq $codeCommand) {

    Write-Host "[SKIPPED] VS Code command was not found."

}
else {

    $extensions = code --list-extensions 2>$null

    if ($extensions -contains $latexWorkshopId) {

        Write-Host "[INSTALLED] LaTeX Workshop"

        $installed += "LaTeX Workshop"

    }
    else {

        Write-Host "[MISSING] LaTeX Workshop"
        Write-Host "Extension ID: $latexWorkshopId"

        $permission = Confirm-YesNo `
            "Install LaTeX Workshop extension?"

        if ($permission) {

            Write-Host ""
            Write-Host "Installing LaTeX Workshop..."

            code --install-extension `
                $latexWorkshopId `
                --force

            if ($LASTEXITCODE -eq 0) {

                Write-Host ""
                Write-Host "LaTeX Workshop installed successfully."

                $installed += "LaTeX Workshop"

            }
            else {

                Write-Host ""
                Write-Host "LaTeX Workshop installation failed."

                $failed += "LaTeX Workshop"
            }

        }
        else {

            Write-Host "Skipped LaTeX Workshop."

            $skipped += "LaTeX Workshop"
        }
    }
}

# --------------------------------------------
# Final Summary
# --------------------------------------------

Write-Host ""
Write-Host "============================================"
Write-Host "             Setup Summary"
Write-Host "============================================"

Write-Host ""
Write-Host "Installed / Available:"

foreach ($item in $installed) {
    Write-Host "  [OK]      $item"
}

Write-Host ""
Write-Host "Skipped:"

foreach ($item in $skipped) {
    Write-Host "  [SKIPPED] $item"
}

Write-Host ""
Write-Host "Failed:"

foreach ($item in $failed) {
    Write-Host "  [FAILED]  $item"
}

Write-Host ""
Write-Host "Setup checks completed."

# --------------------------------------------
# Compile LaTeX CV
# --------------------------------------------

Write-Host ""
Write-Host "Checking LaTeX CV..."

if (Test-Path "main.tex") {

    Write-Host "main.tex found."

    # ----------------------------------------
    # Final pdflatex verification
    # ----------------------------------------

    $pdflatexCommand = Get-Command `
        pdflatex `
        -ErrorAction SilentlyContinue

    if ($null -eq $pdflatexCommand) {

        Write-Host ""
        Write-Host "ERROR: pdflatex is not available."
        Write-Host "Cannot compile main.tex."

        exit 1
    }

    Write-Host ""
    Write-Host "pdflatex found:"
    Write-Host "$($pdflatexCommand.Source)"

    # ----------------------------------------
    # Compile CV
    # ----------------------------------------

    Write-Host ""
    Write-Host "Compiling CV..."
    Write-Host ""

    & pdflatex `
        -interaction=nonstopmode `
        -halt-on-error `
        main.tex

    if ($LASTEXITCODE -eq 0) {

        Write-Host ""
        Write-Host "============================================"
        Write-Host "        CV COMPILED SUCCESSFULLY"
        Write-Host "============================================"

        if (Test-Path "main.pdf") {

            Write-Host ""
            Write-Host "PDF generated successfully: main.pdf"
            Write-Host ""
            Write-Host "PDF location:"
            Write-Host "$(Join-Path (Get-Location) 'main.pdf')"

        }
        else {

            Write-Host ""
            Write-Host "WARNING: Compilation succeeded"
            Write-Host "but main.pdf was not found."
        }

    }
    else {

        Write-Host ""
        Write-Host "============================================"
        Write-Host "        CV COMPILATION FAILED"
        Write-Host "============================================"

        Write-Host ""
        Write-Host "Please check main.log for details."

        exit 1
    }

}
else {

    Write-Host ""
    Write-Host "WARNING: main.tex was not found."
    Write-Host "Skipping CV compilation."
}