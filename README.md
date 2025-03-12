# ArchiSteamFarm Docker Setup

A comprehensive setup script for [ArchiSteamFarm](https://github.com/JustArchiNET/ArchiSteamFarm) with Docker, including automatic web interface configuration and easy Steam authentication handling.

## Features

- **Easy Installation**: Complete Docker-based setup with a single script
- **Web Interface**: Configures secure HTTPS access to ASF's web interface
- **Choice of Web Server**: Support for both Apache2 and Nginx
- **Steam Authentication Helpers**: Scripts to simplify handling Steam Guard codes
- **SDA .maFile Import**: Easy import from Steam Desktop Authenticator
- **German Language Support**: Interface in German by default
- **European Timezone**: Configured for Europe/Berlin timezone
- **Environment-based Configuration**: Uses .env file for easy customization
- **Host Network Mode**: Reliable networking configuration to prevent connectivity issues

## Prerequisites

- Ubuntu 22.04 (or compatible Linux distribution)
- sudo/root access
- Domain name pointed to your server IP (for HTTPS setup)
- SSL certificates for your domain (stored at `/etc/ssl/cert.pem` and `/etc/ssl/key.pem`)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/asf-docker-setup.git
   cd asf-docker-setup
   ```

2. Make the installation script executable:
   ```bash
   chmod +x asf-install.sh
   ```

3. Run the installation script:
   ```bash
   sudo ./asf-install.sh
   ```

4. Edit the .env file created during installation to customize your settings:
   ```bash
   sudo nano /opt/asf/.env
   ```

5. Run the script again to apply your configuration:
   ```bash
   sudo ./asf-install.sh
   ```

## Configuration

The script creates a .env file at `/opt/asf/.env` with the following options:

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| MAIN_DOMAIN | Your main domain name | example.com |
| ASF_SUBDOMAIN | Subdomain for ASF | asf |
| ASF_IPC_PASSWORD | Password for web interface | (randomly generated) |
| ASF_CRYPT_KEY | Encryption key for ASF | (randomly generated) |
| WEB_SERVER | Web server to use | apache2 or nginx |
| ASF_RESTART_POLICY | Docker restart policy | unless-stopped |
| ASF_PORT | Port for ASF service | 1242 |
| TZ | Timezone | Europe/Berlin |

## Usage

### Web Interface

Access the ASF web interface at: `https://[ASF_SUBDOMAIN].[MAIN_DOMAIN]/`

Login with the password specified in your .env file.

### Adding Steam Accounts

1. Access the web interface
2. Go to Bot Management
3. Click "Add new bot"
4. Enter your Steam account details

### Using Steam Desktop Authenticator .maFile

To import an existing .maFile:

```bash
sudo bash /opt/asf/asf-import-mafile-fixed.sh
```

Follow the prompts to import your .maFile.

### Handling Steam Guard Codes

If you need to enter Steam Guard codes, you can:

1. Use the authentication helper script:
   ```bash
   sudo bash /opt/asf/asf-auth-helper.sh
   ```

2. Or manually enter codes in the web interface command line:
   ```
   2fa BotName YourCode
   ```

## Troubleshooting

### Authentication Issues

If you're having trouble with authentication:

1. Make sure ASF is configured in non-headless mode:
   - Check that `"Headless": false` is set in ASF.json

2. Try using the authentication helper:
   ```bash
   sudo bash /opt/asf/asf-auth-helper.sh
   ```

3. Check Docker logs:
   ```bash
   docker logs asf
   ```

### Connection Issues

If you can't access the web interface:

1. Verify your web server is running:
   ```bash
   sudo systemctl status apache2
   # or
   sudo systemctl status nginx
   ```

2. Check your firewall settings:
   ```bash
   sudo ufw status
   ```

3. Ensure ports 80 and 443 are open on your server

## Notes

- The script disables automatic joining of the ArchiASF Steam group
- Configurations are stored in `/opt/asf/config/`
- Log files can be accessed with `docker logs asf`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [JustArchiNET](https://github.com/JustArchiNET) for creating ArchiSteamFarm
- The Docker and containerization community
- All contributors to this script

## Disclaimer

This script is not officially affiliated with ArchiSteamFarm or Valve Corporation. Use at your own risk and always ensure you comply with Steam's Terms of Service.