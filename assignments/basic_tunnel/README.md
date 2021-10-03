# Implementing Basic Tunneling

## Introduction

In this exercise, we will add support for a basic tunneling protocol to the IP
router that you completed in the previous assignment.  The basic switch
forwards based on the destination IP address.  Your job is to define a new
header type to encapsulate the IP packet and modify the switch code, so that it
instead decides the destination port using a new tunnel header.

The new header type will contain a protocol ID, which indicates the type of
packet being encapsulated, along with a destination ID to be used for routing.

### A note about the control plane

A P4 program defines a packet-processing pipeline, but the rules within each
table are inserted by the control plane. When a rule matches a packet, its
action is invoked with parameters supplied by the control plane as part of the
rule.

For this exercise, we have already added the necessary static control plane
entries. As part of bringing up the Mininet instance, the `make run` command
will install packet-processing rules in the tables of each switch. These are
defined in the `sX-runtime.json` files, where `X` corresponds to the switch
number.

Since the control plane tries to access the `myTunnel_exact` table, and that
table does not yet exist, the `make run` command will not work with the starter
code.

**Important:** We use P4Runtime to install the control plane rules. The content
of files `sX-runtime.json` refer to specific names of tables, keys, and
actions, as defined in the P4Info file produced by the compiler (look for the
file `build/basic.p4info` after executing `make run`). Any changes in the P4
program that add or rename tables, keys, or actions will need to be reflected
in these `sX-runtime.json` files.

## Step 1: Implement Basic Tunneling

The complete version of this assignment will be a switch able to forward based on the contents of a custom encapsulation
header as well as perform normal IP forwarding if the encapsulation header does not exist in the packet. To start of this, you will need to use your `basic.p4` code written in the [previous assignment](../basic). Simply copy and paste the code you have written in this folder and, assuming it's working, you are good for starting.

Your job will be to do the following:

1. Properly add a new header type called `myTunnel_t` that contains two 16-bit fields: `proto_id` and `dst_id`.
2. Add the `ethertype` of the tunnel as a constant in your code. The type must be called `TYPE_MYTUNNEL` and it's value must be `0x1212`.
3. Update the parser to properly extract the packets according to their `etherType`.
4. Define a new ingress action called `myTunnel_forward` that sets the egress port to the port number provided by the control plane (data provided by the control plane are created on runtime). The port number is an `egressSpec_t` argument received by the action.
4. Define a new table on ingress called `myTunnel_exact` that defines that the destination id of the tunnel header must be `exact`. This table must invoke the tunnel forward and drop actions.
5. Update Ingress `apply` control block with the necessary logic for properly parsing packets, either the newly added `myTunnel` packets or IPv4 packets.
6. Update the deparser with the newly added tunnel type.

![topology](./topo.png)

## Step 2: Run your solution

1. In your shell, run:
   ```bash
   make run
   ``` 
   This will:
   * compile `basic.p4`, and
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`) configured
     in a triangle, each connected to one host (`h1`, `h2`, and `h3`).
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, and `10.0.3.3`.

2. You should now see a Mininet command prompt. Open two terminals for `h1` and
`h2`, respectively: 
  ```bash
  mininet> xterm h1 h2
  ```
3. Each host includes a small Python-based messaging client and server. In
`h2`'s xterm, start the server: 
  ```bash 
  ./receive.py
  ```
4. First we will test without tunneling. In `h1`'s xterm, send a message to
`h2`: 
  ```bash
  ./send.py 10.0.2.2 "P4 is cool"
  ```
  The packet should be received at `h2`. If you examine the received packet 
  you should see that is consists of an Ethernet header, an IP header, a TCP
  header, and the message. If you change the destination IP address (e.g. try
  to send to `10.0.3.3`) then the message should not be received by `h2`, and
  will instead be received by `h3`.
5. Now we test with tunneling. In `h1`'s xterm, send a message to `h2`: 
  ```bash
  ./send.py 10.0.2.2 "P4 is cool" --dst_id 2
  ```
  The packet should be received at `h2`. If you examine the received packet you
  should see that is consists of an Ethernet header, a tunnel header, an IP header,
  a TCP header, and the message. 
6. In `h1`'s xterm, send a message: 
  ```bash
  ./send.py 10.0.3.3 "P4 is cool" --dst_id 2
  ```
  The packet should be received at `h2`, even though that IP address is the address
  of `h3`. This is because the switch is no longer using the IP header for routing
  when the `MyTunnel` header is in the packet. 
7. Type `exit` or `Ctrl-D` to leave each xterm and the Mininet command line.

> Python Scapy does not natively support the `myTunnel` header type so we have
> provided a file called `myTunnel_header.py` which adds support to Scapy for
> our new custom header. Feel free to inspect this file if you are interested
> in learning how to do this.

### Troubleshooting

There are several problems that might manifest as you develop your program:

1. `basic.p4` might fail to compile. In this case, `make run` will
report the error emitted from the compiler and halt.

2. `basic.p4` might compile but fail to support the control plane rules
in the `sX-runtime.json` files that `make run` tries to install using the
P4Runtime. In this case, `make run` will report errors if control plane rules
cannot be installed. Use these error messages to fix your `basic_tunnel.p4`
implementation or forwarding rules.

3. `basic.p4` might compile, and the control plane rules might be
installed, but the switch might not process packets in the desired way. The
`/tmp/p4s.<switch-name>.log` files contain detailed logs that describing how
each switch processes each packet. The output is detailed and can help pinpoint
logic errors in your implementation.

4. If you run into permission denials and problems while running p4 code or python scripts, try running as `sudo` and/or `chmod` your files as required.

#### Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance running in
the background. Use the following command to clean up these instances:

```bash
make stop
```

## Next Steps

Congratulations, your implementation works! Move onto the next assignment
[P4Runtime](../p4runtime)!

