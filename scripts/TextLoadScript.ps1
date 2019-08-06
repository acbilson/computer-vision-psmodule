Import-Module .\ComputerVisionModule -Force
$settings = gc settings.json | ConvertFrom-Json
$files = ipcsv files.csv

$i = 6
$path = [System.IO.Path]::Combine($env:OneDriveCommercial, 'Working/Bench/Images/groceries', $files[$i].filename + '.jpg');
$bytes = [System.IO.File]::ReadAllBytes($path);
$response = Request-RecognizeText -ImageBytes $bytes -CVAPIKey $settings.key;
Sleep -Seconds 2
$content = $response.Content | ConvertFrom-Json
$content.recognitionResult | select -ExpandProperty lines

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