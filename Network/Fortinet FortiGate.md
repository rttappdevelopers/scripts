# About
Commands specific to FortiGate firewalls

# Commands
## Network commands

**Ping**

Pings a network address
```properties
exec ping 192.168.1.10
```

**ARP Table**

Show list of IP and MAC addresss that the firewall has seen activity from
```properties
get system arp
```

## System

**Performance Stats**
```properties
get sys perf status
```

**Top processes**
```properties
diagnose sys top
diagnose sys top-mem
```

**Find and restart process**

Example used is the SSL VPN service.
```properties
diag sys process pidof sslvpnd
diag sys kill 11 <pid>
```

# Configurations
**Filesystem Check**

Configure firewall to automatically run filesystem check at boot if it was powercycled.
```properties
config system global
   set autorun-log-fsck enable
end
```

**TCP Timestamp Disable**

This should be disabled as it poses a possible security vulnerability.

```properties
config system global
   set tcp-option disable
end
```

```properties
config firewall service custom
    edit "TIMESTAMP"
        set protocol ICMP
        set icmptype 13
    next
end
config firewall local-in-policy
    edit 0
        set intf "wan1"
        set srcaddr "all"
        set dstaddr "all"
        set service "TIMESTAMP"
        set schedule "always"
        set action deny
    next
    edit 0
        set intf "wan2"
        set srcaddr "all"
        set dstaddr "all"
        set service "TIMESTAMP"
        set schedule "always"
        set action deny
    next
    edit 0
        set intf "wan"
        set srcaddr "all"
        set dstaddr "all"
        set service "TIMESTAMP"
        set schedule "always"
        set action deny
    next
end
```
**Legacy encryption cipher disablement**

Disable these ciphers to mitigate against DHEater DDoS attacks.

```properties
config system global
    set admin-https-ssl-banned-ciphers RSA DHE
end
```

```properties
config vpn ssl settings
    set banned-cipher RSA DHE
end
```

**VOIP Requirements**

VoIP - Disable SIP ALG (even if they don't have VoIP now)
```properties
config system session-helper
    delete 13
end
config system settings
    set sip-helper disable
    set sip-expectation disable
    set sip-nat-trace disable
    set default-voip-alg-mode kernel-helper-based
end
config voip profile
    edit default
    config sip
        set rtp disable
    end
end
```

**WAN Link Failover**

Useful for dual-WAN configurations where it is expected that the router should redirect traffic over the secondary WAN if the primary becomes unusable. 

The default is to ping the ISP gateway IP address, which is not recommended where ISP gateways may remain reachable from the site but anything upstream is not. This is common in Carrier Grade NAT (CGNAT) scenarios where an ISP provides sites with an internally routed IP address.

```properties
config system link-monitor
    edit "WAN1"
        set srcintf "wan1"
        set server "8.8.8.8"
        set update-cascade-interface disable
    next
end
```