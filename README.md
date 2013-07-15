play-tools
============

Tools and scripts for managing and deploying play projects.

bin/play-deploy
-----------------

Deploy strategy from dev to prod that automates the entire process. Features include:

 * Only syncs jars that have changed
 * Retains previous versions on prod
 * Better run/start/stop scripts
 * Prompts for restart of prod app
