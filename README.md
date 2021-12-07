# MarktplaatsNotificaties
PHP script that keeps an eye on one or more search queries and sends a Pushover notification when a new item is found.

<p align='center'>
<img src='https://media.giphy.com/media/wBFVJylsveDVdGOOo2/giphy.gif'>
</p>

## Requirements
- PHP (tested on 7.3)
- Pushover (push notification service)
- A server running a job scheduler (cron)

## Install
```
$ git clone http://github.com/n-brunninkhuis/MarktplaatsNotificaties.git
$ cd MarktplaatsNotificaties
$ chmod +x mp
```

Edit the ```$settings[]``` array.

## Usage

#### Add Marktplaats search URL
```
$ mp -a "https://www.marktplaats.nl/l/fietsen-en-brommers/fietsen-mountainbikes-en-atb/f/zo-goed-als-nieuw/31/#q:fully+xl|f:32|postcode:5041AK|searchInTitleAndDescription:true"
```

#### List queries
```
$ mp -l
[0]	Fietsen | Mountainbikes en ATB • "scott spark xl"
[1]	Fietsen | Mountainbikes en ATB • "scott scale xl"
```

#### Delete query
```
$ mp -d 0
```

#### Find new items and send to pushover
```
$ mp -p
```

#### Perform a search every 5 minutes (crontab)
```
*/5 * * * * /home/niek/bin/mp -p
```
