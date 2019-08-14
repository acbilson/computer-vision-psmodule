$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$module = 'ComputerVisionModule'

Import-Module ([System.IO.Path]::Combine($here, $module + '.psm1')) -Force

$imagePath = [System.IO.Path]::Combine($here, '.\Images\test-image-sauce.png')
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)

Describe -Tags ('Unit') "$module Module Tests"  {

    Context 'Module Setup' {

        $cmds = Get-Module ComputerVisionModule | Select -ExpandProperty ExportedCommands

        It 'has exported commands' {
            $cmds.ContainsKey('Request-AnalyzeImage') | Should -BeTrue
            $cmds.ContainsKey('Request-GenerateThumbnail') | Should -BeTrue
            $cmds.ContainsKey('Request-RecognizeText') | Should -BeTrue
            $cmds.ContainsKey('Request-TagImage') | Should -BeTrue
        }

        It 'does not have private commands' {
            $cmds.ContainsKey('Read-Settings') | Should -BeFalse
            $cmds.ContainsKey('New-HttpRequestUri') | Should -BeFalse
        }
    }

    Context 'Request-AnalyzeImage Golden Tests' {

        It 'returns success status code' {

            Mock -CommandName Invoke-WebRequest -MockWith {
                return @{
                    Content = @{
                        requestId = 1
                        categories = ''
                        brands = ''
                        metadata = ''
                        }
                    StatusCode = 200
                }
            } `
                 -ModuleName $module

            Mock -CommandName Read-Settings -MockWith {
                return @{
                    success = $true
                    message = ''
                    settings = @{
                        host = 'localhost'
                        key = 'mytestkey'
                    }
                }
            } `
                 -ModuleName $module
            
            $response = Request-AnalyzeImage -ImageBytes $imageBytes
            $response.StatusCode | Should -BeTrue
        } 
    }
    Context 'Request-AnalyzeImage Settings Tests' {

        It 'returns settings failure message' {

            Mock -CommandName Read-Settings -MockWith {
                return @{
                    success = $false
                    message = 'failure message'
                    settings = $null
                }
            } `
                 -ModuleName $module
            
            $response = Request-AnalyzeImage -ImageBytes $imageBytes
            $response | Should -Be 'failure message'
        } 

    }

}