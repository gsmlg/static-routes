#!/usr/bin/env ruby
#
# create route file
# ip-up ip-down
#

exit if ENV["OS"].nil?

require "fileutils"
require "csv"

ostype = ENV["OS"]

names = CSV.read("name.csv")

cn = names.find do |r|
    r[4] == "CN" 
end

cnCode = cn[0]

data = CSV.read("data.csv")
routes = []
cnRoutes = []

data.slice(1, data.length).each do |r|
    if r.include?(cnCode)
        cnRoutes << r[0]
    else
        routes << r[0]
    end
end

FileUtils.rm_rf("mode1")
FileUtils.mkdir("mode1")

ppp_head=<<-EOF
#!/bin/sh
# The  environment is cleared before executing this script
# so the path must be reset
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin
export PATH

# This script is called with the following arguments:
#    Arg  Name                          Example
#    $1   Interface name                ppp0
#    $2   The tty                       ttyS1
#    $3   The link speed                38400
#    $4   Local IP number               12.34.56.78
#    $5   Peer  IP number               12.34.56.99
#    $6   Optional ``ipparam'' value    foo

# These variables are for the use of the scripts run by run-parts
PPP_IFACE="$1"
PPP_TTY="$2"
PPP_SPEED="$3"
PPP_LOCAL="$4"
PPP_REMOTE="$5"
PPP_IPPARAM="$6"
export PPP_IFACE PPP_TTY PPP_SPEED PPP_LOCAL PPP_REMOTE PPP_IPPARAM

# as an additional convenience, $PPP_TTYNAME is set to the tty name,
# stripped of /dev/ (if present) for easier matching.
PPP_TTYNAME=`/usr/bin/basename "$2"`
export PPP_TTYNAME

# If /var/log/ppp-ipupdown.log exists use it for logging.
if [ -e /var/log/ppp-ipupdown.log ]; then
  exec > /var/log/ppp-ipupdown.log 2>&1
  echo $0 $@
  echo
fi

# quit if connect to some vpn
[[ $PPP_REMOTE == "192.168.240.1" ]] && exit 0
EOF

rt = routes.map do |r|
    if ostype == "Linux"
        "route add -net #{r} gw ${PPP_REMOTE}"
    else
        "route add -net #{r} -iface ${PPP_IFACE}"
    end
end.join("\n")

ip_up = <<-EOF
#{ppp_head}

#{rt}

EOF

nets = routes.join("\n")

ipset = <<-EOF
create abroad hash:net family inet hashsize 131080 maxelem 524288
#{routes.map do |r|
"add abroad #{r}"
end.join("\n")}
EOF

File.open "mode1/ip-up", "w" do |f|
    f.write(ip_up)
end

File.open "mode1/nets", "w" do |f|
  f.write nets
end

File.open "mode1/ipset", "w" do |f|
  f.write ipset
end

FileUtils.chmod_R "a+x", "mode1/"


FileUtils.rm_rf("mode2")
FileUtils.mkdir("mode2")

rt = cnRoutes.map do |r|
    if ostype == "Linux"
        "route add -net #{r} gw ${PPP_IPPARAM}"
    else
        "route add -net #{r} ${PPP_IPPARAM}"
    end
end.join("\n")

ip_up = <<-EOF
#{ppp_head}

route add -net 10/8 gw ${PPP_IPPARAM}
route add -net 172.16/12 gw ${PPP_IPPARAM}
route add -net 192.168/16 gw ${PPP_IPPARAM}

#{rt}

EOF


rt = cnRoutes.map do |r|
    "route del -net #{r} "
end.join("\n")


ip_down = <<-EOF
#{ppp_head}

route del -net 10/8 
route del -net 172.16/12 
route del -net 192.168/16 

#{rt}

EOF

nets = cnRoutes.join "\n"

ipset = <<-EOF
create china hash:net family inet hashsize 16385 maxelem 65535
#{cnRoutes.map do |r|
"add china #{r}"
end.join("\n")}
EOF

File.open "mode2/ip-up", "w" do |f|
    f.write(ip_up)
end


File.open "mode2/ip-down", "w" do |f|
    f.write(ip_down)
end

File.open "mode2/nets", "w" do |f|
  f.write nets
end

File.open "mode2/ipset", "w" do |f|
  f.write ipset
end

FileUtils.chmod_R "a+x", "mode2/"



