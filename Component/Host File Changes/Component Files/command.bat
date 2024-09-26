#HOSTS monitor :: build 1/seagull :: original code by mat s., datto labs :: Changed to hash comparison by Oliver Perring 
 
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hashFilePath = "$env:TEMP\hostsfilehash.txt" # Temporary storage for the last hash

# Get the current hash of the hosts file
$currentHash = Get-FileHash -Path $hostsPath -Algorithm SHA256

# Check if the hash file exists
if (Test-Path $hashFilePath) {
    $lastHash = Get-Content $hashFilePath
    # Compare the current hash with the last saved hash
    if ($currentHash.Hash -ne $lastHash) {
        # File contents have changed
        write-host '<-Start Result->'
        write-host "X=HOSTS modified within the last 24 hours. Last modification @ $((Get-ItemProperty -Path $hostsPath -Name LastWriteTime).LastWriteTime)"
        write-host '<-End Result->'
        # Save the new hash for future comparisons
        $currentHash.Hash | Out-File -FilePath $hashFilePath -Force
        Exit 1
    } else {
        # File contents have not changed
        write-host '<-Start Result->'
        write-host "X=HOSTS not modified since $((Get-ItemProperty -Path $hostsPath -Name LastWriteTime).LastWriteTime)"
        write-host '<-End Result->'
        Exit 0
    }
} else {
    # First run - store the hash and indicate no modification
    write-host '<-Start Result->'
    write-host "X=First run. Storing initial hash of the hosts file."
    write-host '<-End Result->'
    # Save the initial hash for future comparisons
    $currentHash.Hash | Out-File -FilePath $hashFilePath -Force
    Exit 0
}
