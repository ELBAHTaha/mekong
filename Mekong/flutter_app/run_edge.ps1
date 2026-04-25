# Lancer l'app sur Edge avec les mêmes options que .vscode/settings.json
# (réduit les erreurs WipError / AppInspector liées au widget inspector).
Set-Location $PSScriptRoot
& "D:\profesDocs\Mekong\tools\flutter\bin\flutter.bat" run -d edge --no-track-widget-creation
