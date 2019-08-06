Import-Module .\ComputerVisionModule -Force
$settings = gc settings.json | ConvertFrom-Json
$path = [System.IO.Path]::Combine($env:OneDriveCommercial, 'Working/Bench/Images/receipts/IMG_2360.jpg');
$bytes = [System.IO.File]::ReadAllBytes($path);

$response = Request-RecognizeText -ImageBytes $bytes -CVAPIKey $settings.key;
Sleep -Seconds 2
#$content = $response.Content | ConvertFrom-Json
#$content.recognitionResult | select -ExpandProperty lines

$titles = @()
$results.ForEach({ $x = $_.text; `
if ($_.boundingBox[0] -lt 910 -and $_.boundingBox[0] -gt 890) { $titles += $x } })

$amounts = @()
$results.ForEach({ $x = $_.text; `
if ($_.boundingBox[0] -lt 1755 -and $_.boundingBox[0] -gt 1735) { $amounts += $x } })


<#
$files.ForEach( {
    $path = [System.IO.Path]::Combine($env:OneDriveCommercial, 'Working/Bench/Images/groceries', $_.filename + '.jpg');
    $bytes = [System.IO.File]::ReadAllBytes($path);
    $response = Request-TagImage -ImageBytes $bytes -CVAPIKey $settings.key;
    sleep -Seconds 2;
    $content = $response.Content | ConvertFrom-Json;

    $_.filename >> results.txt;
    ($content.tags.Where({ $_.confidence -gt 0.75}) | select -ExpandProperty name) >> results.txt;
 } )
 #>