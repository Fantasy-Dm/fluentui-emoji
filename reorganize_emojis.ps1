# Reorganize emoji files script
# Organize by style and rename by unicode
# Handle both simple and skintone variants

param(
	[int]$Limit = 10
)

$assetsPath = "assets"
$outputPath = "output"

if (-not (Test-Path $outputPath)) {
	New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

$metadataOutputPath = Join-Path $outputPath "metadata"
if (-not (Test-Path $metadataOutputPath)) {
	New-Item -ItemType Directory -Path $metadataOutputPath -Force | Out-Null
}

$emojiDirs = Get-ChildItem -Path $assetsPath -Directory | Select-Object -First $Limit

$processedCount = 0
$errorCount = 0

# Function to process style directories and copy files
function Process-StyleDirectory {
	param(
		[string]$styleDirPath,
		[string]$styleName,
		[string]$unicode,
		[string]$skintoneVariant = ""
	)

	$styleOutputPath = Join-Path $outputPath $styleName
	if (-not (Test-Path $styleOutputPath)) {
		New-Item -ItemType Directory -Path $styleOutputPath -Force | Out-Null
	}

	$files = Get-ChildItem -Path $styleDirPath -File

	foreach ($file in $files) {
		$extension = $file.Extension
		if ([string]::IsNullOrEmpty($skintoneVariant)) {
			$newFileName = "$unicode$extension"
		} elseif ($skintoneVariant -eq "Default") {
			# Default skintone doesn't need suffix
			$newFileName = "$unicode$extension"
		} else {
			$newFileName = "${unicode}_${skintoneVariant}${extension}"
		}
		$destPath = Join-Path $styleOutputPath $newFileName

		Copy-Item -Path $file.FullName -Destination $destPath -Force
		Write-Host "  Copied: $($file.Name) -> $styleName/$newFileName"
	}
}

foreach ($emojiDir in $emojiDirs) {
	try {
		$metadataPath = Join-Path $emojiDir.FullName "metadata.json"

		if (-not (Test-Path $metadataPath)) {
			Write-Warning "Skip $($emojiDir.Name): no metadata.json"
			continue
		}

		$metadata = Get-Content $metadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
		$unicode = $metadata.unicode

		if ([string]::IsNullOrEmpty($unicode)) {
			Write-Warning "Skip $($emojiDir.Name): no unicode"
			continue
		}

		$unicode = $unicode -replace '\s+', '-'

		# Remove variant selectors (fe0f, fe0e) for cleaner filenames
		$unicode = $unicode -replace '-fe0[ef]', ''

		Write-Host "Processing: $($emojiDir.Name) -> Unicode: $unicode"

		# Check if this emoji has skintone variants
		$hasSkintones = $metadata.PSObject.Properties.Name -contains "unicodeSkintones"

		if ($hasSkintones) {
			# This emoji has skintone variants (e.g., Default, Light, Dark, etc.)
			$skintoneDirs = Get-ChildItem -Path $emojiDir.FullName -Directory

			foreach ($skintoneDir in $skintoneDirs) {
				$skintoneName = $skintoneDir.Name

				# Check if this skintone directory contains style subdirectories
				$styleDirs = Get-ChildItem -Path $skintoneDir.FullName -Directory

				foreach ($styleDir in $styleDirs) {
					$styleName = $styleDir.Name
					Process-StyleDirectory -styleDirPath $styleDir.FullName -styleName $styleName -unicode $unicode -skintoneVariant $skintoneName
				}
			}
		} else {
			# Regular emoji without skintone variants
			$styleDirs = Get-ChildItem -Path $emojiDir.FullName -Directory

			foreach ($styleDir in $styleDirs) {
				$styleName = $styleDir.Name
				Process-StyleDirectory -styleDirPath $styleDir.FullName -styleName $styleName -unicode $unicode
			}
		}

		# Copy metadata.json
		if (-not (Test-Path $metadataOutputPath)) {
			New-Item -ItemType Directory -Path $metadataOutputPath -Force | Out-Null
		}
		$metadataDestPath = Join-Path $metadataOutputPath "$unicode.json"
		Copy-Item -Path $metadataPath -Destination $metadataDestPath -Force

		$processedCount++

	} catch {
		Write-Error "Error processing $($emojiDir.Name): $_"
		$errorCount++
	}
}

Write-Host "`n====== Complete ======"
Write-Host "Success: $processedCount emojis"
Write-Host "Failed: $errorCount"
Write-Host "Output: $outputPath"
