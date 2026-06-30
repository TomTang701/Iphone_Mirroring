iPhone Mirroring installer payload

This self-extracting setup installs the app for the current Windows user under:
%LOCALAPPDATA%\iPhoneMirroring

It creates desktop and Start Menu shortcuts, registers a per-user uninstall entry,
and attempts to add a Windows Firewall allow rule for rpiplay.exe.

Bonjour is required for iPhone/iPad discovery. If Bonjour is missing, setup offers
to download Apple Bonjour Print Services from Apple's support download URL:
https://support.apple.com/en-us/106380
