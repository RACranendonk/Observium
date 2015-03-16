# Observium
Observium installation script, follows the basic [Observium installation guide](http://www.observium.org/wiki/Debian_Ubuntu_Installation).

Please note that this script will add the `ondrej/php5-oldstable` repository, install several packages, overwrite any configurations you have in `/etc/apache2/sites-available/default`, create and modify an MySQL database, and add CRON jobs.

Refer to the code or the [Observium installation guide](http://www.observium.org/wiki/Debian_Ubuntu_Installation) to see what changes are made.

## Setup

Make the script executable by using `sudo chmod +x <script>`, and execute with `sudo ./<script>`
