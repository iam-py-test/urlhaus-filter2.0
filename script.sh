#!/bin/sh

set -efux -o pipefail

## Create a temporary working folder
mkdir -p "tmp/"
cd "tmp/"


## Prepare datasets
curl -L "https://urlhaus.abuse.ch/downloads/csv/" -o "urlhaus.zip"
curl -L "https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip" -o "top-1m-umbrella.zip"
curl -L "https://tranco-list.eu/top-1m.csv.zip" -o "top-1m-tranco.zip"

cp "../src/exclude.txt" "."

## Prepare URLhaus.csv
unzip -p "urlhaus.zip" | \
# Convert DOS to Unix line ending
dos2unix | \
# Remove comment
sed "/^#/d" > "URLhaus.csv"

## Parse URLs
cat "URLhaus.csv" | \
cut -f 6 -d '"' | \
cut -f 3- -d "/" | \
# Domain must have at least a 'dot'
grep -F "." | \
# Remove www.
sed "s/^www\.//g" | \
sort -u > "urlhaus.txt"

## Parse domain and IP address only
cat "urlhaus.txt" | \
cut -f 1 -d "/" | \
cut -f 1 -d ":" | \
# Remove invalid domains, see #15
grep -vF "??" | \
cut -f 1 -d "?" | \
sort -u > "urlhaus-domains.txt"

## Parse online URLs only
cat "URLhaus.csv" | \
grep '"online"' | \
cut -f 6 -d '"' | \
cut -f 3- -d "/" | \
sed "s/^www\.//g" | \
sort -u > "urlhaus-online.txt"

cat "urlhaus-online.txt" | \
cut -f 1 -d "/" | \
cut -f 1 -d ":" | \
grep -vF "??" | \
cut -f 1 -d "?" | \
sort -u > "urlhaus-domains-online.txt"


## Parse the Umbrella 1 Million
unzip -p "top-1m-umbrella.zip" | \
dos2unix | \
# Parse domains only
cut -f 2 -d "," | \
grep -F "." | \
# Remove www.
sed "s/^www\.//g" | \
sort -u > "top-1m-umbrella.txt"

## Parse the Tranco 1 Million
unzip -p "top-1m-tranco.zip" | \
dos2unix | \
# Parse domains only
cut -f 2 -d "," | \
grep -F "." | \
# Remove www.
sed "s/^www\.//g" | \
sort -u > "top-1m-tranco.txt"

# Merge Umbrella and self-maintained top domains
cat "top-1m-umbrella.txt" "top-1m-tranco.txt" "exclude.txt" | \
sort -u > "top-1m-well-known.txt"


## Parse popular domains from URLhaus
cat "urlhaus-domains.txt" | \
# grep match whole line
grep -Fx -f "top-1m-well-known.txt" > "urlhaus-top-domains.txt"


## Parse domains from URLhaus excluding popular domains
cat "urlhaus-domains.txt" | \
grep -F -vf "urlhaus-top-domains.txt" > "malware-domains.txt"

cat "urlhaus-domains-online.txt" | \
grep -F -vf "urlhaus-top-domains.txt" > "malware-domains-online.txt"

## Parse malware URLs from popular domains
cat "urlhaus.txt" | \
grep -F -f "urlhaus-top-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-url-top-domains.txt"

cat "urlhaus-online.txt" | \
grep -F -f "urlhaus-top-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-url-top-domains-online.txt"


## Merge malware domains and URLs
CURRENT_TIME="$(date -R -u)"
FIRST_LINE="! Title: Malicious URL Blocklist"
SECOND_LINE="! Updated: $CURRENT_TIME"
THIRD_LINE="! Expires: 1 day (update frequency)"
FOURTH_LINE="! Repo: https://gitlab.com/curben/urlhaus-filter"
FIFTH_LINE="! License: https://creativecommons.org/publicdomain/zero/1.0/"
SIXTH_LINE="! Source: https://urlhaus.abuse.ch/api/"
COMMENT_ABP="$FIRST_LINE\n$SECOND_LINE\n$THIRD_LINE\n$FOURTH_LINE\n$FIFTH_LINE\n$SIXTH_LINE"

# Adguard Home (#19, #22)
cat "malware-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/^/g" > "malware-domains-adguard-home.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/g" | \
sed "s/$/^/g" > "malware-domains-online-adguard-home.txt"

cat "malware-domains-adguard-home.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Blocklist/Blocklist (AdGuard Home)/" > "../urlhaus-filter-agh.txt"

cat "malware-domains-online-adguard-home.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (AdGuard Home)/" > "../urlhaus-filter-agh-online.txt"

cat "malware-domains-adguard-home.txt" "malware-url-top-domains.txt" | \
sort | \
sed '1 i\'"\n! BREAKING CHANGE (1 Oct 2020): AdGuard Home should use this blocklist https://gitlab.com/curben/urlhaus-filter#domain-based-adguard-home\n"'' | \
sed '1 i\'"$COMMENT_ABP"'' > "../urlhaus-filter.txt"

cat "malware-domains-online-adguard-home.txt" "malware-url-top-domains-online.txt" | \
sort | \
sed '1 i\'"\n! BREAKING CHANGE (1 Oct 2020): AdGuard Home should use this blocklist https://gitlab.com/curben/urlhaus-filter#domain-based-adguard-home\n"'' | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" > "../urlhaus-filter-online.txt"


# Adguard browser extension
cat "malware-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-domains-adguard.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$all/g" > "malware-domains-online-adguard.txt"

cat "malware-domains-adguard.txt" "malware-url-top-domains.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Blocklist/Blocklist (AdGuard)/" > "../urlhaus-filter-ag.txt"

cat "malware-domains-online-adguard.txt" "malware-url-top-domains-online.txt" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (AdGuard)/" > "../urlhaus-filter-ag-online.txt"


# Vivaldi
cat "malware-domains.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$document/g" > "malware-domains-vivaldi.txt"

cat "malware-domains-online.txt" | \
sed "s/^/||/g" | \
sed "s/$/\$document/g" > "malware-domains-online-vivaldi.txt"

cat "malware-domains-vivaldi.txt" "malware-url-top-domains.txt" | \
sed "s/\$all$/\$document/g" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Blocklist/Blocklist (Vivaldi)/" > "../urlhaus-filter-vivaldi.txt"

cat "malware-domains-online-vivaldi.txt" "malware-url-top-domains-online.txt" | \
sed "s/\$all$/\$document/g" | \
sort | \
sed '1 i\'"$COMMENT_ABP"'' | \
sed "1s/Malicious/Online Malicious/" | \
sed "1s/Blocklist/Blocklist (Vivaldi)/" > "../urlhaus-filter-vivaldi-online.txt"


## Domains-only blocklist
# awk + head is a workaround for sed prepend
COMMENT=$(printf "$COMMENT_ABP" | sed "s/^!/#/g" | sed "1s/URL/Domains/" | awk '{printf "%s\\n", $0}' | head -c -2)
COMMENT_ONLINE=$(printf "$COMMENT" | sed "1s/Malicious/Online Malicious/" | awk '{printf "%s\\n", $0}' | head -c -2)

cat "malware-domains.txt" | \
sort | \
sed '1 i\'"$COMMENT"'' > "../urlhaus-filter-domains.txt"

cat "malware-domains-online.txt" | \
sort | \
sed '1 i\'"$COMMENT_ONLINE"'' > "../urlhaus-filter-domains-online.txt"


## Hosts file blocklist
cat "../urlhaus-filter-domains.txt" | \
# Exclude comment with #
grep -vE "^#" | \
# Remove IPv4 address
grep -vE "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | \
sed "s/^/0.0.0.0 /g" | \
# Re-insert comment
sed '1 i\'"$COMMENT"'' | \
sed "1s/Domains/Hosts/" > "../urlhaus-filter-hosts.txt"

cat "../urlhaus-filter-domains-online.txt" | \
grep -vE "^#" | \
grep -vE "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | \
sed "s/^/0.0.0.0 /g" | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Domains/Hosts/" > "../urlhaus-filter-hosts-online.txt"


## Dnsmasq-compatible blocklist
cat "../urlhaus-filter-hosts.txt" | \
grep -vE "^#" | \
sed "s/^0.0.0.0 /address=\//g" | \
sed "s/$/\/0.0.0.0/g" | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Blocklist/dnsmasq Blocklist/" > "../urlhaus-filter-dnsmasq.conf"

cat "../urlhaus-filter-hosts-online.txt" | \
grep -vE "^#" | \
sed "s/^0.0.0.0 /address=\//g" | \
sed "s/$/\/0.0.0.0/g" | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Blocklist/dnsmasq Blocklist/" > "../urlhaus-filter-dnsmasq-online.conf"


## BIND-compatible blocklist
cat "../urlhaus-filter-hosts.txt" | \
grep -vE "^#" | \
sed 's/^0.0.0.0 /zone "/g' | \
sed 's/$/" { type master; notify no; file "null.zone.file"; };/g' | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Blocklist/BIND Blocklist/" > "../urlhaus-filter-bind.conf"

cat "../urlhaus-filter-hosts-online.txt" | \
grep -vE "^#" | \
sed 's/^0.0.0.0 /zone "/g' | \
sed 's/$/" { type master; notify no; file "null.zone.file"; };/g' | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Blocklist/BIND Blocklist/" > "../urlhaus-filter-bind-online.conf"


## Unbound-compatible blocklist
cat "../urlhaus-filter-hosts.txt" | \
grep -vE "^#" | \
sed 's/^0.0.0.0 /local-zone: "/g' | \
sed 's/$/" always_nxdomain/g' | \
sed '1 i\'"$COMMENT"'' | \
sed "1s/Blocklist/Unbound Blocklist/" > "../urlhaus-filter-unbound.conf"

cat "../urlhaus-filter-hosts-online.txt" | \
grep -vE "^#" | \
sed 's/^0.0.0.0 /local-zone: "/g' | \
sed 's/$/" always_nxdomain/g' | \
sed '1 i\'"$COMMENT_ONLINE"'' | \
sed "1s/Blocklist/Unbound Blocklist/" > "../urlhaus-filter-unbound-online.conf"


## Clean up artifacts
rm "URLhaus.csv" "top-1m-umbrella.zip" "top-1m-umbrella.txt" "top-1m-tranco.txt"


cd ../
