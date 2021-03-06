param (
    [ValidateSet("debug", "release")][string]$Configuration="release",    
    [switch]$Clean,
	[switch]$SkipTests
)

# Build a project k project.
# - projectDirectory is the root directory of the project
# - outputDirectory is the directory where the generated nupkg files are copied to
function ProjectKBuild([string]$projectDirectory, [string]$outputDirectory) 
{
    Write-Host "======== Building in $ProjectDirectory ======"

    # build the project
	$prevDirectory = Get-Location
	cd $projectDirectory
    & ".\build.cmd"
	$result = $lastexitcode
	cd $prevDirectory

    Write-Output "last exit code $result"
    if ($result -ne 0) 
    {		
		$errorMessage = "Build failed. Project directory is $projectDirectory"
    	throw $errorMessage
    }

    # copy the generated nupkgs
    $artifactDirectory = Join-Path $projectDirectory "artifacts\build"
    Copy-Item (Join-Path $artifactDirectory "*.nupkg") $outputDirectory -Verbose:$true
}

# remove NuGet.* packages from the specified directory
function RemovePackages([string]$packagesDirectory)
{
    if (Test-Path "$packagesDirectory") 
    { 
        rm -r -force "$packagesDirectory\NuGet.*" 
    }
}

function BuildNuGetPackageManagement()
{
	cd "$GitRoot\NuGet.PackageManagement"
	$env:NUGET_PUSH_TARGET = $packagesDirectory
	$args = @{ Configuration = $Configuration; PushTarget = $packagesDirectory;
		Version = $Version; NoLock = $true }
	if ($SkipTests)
	{	
		$args.Add("SkipTests", $true)
	}

	& "$GitRoot\NuGet.PackageManagement\pack.ps1" @args
	$result = $lastexitcode
	cd $GitRoot

	if ($result -ne 0) 
	{		
	  	throw "Build failed"
	}
}

function BuildVSExtension()
{
	cd "$GitRoot\NuGet.VisualStudioExtension"
	& nuget restore -source "$GitRoot\nupkgs"
	& nuget restore
	$env:VisualStudioVersion="14.0"
	& msbuild NuGet.VisualStudioExtension.sln /p:Configuration=$Configuration /p:VisualStudioVersion="14.0" /p:DeployExtension=false
	cd $GitRoot
}

# version number of non-k projects
$Version="3.0.0-beta"

# set environment used by k
$env:Configuration=$Configuration
$env:DNX_BUILD_VERSION="beta"

# Create the packages directory
$GitRoot = Get-Location
$packagesDirectory = "$GitRoot\nupkgs"
if (!(Test-Path $packagesDirectory))
{
	mkdir $packagesDirectory
}

if ($Clean)
{
    rm "$packagesDirectory\*.nupkg"
    
    RemovePackages "$GitRoot\NuGet3\packages"
    RemovePackages "$GitRoot\NuGet.PackageManagement\packages"
    RemovePackages "$GitRoot\NuGet.VisualStudioExtension\packages"
}

# build k-based solutions
ProjectKBuild "$GitRoot\NuGet3" "$GitRoot\nupkgs"

# now build NuGet.PackageManagement
BuildNuGetPackageManagement

# build nuget.VisualStudioExtension
BuildVSExtension