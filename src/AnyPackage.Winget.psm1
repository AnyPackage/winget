using module AnyPackage
using namespace AnyPackage.Provider

# Current script path
[string]$ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.MyCommand.Definition -Parent

# Dot sourcing private script files
Get-ChildItem $ScriptPath/private -Recurse -Filter '*.ps1' -File | ForEach-Object {
	. $_.FullName
}

[PackageProvider("WinGet")]
class WinGetProvider : PackageProvider, IGetSource, ISetSource, IGetPackage, IFindPackage, IInstallPackage, IUninstallPackage {
	WinGetProvider() : base('47e987f7-7d96-4e7b-853e-182ee6e396ae') { }

	[void] GetSource([SourceRequest] $Request) {
		Cobalt\Get-WinGetSource | Where-Object {$_.Name -Like $Request.Name} | ForEach-Object {
			$Request.WriteSource($_.Name, $_.Arg, $true)
		}
	}

	[void] RegisterSource([SourceRequest] $Request) {
		Cobalt\Register-WinGetSource -Name $Request.Name -Argument $Request.Location
		# WinGet doesn't return anything after source operations, so we make up our own output object
		$Request.WriteSource($Request.Name, $Request.Location.TrimEnd("\"), $Request.Trusted)
	}

	[void] UnregisterSource([SourceRequest] $Request) {
		Cobalt\Unregister-WinGetSource -Name $Request.Name
		# WinGet doesn't return anything after source operations, so we make up our own output object
		$Request.WriteSource($Request.Name, '')
	}

	[void] SetSource([SourceRequest] $Request) {
		$this.RegisterSource($Request)
	}

	[void] GetPackage([PackageRequest] $Request) {
		Get-WinGetPackage | Write-Package
	}

	[void] FindPackage([PackageRequest] $Request) {
		Find-WinGetPackage | Write-Package
	}

	[void] InstallPackage([PackageRequest] $Request) {
		# Run the package request first through Find-WinGetPackage to determine which source to use, and filter by any version requirements
		Find-WinGetPackage | Cobalt\Install-WinGetPackage | Write-Package
	}

	[void] UninstallPackage([PackageRequest] $Request) {
		# Run the package request first through Get-WinGetPackage to filter by any version requirements and save it off for later use
		$result = Get-WinGetPackage
		Cobalt\Uninstall-WinGetPackage $result.ID

		# WinGet doesn't return any output on successful uninstallation, so we have to make up a new object to satisfy AnyPackage
		Write-Package $result
	}
}

[PackageProviderManager]::RegisterProvider([WinGetProvider], $MyInvocation.MyCommand.ScriptBlock.Module)

