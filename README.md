# Observium
Observium installation script, follows the [Observium installation guide](http://www.observium.org/wiki/Debian_Ubuntu_Installation).

Please note that this script will install several packages, overwrite any configurations you have in `/etc/apache2/sites-available/000-default.conf`, create and modify an MySQL database, and add CRON jobs for Observium.

Refer to the code or the [Observium installation guide](http://www.observium.org/wiki/Debian_Ubuntu_Installation) to see what changes are made.

## Setup

Make the script executable by using `sudo chmod +x <script>`, and execute with `sudo ./<script>`

## Troubleshooting

Error messages are stored in `/var/log/observium_errors.log`.

Script output is stored in `/var/log/observium_script.log`.
