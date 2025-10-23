Write-Host ""
Write-Host "Creating dummy files..."
Write-Host ""
$files="I:/"
$i=1
while ($i -le 6000) {
add-content -path $files$i.txt -value "blah blah blah"
$i++
}
Write-Host ""
Write-Host "--- Process complete ---"
Write-Host ""
Write-Host ""
$dummy = Read-Host "Press any key to close window..."