<#
    Computer Vision API Script Module
    Author: Alex Bilson (alex.bilson@spr.com)
    Last Updated: 2-August-2019

    Description:

        This module simplifies the use of the Computer Vision API to analyze images.

    Setup:

        This script requires an Azure Cognitive Service account. Please supply the example values in a settings.json file in the same path as this script.

    Example:

        {
            'host': 'westcentralus.api.cognitive.microsoft.com',
            key: 'sfslkja;sldj;'
        }

        host: no forward slashes
        key: the subscription key given you by Microsoft when you register your account. MS supplies two keys; the first is fine
#>

########################################
# Helper Functions (not exported by module)
########################################

# Reads the settings from .\settings.json
function Read-Settings {
    
    $filename = 'settings.json'

    if ((Test-Path $filename) -eq $false) {
        return @{ success=$false; message='No settings.json file in this directory. Check help for this command for more information.'; settings=$null }
    }

    $settings = Get-Content -Path $filename -Raw | ConvertFrom-Json
    return @{ success=$true; message=[String]::Empty(); settings=$settings }
}

# Simplifies the http request generation
function New-HttpRequestUri {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]$HostName,

        [Parameter(Mandatory = $true)]
        [String]$Path,

        [Parameter(Mandatory = $false)]
        [Hashtable]$QueryParameters
    )
    Add-Type -AssemblyName System.Web

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

            Analyzes the content of an image using the Microsoft Computer Vision API. Returns information about category, tags, description, and brands.

        .OUTPUTS

            Returns a BasicHtmlWebResponseObject. If the request was successful (StatusCode == 200) then the Content will be a JSON string in the following format. The types are what the ConvertFrom-Json Cmdlet will deserialize into.

            categories <Object[]> {
                name <String>,
                score <Decimal>
                },
            tags <Object[]> {
                name <String>,
                confidence <Decimal>
                },
            brands <Object[]> {
                name <String>,
                confidence <Decimal>,
                rectangle <PSCustomObject> {
                  x <int>,
                  y <int>,
                  w <int>,
                  h <int>
                }
                },
            requestId <String>,
            metadata <PSCustomObject>: {
                width <Int>,
                height <Int>,
                format <String>
                }

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); Request-AnalyzeImage -ImageBytes $imageBytes

            This retrieves results from a single image and returns the response object to the console.

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); $response = Request-AnalyzeImage -ImageBytes $imageBytes; $content = ConvertFrom-Json $response.Content

            This retrieves results from a single image and stores them in a custom PowerShell object for further processing.

        .LINKS

            Request-RecognizeText
            Request-TagImage
            Request-GenerateThumbnail

    #>
    [CmdletBinding()]
    param
    (
        # A byte array of the image. See example for how to retrieve image bytes.
        [Parameter(Mandatory = $true)]
        [Byte[]]$ImageBytes
    )

    # Retrieve settings from file
    $result = Read-Settings

    if ($result.success -eq $false) { return $result.message }

    $settings = $result.settings

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'visualFeatures'='Brands,Categories,Description,Tags'
    }

    $uri = New-HttpRequestUri -HostName $settings.host -Path '/vision/v2.0/analyze' -QueryParameter $queryParams

    $response = Invoke-WebRequest `
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

            Returns a BasicHtmlWebResponseObject. If the request was successful (StatusCode == 200) then the Content will be a JSON string in the following format. The types are what the ConvertFrom-Json Cmdlet will deserialize into.

            status <String>,
            recognitionResult <PSCustomObject> {
              lines <Object[]> {
                boundingBox <Int[]>,
                text <String>,
                words <Object[] {
                  boundingBox <Int[]>,
                  text <String>,
                  confidence <String>
                }
              }
            }

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); Request-RecognizeText -ImageBytes $imageBytes

            This retrieves results from a single image and returns the response object to the console.

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); $response = Request-RecognizeText -ImageBytes $imageBytes; $content = ConvertFrom-Json $response.Content

            This retrieves results from a single image and stores them in a custom PowerShell object for further processing.

        .LINKS

            Request-AnalyzeImage
            Request-TagImage
            Request-GenerateThumbnail

    #>
    [CmdletBinding()]
    param
    (
        # A byte array of the image. See example for how to retrieve image bytes.
        [Parameter(Mandatory = $true)]
        [Byte[]]$ImageBytes
    )

    # Retrieve settings from file
    $result = Read-Settings

    if ($result.success -eq $false) { return $result.message }

    $settings = $result.settings

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'mode'='Printed'
    }

    $uri = New-HttpRequestUri -HostName $settings.host -Path '/vision/v2.0/recognizeText' -QueryParameter $queryParams

    $response = curl `
    -Uri $uri `
    -Headers @{ "Content-Type"="application/octet-stream"; "Ocp-Apim-Subscription-Key"=$settings.key } `
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

            Returns a BasicHtmlWebResponseObject. If the request was successful (StatusCode == 200) then the Content will be a JSON string in the following format. The types are what the ConvertFrom-Json Cmdlet will deserialize into.

            tags <Object[]> {
                name <String>,
                confidence <Decimal>
                },

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); Request-TagImage -ImageBytes $imageBytes

            This retrieves results from a single image and returns the response object to the console.

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); $response = Request-TagImage -ImageBytes $imageBytes; $content = ConvertFrom-Json $response.Content

            This retrieves results from a single image and stores them in a custom PowerShell object for further processing.

        .LINKS

            Request-AnalyzeImage
            Request-RecognizeText
            Request-GenerateThumbnail

    #>
    [CmdletBinding()]
    param
    (
        # A byte array of the image. See example for how to retrieve image bytes.
        [Parameter(Mandatory = $true)]
        [Byte[]]
        $ImageBytes
    )

    # Retrieve settings from file
    $result = Read-Settings

    if ($result.success -eq $false) { return $result.message }

    $settings = $result.settings

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'language'='en'
    }

    $uri = New-HttpRequestUri -HostName $settings.host -Path '/vision/v2.0/tag' -QueryParameter $queryParams

    $response = curl `
    -Uri $uri `
    -Headers @{ "Content-Type"="application/octet-stream"; "Ocp-Apim-Subscription-Key"=$settings.key } `
    -Method POST `
    -UseBasicParsing `
    -Body $ImageBytes

    return $response
}

function Request-GenerateThumbnail {
    <#
        .SYNOPSIS

            Returns a resized thumbnail of the image at 125x125 pixels with smart cropping.

        .OUTPUTS

            Returns a byte array.

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); Request-GenerateThumbnail -ImageBytes $imageBytes

            This retrieves results from a single image and returns a resized version of the same image as a byte array.

        .EXAMPLE

            $imageBytes = [System.IO.File]::ReadAllBytes('C:\User\myusername\Images\test-image.png'); $response = Request-GenerateThumbnail -ImageBytes $imageBytes; [System.IO.File]::WriteAllBytes(''C:\User\myusername\Images\thumbnail.png', $response.Content)

            This retrieves results from a single image and returns the resized version of the same image as a byte array, and saves the new image to the same folder as a thumbnail.

        .LINKS

            Request-AnalyzeImage
            Request-RecognizeText
            Request-TagImage

    #>
    [CmdletBinding()]
    param
    (
        # A byte array of the image. See example for how to retrieve image bytes.
        [Parameter(Mandatory = $true)]
        [Byte[]]
        $ImageBytes
    )

    # Retrieve settings from file
    $result = Read-Settings

    if ($result.success -eq $false) { return $result.message }

    $settings = $result.settings

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'width'=125;
        'height'=125;
        'smartCropping'='true'
    }

    $uri = New-HttpRequestUri -HostName $settings.host -Path '/vision/v2.0/generateThumbnail' -QueryParameter $queryParams

    $response = curl `
    -Uri $uri `
    -Headers @{ "Content-Type"="application/octet-stream"; "Ocp-Apim-Subscription-Key"=$settings.key } `
    -Method POST `
    -UseBasicParsing `
    -Body $ImageBytes

    return $response
}

Export-ModuleMember -function Request-AnalyzeImage
Export-ModuleMember -function Request-RecognizeText
Export-ModuleMember -function Request-TagImage
Export-ModuleMember -function Request-GenerateThumbnail
