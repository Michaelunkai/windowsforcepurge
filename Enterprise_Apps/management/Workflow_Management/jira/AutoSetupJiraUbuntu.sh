#!/bin/bash

#================================================================
# Jira Software Installation Script with MariaDB
#
# This script automates the installation of Atlassian Jira
# and configures it with a MariaDB database. It runs the
# Jira installer in unattended mode to avoid interactive prompts.
#================================================================

# --- Configuration ---
# You can change these versions to download different ones.
JIRA_VERSION="9.12.0"
MARIADB_CONNECTOR_VERSION="2.7.4"
DB_PASSWORD="123456" # Change this to a secure password

# --- Script Start ---

# Exit immediately if a command exits with a non-zero status.
set -e

# --- User Confirmation ---
# Ask the user for confirmation before running.
# The script will proceed if the user presses Enter (default) or types 'ya'.
read -p "This will install Jira Software and MariaDB. Press ENTER or type 'ya' to continue: " user_confirmation

if [[ "$user_confirmation" != "" && "$user_confirmation" != "ya" ]]; then
    echo "Installation cancelled by user."
    exit 1
fi

# --- Step 1: Install MariaDB ---
echo ">>> Installing MariaDB server..."
sudo apt-get update
sudo apt-get install -y mariadb-server fontconfig # Pre-install fontconfig to be safe

# --- Step 2: Create Jira Database and User ---
echo ">>> Setting up MariaDB database 'jiradb' and user 'jirauser'..."
sudo mariadb -u root -e "
DROP DATABASE IF EXISTS jiradb;
CREATE DATABASE jiradb CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'jirauser'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON jiradb.* TO 'jirauser'@'localhost';
FLUSH PRIVILEGES;
"

# --- Step 3: Download Jira and Prepare for Unattended Install ---
echo ">>> Downloading Jira Software v${JIRA_VERSION}..."
cd ~
JIRA_INSTALLER_FILE="atlassian-jira-software-${JIRA_VERSION}-x64.bin"
wget "https://www.atlassian.com/software/jira/downloads/binary/${JIRA_INSTALLER_FILE}"

echo ">>> Making Jira installer executable..."
chmod a+x "${JIRA_INSTALLER_FILE}"

echo ">>> Creating response file for unattended Jira installation..."
# This file provides answers to the installer's questions.
# This avoids all interactive prompts.
cat > ~/response.varfile <<EOL
#install4j response file for Atlassian Jira Software
sys.adminRights$Boolean=true
sys.languageId=en
sys.installationDir=/opt/atlassian/jira
jira.home=/var/atlassian/application-data/jira
app.install.service$Boolean=true
port.number=8080
control.port=8005
execute.launch$Boolean=false
EOL

echo ">>> Running Jira installer in unattended mode..."
# The -q flag runs the installer in quiet mode.
# The -varfile flag specifies the file with the answers.
sudo "./${JIRA_INSTALLER_FILE}" -q -varfile ~/response.varfile

# --- Step 4: Install MariaDB JDBC Driver ---
echo ">>> Downloading MariaDB Connector/J v${MARIADB_CONNECTOR_VERSION}..."
CONNECTOR_JAR="mariadb-java-client-${MARIADB_CONNECTOR_VERSION}.jar"
wget "https://downloads.mariadb.com/Connectors/java/connector-java-${MARIADB_CONNECTOR_VERSION}/${CONNECTOR_JAR}"

echo ">>> Copying connector to Jira's library..."
# This path assumes a standard Jira installation directory.
sudo cp "${CONNECTOR_JAR}" /opt/atlassian/jira/lib/

# --- Step 5: Restart Jira ---
echo ">>> Restarting Jira service to apply changes..."
sudo /etc/init.d/jira stop
sudo /etc/init.d/jira start

# --- Step 6: Clean up and Finish ---
echo ">>> Cleaning up downloaded files..."
rm "${JIRA_INSTALLER_FILE}"
rm "${CONNECTOR_JAR}"
rm ~/response.varfile

echo ">>> Installation complete!"
echo ">>> Opening Jira in your default browser at http://localhost:8080"

# Opens the URL in the Chrome browser on Windows via PowerShell (for WSL).
# This command is based on the user's specific setup.
powershell.exe -Command "Start-Process -FilePath 'F:\backup\windowsapps\installed\Chrome\Application\chrome.exe' -ArgumentList 'http://localhost:8080'"

exit 0
