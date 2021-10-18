/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<8>  TYPE_TCP  = 6;

#define BLOOM_FILTER_ENTRIES 4096
#define BLOOM_FILTER_BIT_WIDTH 1

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t{
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<1>  cwr;
    bit<1>  ece;
    bit<1>  urg;
    bit<1>  ack;
    bit<1>  psh;
    bit<1>  rst;
    bit<1>  syn;
    bit<1>  fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct metadata {

}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t        tcp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition accept;
    }
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_1;
    register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_2;
    bit<32> reg_pos_one; bit<32> reg_pos_two;
    bit<1> reg_val_one; bit<1> reg_val_two;
    bit<1> direction;

    action drop() {
        mark_to_drop(standard_metadata);
    }
    
    action compute_hashes(ip4Addr_t ipAddr1, ip4Addr_t ipAddr2, bit<16> port1, bit<16> port2){
       //Get register position
       hash(reg_pos_one, HashAlgorithm.crc16, (bit<32>)0, {ipAddr1,
                                                           ipAddr2,
                                                           port1,
                                                           port2,
                                                           hdr.ipv4.protocol},
                                                           (bit<32>)BLOOM_FILTER_ENTRIES);

       hash(reg_pos_two, HashAlgorithm.crc32, (bit<32>)0, {ipAddr1,
                                                           ipAddr2,
                                                           port1,
                                                           port2,
                                                           hdr.ipv4.protocol},
                                                           (bit<32>)BLOOM_FILTER_ENTRIES);
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
    }
    
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    table check_ports {
        key = {
            standard_metadata.ingress_port: exact;
            standard_metadata.egress_spec: exact;
        }
        actions = {
            set_direction;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }
    
    apply {
        ipv4_lpm.apply();
        /*
        ---Apply firewall logic here---

        1- Check if the tcp packet is valid, and set a default direction value (e.g., direction = 0)

        2- Firewalls only apply actions to packets **IF** the TCP ports of the packet are defined to be filtered. These ports are defined in the check_ports table. You can verify if the ports of the packet should be filtered by using "if(check_ports.apply().hit)".

        3- Before dropping or forwarding the packet, the firewall must check and set the values of the respective data structure (in this case bloom_filter_1 and bloom_filter_2) for deciding the action it must take:
            3.1- Calculate the hash for that communication flow with "compute_hashes".
                3.1.1- The hash is an entry to our table filters (bloom_filters_1 and bloom_filters_2).
                3.1.2- The hash is the same for all ongoing open communications, as hashes are deterministic and if you use the same parameters, they will always yield the same value. In our case we use the source address, destination address, source port and destination port as parameters to compute the hash. Don't forget to swap the parameters position according to the direction of the flow with "compute_hashes".
                3.1.3- The "compute_hashes" consumes this data and digests it into a hash saved in "reg_pos_1" and "reg_pos_2". The hashes saved in this registers are then used for writting or reading from "bloom_filters_1" and "bloom_filters_2".

            3.2- Accept or drop the packets by analyzing the filters based on the direction of the flow.
                3.2.1- For applying, you don't have to invoke any command. For dropping you invoke the "drop()" function.
                3.2.2- Don't forget that the bloom filters start off empty, so you have to write into them. Write a 1 to the filters (e.g., "bloom_filter_1(reg_pos_one, 1)").
                3.2.3- All outbound packets are allowed and some inbound packets are blocked. You have to allow inbound packets from existing connections. You have to set the values on the bloom filters for new outbound connections, you can check if it's the start of a new connection by checking "hdr.tcp.syn == 1". With the values set on the filters, you can manage allowed and blocked inbound packets correctly.
                3.2.4- Use the "reg_val_one" and "reg_val_two" to read from the bloom_filters. (e.g. bloom_filters_1.read(reg_val_one, hash); bloom_filters_2.read(read_val_two,hash);)
                3.2.5- If BOTH "reg_val_one" and "reg_val_two" values are set. The packet is allowed, otherwise it is dropped.


        Here is a PSEUDOCODE of a possible solution.
        
        if(tcp_is_valid(packet)):
            if(packet_ports_must_be_filtered(packet)):
                packet_flow = direction
                //first i need the hashes to query my filter tables
                if(is_outbound(packet_flow)):
                    compute_hashes(src, dst, srcport, dstport)
                else:
                    compute_hashes(dst, src, dstport, srcport)
                //now that i have the hashes, i can query and take action
                if(is_outbound(packet_flow)):
                    //its an inbound connection, so i allow everything and must be able to receive the responses
                    //to receive the responses i have to write to the filters, because otherwise it will be blocked
                    if(is_new_connection(hdr.tcp.syn)):
                        write_to_filters(reg_pos_one, reg_pos_two, 1)
                else:
                    //its an outbound connection, so i block everything
                    //unless both entries to the filters are set as 1
                    read_from_filters(read_val_one, reg_pos_one, read_val_two, reg_pos_two)
                    if((read_val_one AND read_val_two) != 1):
                        drop()
        */
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
    update_checksum(
        hdr.ipv4.isValid(),
            { hdr.ipv4.version,
          hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}


/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
