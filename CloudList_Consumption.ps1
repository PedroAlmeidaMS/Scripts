$resourceGroupName = 'Your ResourceGroup'

$path = '/home/' + $Env:USER
$csvSecureFilepath = $path + '/SecureLogicApps.csv'
$csvUnsecureFilepath = $path + '/UnsecureLogicApps.csv'

#Get Resource Group Info
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$resourceGroupPath = $resourceGroup.ResourceId
Write-Host 'Resource Group Path: '  $resourceGroupPath

#use the collection to build up objects for the table
$secureLADictionary = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.Object]" 
$nonSecureLADictionary = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.Object]" 
$boolCheck = $false


#Check logic apps to find orphaned connectors
Write-Host ''
Write-Host 'Looking up Consumption Logic Apps'

$resources = Get-AzResource -ResourceGroupName $resourcegroupName -ResourceType Microsoft.Logic/workflows
$resources | ForEach-Object {    

    $resourceName = $_.Name    
    $logicAppName = $resourceName
    $logicApp = Get-AzLogicApp -Name $logicAppName -ResourceGroupName $resourceGroupName        
    $logicAppUrl = $resourceGroupPath + '/providers/Microsoft.Logic/workflows/' + $logicApp.Name + '?api-version=2018-07-01-preview'
    
    #Get Logic App Content using Az REST GET
    $logicAppJson = az rest --method get --uri $logicAppUrl
    $logicAppJsonText = $logicAppJson | ConvertFrom-Json
    #Check Logic App Actions inside the Logic App JSON
    #Iterate through the connectors
    Write-Host 'Logic App ' $logicAppName ''

    Write-Host 'Checking Logic App if is using Secure Inputs'
    #Check Logic App Actions inside the Logic App JSON
    $logicAppActions = $logicAppJsonText.properties.definition.actions

    $logicAppActions.psobject.properties | ForEach-Object{
        Write-Host 'Logic App Action name: ' $_.Name
        if($_.Value.runtimeConfiguration.secureData -ne $null)
            {
                Write-Host 'Has Secure data'
                $boolCheck = $true
            }                  
    }
    
   $la = New-Object -TypeName psobject
   if($boolCheck -eq $true)
   {
        #Add to Secure List        
                $resourceIdLower = $logicApp.id.ToLower()
        ##Add members to the dictionary     
        $la | Add-Member -MemberType NoteProperty -Name 'Name' -Value $logicApp.Name
        $la | Add-Member -MemberType NoteProperty -Name 'Id' -Value $logicApp.Id
        $secureLADictionary.Add($resourceIdLower, $la)

   }
   else
   {
        #Add to Non-secure list
        $resourceIdLower = $logicApp.id.ToLower()
        ##Add members to the dictionary    
        $la | Add-Member -MemberType NoteProperty -Name 'Name' -Value $logicApp.Name
        $la | Add-Member -MemberType NoteProperty -Name 'Id' -Value $logicApp.Id
        $nonSecureLADictionary.Add($resourceIdLower, $azureConnector)
   }


   #reset boolCheck
    $boolCheck = $false
}

Write-Host ''
Write-Host 'Secure Logic Apps'
$secureLADictionary.Values | ForEach-Object{
    Write-Host $_.name 
}
Write-Host 'Non Secure Logic Apps'
$nonSecureLADictionary.Values | ForEach-Object{
    Write-Host $_.name 
}

$secureLADictionary.Values | Export-Csv -Path $csvSecureFilepath
$nonSecureLADictionary.Values | Export-Csv -Path $csvUnsecureFilepath