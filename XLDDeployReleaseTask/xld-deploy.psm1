<#
The scripts in the following file are copied from the task: https://marketplace.visualstudio.com/items?itemName=xebialabs.tfs2015-xl-deploy-plugin
created by Xebia. Some methods are modified.
#>

<############################################################################################ 
    Checks if the initial or update deployments are necessary, and prepares the 
	given deployment.
############################################################################################>
function Get-Deployment()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$deploymentPackageId,
        [string][parameter(Mandatory = $true)]$targetEnvironment,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "deploymentPackageId = $deploymentPackageId"
        Write-Verbose "targetEnvironment = $targetEnvironment"
    }
    PROCESS {
        # Extract application name from deployment Package Id
        # as we expect a value like "Applications/Finance/Simple Web Project/1.0.0.2"
        # we need to split this string on '/' character and get second-last element
        $path = $deploymentPackageId.Split('/')
        $applicationName = $path[$path.Count - 2]
        $version = $path[$path.Count - 1]

        Write-Verbose "applicationName = $applicationName"
        Write-Verbose "version = $version"

        if (Test-ApplicationAlreadyDeployed $targetEnvironment $applicationName $EndpointUrl $Credential) {
            return GetDeploymentObject $deploymentPackageId "$targetEnvironment/$applicationName" $EndpointUrl $Credential
        }

        return GetInitialDeploymentObject $deploymentPackageId $targetEnvironment $EndpointUrl $Credential
    }
    END { }
}

<############################################################################################ 
    Prepares an update deployment.
############################################################################################>
function GetDeploymentObject()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$deploymentId,
        [string][parameter(Mandatory = $true)]$deployedApplication,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "deployedApplication = $deployedApplication"
        Write-Verbose "deploymentId = $deploymentId"

		$deploymentId = [System.Uri]::EscapeDataString($deploymentId) 
        $deployedApplication = [System.Uri]::EscapeDataString($deployedApplication) 
    }
    PROCESS
    {
        $uri = "$EndpointUrl/deployment/prepare/update?version=$deploymentId&deployedApplication=$deployedApplication"
        $response = Invoke-RestMethod $uri -Credential $Credential

        return $response
    }
    END { }
}

<############################################################################################ 
    Prepares an initial deployment.
############################################################################################>
function GetInitialDeploymentObject()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$deploymentId,
        [string][parameter(Mandatory = $true)]$targetEnvironment,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "targetEnvironment = $targetEnvironment"
        Write-Verbose "deploymentId = $deploymentId"

		$deploymentId = [System.Uri]::EscapeDataString($deploymentId) 
        $deployedApplication = [System.Uri]::EscapeDataString($deployedApplication) 
    }
    PROCESS
    {
        return Invoke-RestMethod "$EndpointUrl/deployment/prepare/initial?version=$deploymentId&environment=$targetEnvironment" -Credential $Credential
    }
    END { }
}

<############################################################################################ 
    Prepares all the deployeds for the given deployment. This will keep any previous 
	deployeds present in the deployment object that are already present, unless they cannot
	be deployed with regards to their tags. It will add all the deployeds that are still
	missing. Also filters out the deployeds that do not have any source attached anymore 
	(deployables that were previously present).
############################################################################################>
function Get-Deployed()
{
    [CmdletBinding()]
    param
    (
        [xml][parameter(Mandatory = $true)]$deployment,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "deployment = $($deployment.OuterXml)"
    }
    PROCESS
    {
        return Invoke-RestMethod "$EndpointUrl/deployment/prepare/deployeds" -Method Post -Body $deployment -ContentType "application/xml" -Credential $Credential
    }
    END { }
}

<############################################################################################ 
    Validates the generated deployment. Checks whether all the deployeds that are in the 
	deployment are valid.
############################################################################################>
function Confirm-Deployment()
{
    [CmdletBinding()]
    param
    (
        [xml][parameter(Mandatory = $true)]$deployment,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "deployment = $($deployment.OuterXml)"
    }
    PROCESS
    {
        return Invoke-RestMethod "$EndpointUrl/deployment/validate" -Method Post -Body $deployment -ContentType "application/xml" -Credential $Credential
    }
    END { }
}

<############################################################################################ 
    Rollback a STOPPED or EXECUTED task. Reverting the deployment to the previous state.
	The task will be set to CANCELLED when it was STOPPED , and DONE when it was EXECUTED.
############################################################################################>
function New-RollbackTask()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$taskId,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "taskId = $taskId"

        $taskId = Get-EncodedPathPart($taskId)
    }
    PROCESS
    {
        return Invoke-RestMethod "$EndpointUrl/deployment/rollback/$taskId" -Method Post -ContentType "application/xml" -Credential $Credential
    }
    END { }
}

<############################################################################################ 
    Prepares given deployment and deployeds and creates a new deployment task.
############################################################################################>
function New-DeploymentTask()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$deploymentPackageId,
        [string][parameter(Mandatory = $true)]$targetEnvironment,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "deploymentPackageId = $deploymentPackageId"
        Write-Verbose "targetEnvironment = $targetEnvironment"
    }
    PROCESS
    {
        $deployment = Get-Deployment $deploymentPackageId $targetEnvironment $EndpointUrl $Credential
        $deployment = Get-Deployed $deployment $EndpointUrl $Credential
        $deployment = Confirm-Deployment $deployment $EndpointUrl $Credential

        return New-Task $deployment $EndpointUrl $Credential
    }
    END { }
}

<############################################################################################ 
    Creates the deployment task.
############################################################################################>
function New-Task()
{
    [CmdletBinding()]
    param
    (
        [xml][parameter(Mandatory = $true)]$deployment,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN { }
    PROCESS
    {
        return Invoke-RestMethod "$EndpointUrl/deployment/" -Method Post -Body $deployment -ContentType "application/xml" -Credential $Credential
    }
    END { }
}

<############################################################################################ 
    Starts a task.
############################################################################################>
function Start-Task()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$taskId,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "taskId = $taskId"
    }
    PROCESS
    {
        return Invoke-RestMethod "$EndpointUrl/tasks/v2/$taskId/start" -Method Post -ContentType "application/xml" -Credential $Credential
    }
    END { }
}

<############################################################################################ 
    Archive an executed task.
############################################################################################>
function Complete-Task()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$taskId,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "taskId = $taskId"

		$taskId = Get-EncodedPathPart($taskId)
    }
    PROCESS
    { 
        return Invoke-RestMethod "$EndpointUrl/tasks/v2/$taskId/archive" -Method Post -ContentType "application/xml" -Credential $Credential
    }
    END { }
}

<############################################################################################ 
    Returns a task state for a given task ID.
############################################################################################>
function Get-TaskState()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$taskId,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN 
    {
        Write-Verbose "taskId = $taskId"
    }
    PROCESS
    {
        $response = Invoke-RestMethod "$EndpointUrl/tasks/v2/$taskId" -Credential $Credential
        
        return $response.task.state
    }
    END { }
}

<############################################################################################ 
    Pools a call and checks the task state every five seconds, until task doesn't get in a
	non running state.
############################################################################################>
function Get-TaskOutcome()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$taskId,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "taskId = $taskId" 
    }
    PROCESS
    {
        $taskState = Get-TaskState $taskId $EndpointUrl $Credential
        
        while (IsTaskRunning($taskState))
        {
            start-sleep -seconds 5

            $taskState = Get-TaskState $taskId $EndpointUrl $Credential
        }

        return $taskState
    }
    END { }
}

<############################################################################################ 
    Checks if the given state is in one of the states known as running states.
############################################################################################>
function IsTaskRunning()
{
    param
    (
        [string][parameter(Mandatory = $true)]$taskState
    )

    Write-Verbose "Current task state is $taskState"

    $runningStates = "QUEUED", "EXECUTING", "ABORTING", "STOPPING", "FAILING", "PENDING"

    foreach($state in $runningStates)
    {
        if ($taskState -eq $state)
        {
            return $true
        }
    }

    return $false
}

<############################################################################################ 
    Checks if the given application exists.
############################################################################################>
function Test-ApplicationAlreadyDeployed()
{
    [CmdletBinding()]
    param
    (
        [string][parameter(Mandatory = $true)]$targetEnvironment,
        [string][parameter(Mandatory = $true)]$applicationName,
        [string][parameter(Mandatory = $true)]$EndpointUrl,
        [System.Management.Automation.PSCredential][parameter(Mandatory = $true)]$Credential
    )
    BEGIN
    {
        Write-Verbose "targetEnvironment = $targetEnvironment"
        Write-Verbose "applicationName = $applicationName"

        $targetEnvironment = Get-EncodedPathPart($targetEnvironment) 
        $applicationName = Get-EncodedPathPart($applicationName) 
    }
    PROCESS
    {
        $response = Invoke-RestMethod $EndpointUrl/repository/exists/$targetEnvironment/$applicationName -Credential $Credential

        Write-Verbose ("Application {0} exists: {1} at {2}" -f $applicationName, $response.boolean, $EndpointUrl)

        return [boolean]::Parse($response.boolean)
    }
    END { }
}