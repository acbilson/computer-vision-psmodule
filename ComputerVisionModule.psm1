<#
    Computer Vision API Script Module
    Author: Alex Bilson (alex.bilson@spr.com)
    Last Updated: 2-August-2019

    Description:
    
        This script module simplifies the use of the Computer Vision API to analyze images

    Setup:

        This script requires an Azure Cognitive Service account. Please supply the example values in a settings.json file in the same path as this script.

    Example:

        {
            'host': 'westcentralus.api.cognitive.microsoft.com', # no forward slashes please
            key: 'sfslkja;sldj;' # the subscription key given you by Microsoft when you register your account. there are two keys; the first is fine
        }

#>

########################################
# Helper Functions (not exported by module)
########################################

# Reads the settings from .\settings.json
function Read-Settings {

    $settings = Get-Content -Path .\settings.json -Raw | ConvertFrom-Json
    return $settings
}

# Simplifies the http request
function New-HttpRequestUri
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [String]
        $HostName,

        [Parameter(Mandatory = $true)]
        [String]
        $Path,
 
        [Parameter(Mandatory = $false)]
        [Hashtable]
        $QueryParameters
    )
 
    # Add System.Web
    Add-Type -AssemblyName System.Web
 
    # Create a http name value collection from an empty string
    $nvCollection = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
 
    foreach ($key in $QueryParameters.Keys)
    {
        $nvCollection.Add($key, $QueryParameters.$key)
    }
 
    # Build the uri
    $builder = New-Object System.UriBuilder -Property @{
    
        'host'=$HostName;
        'scheme'='https';
        'port'=443;
        'query'=$nvCollection.ToString();
        'path'=$Path
    }
 
    return $builder.Uri.OriginalString
}

########################################
# Computer Vision API Functions
########################################

# I did attempt to make this a pipeable function, but ran into endless loops I couldn't figure out
function Request-AnalyzeImage {
<#
        .SYNOPSIS
            
            Analyzes the content of an image, returning information about category, tags, description, and brands.

        .OUTPUTS

            Returns a PSCustomObject with the following properties:
            
        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); Request-AnalyzeImage -ImageBytes $imageBytes

    #>
    [CmdletBinding()]
    param 
    (
        # A byte array of the image. See example for how to retrieve image bytes.
        [Parameter(Mandatory = $true)]
        [Byte[]]$ImageBytes
    )

    # Retrieve settings from file
    $settings = Read-Settings

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'visualFeatures'='Brands,Categories,Description,Tags'
    }

    $uri = New-HttpRequestUri -HostName $settings.host -Path '/vision/v2.0/analyze' -QueryParameter $queryParams

    $response = curl `
    -Uri $uri `
    -Headers @{ "Content-Type"="application/octet-stream"; "Ocp-Apim-Subscription-Key"=$settings.key } `
    -Method POST `
    -UseBasicParsing `
    -Body $ImageBytes

    return $response
}

function Request-RecognizeText {
    <#
        .SYNOPSIS
            
            Reads text in an image, returning both the OCR'd text and it's location in the image

        .OUTPUTS

            Returns a PSCustomObject with the following properties:
            
        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); Request-RecognizeText -ImageBytes $imageBytes

    #>
    [CmdletBinding()]
    param 
    (
        # A byte array of the image. See example for how to retrieve image bytes.
        [Parameter(Mandatory = $true)]
        [Byte[]]$ImageBytes
    )

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'mode'='Printed'
    }

    $uri = New-HttpRequestUri -BaseUri $BASE_URI -Path '/vision/v2.0/recognizeText' -QueryParameter $queryParams

    $response = curl `
    -Uri $uri `
    -Headers @{ "Content-Type"="application/octet-stream"; "Ocp-Apim-Subscription-Key"="66f52ef9ac114042bee47b446019147a" } `
    -Method POST `
    -UseBasicParsing `
    -Body $ImageBytes

    if ($response.StatusCode -eq 202) {

        # Persists request retrieval Uri for later use (will disappear after first use otherwise)
        $resultRetrievalUri = $response.Headers.'Operation-Location'
    
        # Defines anonymous function to check that the request is complete
        $isRequestCompleteFunc = {
            begin { $complete = $true }
            process {
                if ($_.StatusCode -eq 200) {

                    $content = ConvertFrom-Json $_.Content

                    if ($content.status -and $content.status -eq 'NotStarted' -or $content.status -eq 'Running') {
                        $complete = $false
                    }
                }

                return $complete
            } 
        }

        # Keeps poll count to optimize wait time between requests
        $pollCount = 0

        do {

        $pollCount++

        # Pauses to allow the API time to process the request
        $waitInterval = 500
        Start-Sleep -Milliseconds $waitInterval

        # Retrieves the result of the API operation
        $response = curl `
        -Uri $resultRetrievalUri `
        -Headers @{ "Ocp-Apim-Subscription-Key"="66f52ef9ac114042bee47b446019147a" } `
        -Method GET `
        -UseBasicParsing

        $isComplete = $response | & $isRequestCompleteFunc

        } while (!$isComplete)
    }

    Write-Host ('The request was polled {0} times in {1}ms intervals' -f $pollCount, $waitInterval)
    return $response
}

function Request-TagImage {
    <#
        .SYNOPSIS
            
            Returns image tags, a subset of the analyize image functionality

        .OUTPUTS

            Returns a PSCustomObject with the following properties:
            
        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); Request-RecognizeText -ImageBytes $imageBytes

    #>
    [CmdletBinding()]
    param 
    (
        # A byte array of the image. See example for how to retrieve image bytes.
        [Parameter(Mandatory = $true)]
        [Byte[]]
        $ImageBytes
    )

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'language'='en'
    }

    $uri = New-HttpRequestUri -BaseUri $BASE_URI -Path '/vision/v2.0/tag' -QueryParameter $queryParams

    $response = curl `
    -Uri $uri `
    -Headers @{ "Content-Type"="application/octet-stream"; "Ocp-Apim-Subscription-Key"="66f52ef9ac114042bee47b446019147a" } `
    -Method POST `
    -UseBasicParsing `
    -Body $ImageBytes

    return $response
}

Export-ModuleMember -function Request-AnalyzeImage
Export-ModuleMember -function Request-RecognizeText
Export-ModuleMember -function Request-TagImage