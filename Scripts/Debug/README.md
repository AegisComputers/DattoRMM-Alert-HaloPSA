# Debug Scripts

This folder contains debugging and testing scripts for the DattoRMM-Alert-HaloPSA project.

## Scripts

- `test_regex.ps1` - Tests regex patterns for alert parsing
- `test_exports.ps1` - Tests module function exports
- `test_consolidation_debug.ps1` - Tests alert consolidation logic
- `debug_halo_status.ps1` - Debugs Halo API status responses
- `check_halo_params.ps1` - Validates Halo API parameters

## Usage

These scripts are for development and troubleshooting purposes only. Do not deploy to production.

## Running Scripts

```powershell
# From the project root
.\Scripts\Debug\test_regex.ps1
.\Scripts\Debug\debug_halo_status.ps1
```
