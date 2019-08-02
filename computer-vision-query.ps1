########################################
# Constants
########################################
$BASE_URI = 'https://westcentralus.api.cognitive.microsoft.com/'

########################################
# Helper Functions
########################################

# Adds function to simplify the http request
function New-HttpRequestUri
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [String]
        $BaseUri,

        [Parameter(Mandatory = $true)]
        [String]
        $Path,
 
        [Parameter(Mandatory = $true)]
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
    $uriRequest = [System.UriBuilder]$BaseUri
    $uriRequest.Query = $nvCollection.ToString()
    $uriRequest.Path = $Path
 
    return $uriRequest.Uri.OriginalString
}

function Request-AnalyzeImage {
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [Byte[]]
        $ImageBytes
    )

    # Modify these to retrieve different information from the analysis
    $queryParams = @{
        'visualFeatures'='Brands,Categories,Description,Tags'
    }

    $uri = New-HttpRequestUri -BaseUri $BASE_URI -Path '/vision/v2.0/analyze' -QueryParameter $queryParams

    $response = curl `
    -Uri $uri `
    -Headers @{ "Content-Type"="application/octet-stream"; "Ocp-Apim-Subscription-Key"="66f52ef9ac114042bee47b446019147a" } `
    -Method POST `
    -UseBasicParsing `
    -Body $ImageBytes

    return $response
}

function Request-RecognizeText {
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [Byte[]]
        $ImageBytes
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

########################################
# Read image bytes and send request
########################################

$imagePath = [System.IO.Path]::Combine($env:OneDriveCommercial, 'Archive\2019\GroceryProject\Images\test-image-cereal.png')
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)

$response = Request-RecognizeText -ImageBytes $imageBytes

$result = $null
if ($response.StatusCode -eq 200)
{
    $result = ConvertFrom-Json -InputObject $response.Content
}

$result