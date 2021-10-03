# Implementing Source Routing

## Introduction

The objective of this exercise is to implement source routing.  With
source routing, the source host guides each switch in the network to
send the packet to a specific port. The host puts a stack of output
ports in the packet. In this example, we just put the stack after
Ethernet header and select a special etherType to indicate that.  Each
switch pops an item from the stack and forwards the packet according
to the specified port number.

Your switch must parse the source routing stack. Each item has a bos
(bottom of stack) bit and a port number. The bos bit is 1 only for the
last entry of stack.  Then at ingress, it should pop an entry from the
stack and set the egress port accordingly. The last hop may also
revert back the etherType to `TYPE_IPV4`.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`source_routing.p4`, which initially drops all packets. Your job (in
the next step) will be to extend it to properly to route packets.

Before that, let's compile the incomplete `source_routing.p4` and
bring up a network in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `source_routing.p4`, and
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`) configured
     in a triangle, each connected to one host (`h1`, `h2`, `h3`).
     Check the network topology using the `net` command in mininet.
     You can also change the topology in topology.json
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, etc
     (`10.0.<Switchid>.<hostID>`).

2. You should now see a Mininet command prompt. Open two terminals for
   `h1` and `h2`, respectively:
   ```bash
   mininet> xterm h1 h2
   ```
3. Each host includes a small Python-based messaging client and
   server. In `h2`'s xterm, start the server:
   ```bash
   ./receive.py
   ```
4. In `h1`'s xterm, send a message from the client:
   ```bash
   ./send.py 10.0.2.2
   ```

5. Type a list of port numbers. say `2 3 2 2 1`.  This should send the
   packet through `h1`, `s1`, `s2`, `s3`, `s1`, `s2`, and
   `h2`. However, `h2` will not receive the message.
   
6. Type `q` to exit send.py and type `exit` to leave each xterm and
   the Mininet command line.

The message was not received because each switch is programmed with
`source_routing.p4`, which drops all packets on arrival.  You can
verify this by looking at `/tmp/p4s.s1.log`.  Your job is to extend
the P4 code so packets are delivered to their destination.

## Step 2: Implement source routing

The `source_routing.p4` file contains a skeleton P4 program. You will have to extend it in the following way:


1. Set up `MyParser` accordingly to the [Basic Forwarding](../basic) assignment. You can reuse code if it works.
2. Update the `parse_ethernet` state in `MyParser` to verify if `etherType` is of value `TYPE_SRCROUTING`, transition to the action `parse_srcRouting` if positive, otherwise transition to `accept`.
3. Add a new action called `parse_srcRouting` to `MyParser`. This action must extract the next entry of `hdr.srcRoutes`. Use the `hdr.srcRoutes.last.bos` as argument when selecting your transition and add a loopback to `parse_srcRouting` as the `default` behaviour and for `1` proceed to `parse_ipv4`.
4. Set up `MyIngress` accordingly to the [Basic Forwarding](../basic) assignment. You can reuse code if it works.
5. Add three new actions to `MyIngress`: `srcRoute_nhop`, `srcRoute_finish` and `update_ttl`.
   1. `srcRoute_nhop` fetches the next egress port for the next hop from `hdr.srcRoutes` and sets it to our `standard_metadata.egress_spec`, lastly it removes the first entry of srcRoutes.
   2. `srcRoute_finish` sets the header `etherType` to `TYPE_IPV4`.
   3. `update_ttl` decrements the ttl from the header.
6. On the `MyIngress` `apply` control block you must check if there are still source routes using `isValid()`, change the packet's `etherType` if it's the last hop (by invoking `srcRoute_finish`) and update the ttl of the packet in case it's an IPv4 packet (by invoking `update_ttl()`).


## Step 3: Run your solution

Follow the instructions from Step 1. This time, your message from `h1`
should be delivered to `h2`.

Check the `ttl` of the IP header. Each hop decrements `ttl`.  The port
sequence `2 3 2 2 1`, forces the packet to have a loop, so the `ttl`
should be 59 at `h2`.  Can you find the port sequence for the shortest
path?

### Food for thought
* Can we change the program to handle both IPv4 forwarding and source
routing at the same time?
* How would you enhance your program to let the first switch add the
path, so that source routing would be transparent to end-hosts?

### Troubleshooting

There are several ways that problems might manifest:

1. `source_routing.p4` fails to compile. In this case, `make` will
   report the error emitted from the compiler and stop.
2. `source_routing.p4` compiles but switches or mininet do not start.
   Do you have another instance of mininet running? Did the previous
   run of mininet crash?  if yes, check "Cleaning up Mininet" bellow.
3. `source_routing.p4` compiles but the switch does not process
   packets in the desired way. The `/tmp/p4s.<switch-name>.log`
   files contain trace messages describing how each switch processes
   each packet. The output is detailed and can help pinpoint logic
   errors in your implementation.  The
   `<switch-name>-<interface-name>_<direction>.pcap` files contain pcap captures
   of all packets sent and received on each interface. Use `tcpdump -r <filename> -xxx` to
   print the hexdump of the packets.
4. If you run into permission denials and problems while running p4 code or python scripts, try running as `sudo` and/or `chmod` your files as required.

#### Cleaning up Mininet

In the cases above, `make` may leave a Mininet instance running in
the background.  Use the following command to clean up these
instances:

```bash
mn -c
```
