# basic-iptable-setup
A bash script created for a class assignment that is meant to create a stateful firewall that meets some set requirements. This included flushing the IPtables, setting new default policy, saving rules etc. Some additional aspects were added as I wanted to try to add some extra functionality, like sudo checks, rule persistence, package checks, etc.

Requirements of the assignment:
- Start your script by flushing all previous firewall rules
- Next in your script you are to list your current firewall rules but send the output to a file named
  [path]initialstate.log, where [path] can be anything of your choosing.
- Define the following variables: 
    a. SERVER1 as 192.168.4.2
    b. TECHSUPPORT1 as 192.168.4.5
    c. UPDATESERVER as 192.168.4.7
- Allow all traffic in and out of your loopback interface.
- Make your firewall stateful and allow incoming traffic for all ESTABLISHED and RELATED connections
  and allow outbound traffic for ESTABLISHED and NEW connections.
- Allow incoming SSH traffic from TECHSUPPORT1.
- Allow outgoing FTP traffic to SERVER1 and incoming FTP traffic from UPDATESERVER. Note: FTP uses
  more than one port.
- Make the default policy for: INPUT DROP, OUTPUT ACCEPT and FORWARD DROP.
- Save your firewall rules.
- Next in your script you are to list (verbose) your current firewall rules but send the output to a file
  named [path]configuredstate.log, where [path] can be anything of your choosing.
- Using Wireshark, show traffic flow prior to firewall ruleset script being applied and then after being
  applied to the OS/Host. Note: Traffic should be blocked for SSH and FTP before and allowed after for
  each port in your scripts configuration. (THIS WAS PART OF THE ASSIGNMENT BUT NOT RELEVANT TO THE         SCRIPT ITSELF)

  All additional functionality outside of these requirements were of my own volition for an extra           challenge. I try to make these processes as automated and compatible as possible.
