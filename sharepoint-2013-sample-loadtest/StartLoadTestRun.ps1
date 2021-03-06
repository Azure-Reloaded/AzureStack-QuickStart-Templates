param(
	[parameter(Mandatory = $true)][System.String]$LoadTestPath,
	[parameter(Mandatory = $true)][System.String]$TestControllerName
)
function LogToFile
{
   param (
		[parameter(Mandatory = $true)][System.String]$Message,
		[System.String]$LogFilePath = "$env:SystemDrive\CustomScriptExtensionLogs\CustomScriptExtension.log"
   )
   $timestamp = Get-Date -Format s
   $logLine = "[$($timestamp)] $($Message)"
   Add-Content $LogFilePath -value $logLine
}

if(!(Test-Path $LoadTestPath))
{
	LogToFile -Message "$($LoadTestPath) not found"
	throw [System.IO.FileNotFoundException] "$($LoadTestPath) not found"
}
$ltFolder = Split-Path $LoadTestPath -Parent
$testSettingsFileName = "RunRemote.testsettings"
$testSettingsTemplate = @"
<?xml version="1.0" encoding="UTF-8"?>
<TestSettings name="Remote" id="b2b7ccf4-395c-4ffc-8bc3-58e4bfac5cc3" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Description>These are default test settings for a local test run.</Description>
  <RemoteController name="%TESTCONTROLLER%" />
  <Execution location="Remote">
    <TestTypeSpecific>
      <UnitTestRunConfig testTypeId="13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b">
        <AssemblyResolution>
          <TestDirectory useLoadContext="true" />
        </AssemblyResolution>
      </UnitTestRunConfig>
      <WebTestRunConfiguration testTypeId="4e7599fa-5ecb-43e9-a887-cd63cf72d207">
        <Browser name="Internet Explorer 9.0" MaxConnections="6">
          <Headers>
            <Header name="User-Agent" value="Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)" />
            <Header name="Accept" value="*/*" />
            <Header name="Accept-Language" value="{{$IEAcceptLanguage}}" />
            <Header name="Accept-Encoding" value="GZIP" />
          </Headers>
        </Browser>
      </WebTestRunConfiguration>
    </TestTypeSpecific>
    <AgentRule name="AllAgentsDefaultRole">
    </AgentRule>
  </Execution>
  <Properties />
</TestSettings>
"@
$testSettingsToUse = $testSettingsTemplate.Replace("%TESTCONTROLLER%", $TestControllerName)
$testSettingsPath = Join-Path $ltFolder $testSettingsFileName
if(!(Test-Path $testSettingsPath))
{
	LogToFile -Message "Creating the test settings file"
	New-Item $testSettingsPath -ItemType file
	Out-File -FilePath $testSettingsPath -InputObject $testSettingsToUse -Encoding Oem
	LogToFile -Message "Done creating the test settings file"
}
else
{
	LogToFile -Message "Test settings file already exists on the environment"
}
$testResultsFolder = "LoadTestResults"
$testResultsPath = Join-Path $env:SystemDrive $testResultsFolder
if(!(Test-Path $testResultsPath))
{
	New-Item $testResultsPath -ItemType directory
}
$resultsFileNamePostfix = Get-Date -Format FileDateTime
$resultsFileName = "RunResults$($resultsFileNamePostfix).trx"
$resultsFilePath = Join-Path $testResultsPath $resultsFileName

$MSTestPathString = "Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\MSTest.exe"
$MSTestPath = Join-Path $env:SystemDrive $MSTestPathString
$ltargs =  " /testcontainer:$($LoadTestPath) /testsettings:$($testSettingsPath) /resultsfile:$($resultsFilePath)"
$command = $MSTestPath + $ltargs
LogToFile -Message "Starting load test run"
([WMICLASS]"\\$env:computername\ROOT\CIMV2:win32_process").Create($command)
LogToFile -Message "Load test run executing, test results file for the run to be placed at $($resultsFilePath)"