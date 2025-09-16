gci 'F:\Downloads' -File |
  ? { $_.Extension -match '^(?i)\.(exe|msi)$' } |                         # keep only .exe / .msi
  % {
      # ── clean base name so the folder is just the tool name ──────────
      $tool = ($_.BaseName -replace '(?i)([-_ ]?(setup|installer|install|v?\d+(\.\d+)*|x64|x86|amd64|win64|win32)).*$','').Trim()
      if (-not $tool) { $tool = $_.BaseName }

      # ── create the dedicated install folder (if missing) ─────────────
      $dest = "F:\backup\windowsapps\installed\$tool"
      if (-not (Test-Path $dest)) { mkdir $dest -EA 0 | Out-Null }

      # ── run the installer silently into that folder ──────────────────
      if     ($_.Extension -ieq '.msi') {
          Start-Process 'msiexec.exe' -ArgumentList "/i `"$($_.FullName)`" /qn /norestart INSTALLDIR=`"$dest`"" -Wait
      }
      elseif ($_.Extension -ieq '.exe') {
          Start-Process $_.FullName  -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$dest`"" -Wait
      }
  }

