# Webdock CLI Tutorial

This tutorial will guide you through the process of setting up and using the Webdock CLI to manage your Webdock resources from the command line.

## Step 1: Prerequisites - Get your API Token

Before you can use the Webdock CLI, you need a Webdock API Token.

1.  Log in to your Webdock account.
2.  Navigate to the **API Tokens** section in your dashboard.
3.  Generate a new API token.
4.  Copy the token and save it in a safe place. You will need it to initialize the CLI.

## Step 2: Installation

### Linux

Open your terminal and run the following command to install the Webdock CLI:

```bash
curl -fsSL 'https://cli-src.webdock.tech/install/linux.sh' | sudo bash
```

### Windows (PowerShell)

Open a PowerShell terminal with administrator privileges and run the following command:

```powershell
irm 'https://cli-src.webdock.tech/install/windows.ps1' | iex
```

## Step 3: Initialize the CLI

After the installation is complete, you need to initialize the CLI with your API token.

Run the following command, replacing `<token>` with the API token you obtained in Step 1:

```bash
webdock init -t <token>
```

## Step 4: Basic Usage

Now that the CLI is initialized, you can start managing your Webdock resources.

### Get Account Information

To get information about your account, run:

```bash
webdock account info
```

### List Your Servers

To see a list of all your servers, run:

```bash
webdock servers list
```

### Get Server Details

To get detailed information about a specific server, you need the server's slug. You can get the slug from the `webdock servers list` command.

```bash
webdock servers get <server-slug>
```

### Create a Server

To create a new server, you need to specify the server name, location, and profile.

```bash
webdock servers create "My New Server" "helsinki" "nano"
```

You can find the available locations and profiles using the `webdock locations list` and `webdock profiles list <locationId>` commands.

### Delete a Server

To delete a server, run the following command, replacing `<server-slug>` with the slug of the server you want to delete:

```bash
webdock servers delete <server-slug>
```

## Further Exploration

The Webdock CLI has many more commands and options available. You can explore them by using the `--help` flag with any command.

For example, to see all the available commands for managing servers, run:

```bash
webdock servers --help
```

For more detailed information, you can always refer to the [official documentation](https://github.com/webdock-io/webdock-cli/blob/main/README.md).
