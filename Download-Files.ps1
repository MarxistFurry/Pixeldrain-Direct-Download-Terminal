<#
.SYNOPSIS
Downloads files from a list of Pixeldrain URLs.

.DESCRIPTION
This script takes an array of Pixeldrain URLs, extracts the file ID,
and attempts to download the corresponding file, saving it locally
with its original filename.

.PARAMETER UrlList
An array of strings representing the Pixeldrain sharing URLs (e.g., https://pixeldrain.com/u/...).

.EXAMPLE
.\Download-Files.ps1 -UrlList "https://pixeldrain.com/u/SLUG1", "https://pixeldrain.com/u/SLUG2", "https://pixeldrain.com/u/SLUG3"
#>
param(
    [Parameter(Mandatory=$true)]
    [string[]]$UrlList
)

foreach ($url in $UrlList) {
    try {
        Write-Host "`nProcessing $url ..."

        # 1. Get the page content and extract the file ID using regex
        $content = (Invoke-WebRequest $url).Content
        $fileIdMatch = [regex]::Match($content,'/u/([A-Za-z0-9-_]+)')
        
        if (-not $fileIdMatch.Success) {
            Write-Warning "Failed to extract file ID from $url. Skipping."
            continue
        }

        $fileId = $fileIdMatch.Groups[1].Value
        $apiUrl = "https://pixeldrain.com/api/file/$fileId"

        # 2. Invoke API URL (with MaximumRedirection 0 to get headers without downloading)
        # Note: -ErrorAction SilentlyContinue is used to handle the expected 302 redirect as a non-fatal error
        $resp = Invoke-WebRequest $apiUrl -MaximumRedirection 0 -ErrorAction SilentlyContinue

        # 3. Extract the filename from the Content-Disposition header
        $contentDisposition = $resp.Headers.'Content-Disposition'
        $filename = ($contentDisposition -replace '.*filename="(.+)".*','$1')

        # 4. Sanitize the filename for use in the local file system
        $sanitizedFilename = ($filename -replace '[<>:"/\\|?*]', '_').Trim()

        # 5. Download the file content (this is the actual download command)
        $downloadResp = Invoke-WebRequest $apiUrl -MaximumRedirection 5
        
        # 6. Write the bytes to the file
        [System.IO.File]::WriteAllBytes($sanitizedFilename, $downloadResp.Content)

        Write-Host "Downloaded: $sanitizedFilename"
    }
    catch {
        Write-Warning ("Failed to download from " + $url + ": " + $_.Exception.Message)
    }
}