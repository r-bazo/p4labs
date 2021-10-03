# Implementing a Control Plane using P4Runtime

## Introduction

In this exercise, we will be using P4Runtime to send flow entries to the 
switch instead of using the switch's CLI. We will be building on the same P4
program that you used in the [basic_tunnel](../basic_tunnel) exercise. As in the Tunnel assignment, you can simply copy and paste your `basic.p4` code in this folder, assuming it's working.
You will use the starter program, `mycontroller.py` to create the table entries necessary to tunnel traffic between host 1 and 2.

## Step 1: Run the (incomplete) starter code

The starter code for this assignment is the `mycontroller.py` file, and it will install only some of the rules that you need to tunnel traffic between
two hosts.
Let's first compile the new P4 program, start the network, use `mycontroller.py` to install a few rules.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `basic.p4`,
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`)
     configured in a triangle, each connected to one host (`h1`, `h2`, `h3`), and
   * assign IPs of `10.0.1.1`, `10.0.2.2`, `10.0.3.3` to the respective hosts.

2. You should now see a Mininet command prompt. Start a ping between h1 and h2:
   ```bash
   mininet> h1 ping h2
   ```
   Because there are no rules on the switches, you should **not** receive any
   replies yet. You should leave the ping running in this shell.
   
3. Open another shell and run the starter code:
   ```bash
   cd ~/tutorials/exercises/p4runtime
   ./mycontroller.py
   ```
   This will install the `basic.p4` program on the switches and push the rules. Since there are no ingress rules yet, you should not see ingress data here.
   If you run into permission denials and problems while running p4 code or python scripts, try running as `sudo` and/or `chmod` your files as required.

4. Press `Ctrl-C` to the second shell to stop `mycontroller.py`

Each switch is currently mapping traffic into tunnels based on the destination IP
address. Your job is to write the rules that forward the traffic between the switches
based on the tunnel ID.

## Step 2: Implement the rules and counters

1. In the `mycontroller.py` file, write your ingress transit rules inside the `writeTunnelRules` function. It should be similar to the egress transit rules already implemented on the file.
2. In the `basic.p4` file, add a new constant to your code called `MAX_TUNNEL_ID`, and it's value must be `1 << 16`.
3. On ingress, add two counters (`ingressTunnelCounter`, `egressTunnelCounter`). They must receive two parameters, first the previously created constant, second `CounterType.packets_and_bytes`). Refer to the cheat sheet for more information on the syntax.
4. On ingress, implement an action called `myTunnel_ingress`, the action must receive a 16 bit parameter called `dst_id`. The action must do the following:
  1. Set the valid bit on the `myTunnel` packet header.
  2. Set the `dst_id`, `proto_id` and `etherType` of the tunnel header.
  3. Increment the `ingressTunnelCounter` of the `dst_id` tunnel header index. Cast the index type to `bit<32>`.
5. On egress, implement an action called `myTunnel_egress`, the action must receive two parameters in the following order: first a parameter called `dst_Addr` with our mac address type defined on the code, second a parameter called `port`  with our egress type also defined on the code. The action must do the following:
  1. Set the value of `egress_spec` attribute of the `standard_metadata` to `port`.
  2. Set the `dstAddr` and `etherType` of the ethernet header to `dstAddr` and the tunnel's `proto_id`, respectively.
  3. Set the invalid bit on the `myTunnel` packet header.
  4. Increment the `egressTunnelCounter` of the `dst_id` tunnel header index. Cast the index type to `bit<32>`.
6. Add the implemented actions on `4` and `5` to the `ipv4_lpm` and `myTunnel_exact` tables.

## Step 3: Run your solution

1. In your shell, run:
   ```bash
   make
   ```

2. You should now see a Mininet command prompt. Start a ping between h1 and h2:
   ```bash
   mininet> h1 ping h2
   ```
   Because there are no rules on the switches, you should **not** receive any
   replies yet. You should leave the ping running in this shell.
   
3. Open another shell and run the python code:
   ```bash
   cd ~/tutorials/exercises/p4runtime
   ./mycontroller.py
   ```
   This will install the `basic.p4` program on the switches and push the rules. If you implemented the counters and the rules correctly, you should start see traffic flowing and the counters incrementing.

#### Cleaning up Mininet

If the Mininet shell crashes, it may leave a Mininet instance
running in the background. Use the following command to clean up:
```bash
make clean
```

## Next Steps

Congratulations, your implementation works! Move onto the next assignment
[firewall.](../firewall)

