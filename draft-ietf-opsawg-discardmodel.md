---
title: Information and Data Models for Packet Discard Reporting
abbrev: IM and DM for Packet Discard Reporting
docname: draft-ietf-opsawg-discardmodel-latest
category: std

ipr: trust200902
area: Operations and Management Area
workgroup: "Operations and Management Area Working Group"
keyword:
 - Troubleshooting
 - Diagnostic
 - Network Automation
 - Network Service
 - Resilience
 - Robustness
 - Root cause
 - Anomaly
 - Incident
 - Customer experience

venue:
  group: "Operations and Management Area Working Group"
  type: ""
  mail: "opsawg@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/opsawg/"
  github: "o-pylypenko/draft-ietf-opsawg-discardmodel"
  latest: "https://o-pylypenko.github.io/draft-ietf-opsawg-discardmodel/draft-ietf-opsawg-discardmodel.html"

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
 -
    ins: J. Evans
    name: John Evans
    org: Amazon
    street: 1 Principal Place, Worship Street
    city: London
    code: EC2A 2FA
    country: UK
    email: jevanamz@amazon.co.uk

 -
    ins: O. Pylypenko
    name: Oleksandr Pylypenko
    org: Amazon
    street: 410 Terry Ave N
    city: Seattle
    region: WA
    code: 98109
    country: US
    email: opyl@amazon.com

 -
    ins: J. Haas
    name: Jeffrey Haas
    org: Juniper Networks
    street: 1133 Innovation Way
    city: Sunnyvale
    region: CA
    code: 94089
    country: US
    email: jhaas@juniper.net
 -
    ins: A. Kadosh
    name: Aviran Kadosh
    org: Cisco Systems, Inc.
    street: 170 West Tasman Dr.
    city: San Jose
    region: CA
    code: 95134
    country: US
    email: akadosh@cisco.com
 -
    ins: M. Boucadair
    name: Mohamed Boucadair
    org: Orange
    country: France
    email: mohamed.boucadair@orange.com

normative:

informative:
     RED93:
          title: Random Early Detection gateways for Congestion Avoidance
          authors:
               ins: S. Floyd
               ins: V. Jacobson
     gMNI:
          title: gRPC Network Management Interface, IETF 98, March 2017, <https://datatracker.ietf.org/meeting/98/materials/slides-98-rtgwg-gnmi-intro-draft-openconfig-rtgwg-gnmi-spec-00>
          authors:
               ins: Shakir, R.
               ins: Shaikh, A.
               ins: Borman, P.
               ins: Hines, M.
               ins: Lebsack, C.
               ins: C. Marrow

--- abstract

This document defines an Information Model and specifies a corresponding YANG data model for packet discard reporting. The Information Model provides an implementation-independent framework for classifying packet loss — both intended (e.g., due to policy) and unintended (e.g., due to congestion or errors) — to enable automated network mitigation of unintended packet loss. The YANG data model specifies an implementation of this framework for network elements.

--- middle

# Introduction        {#introduction}

The primary function of a network is to transport and deliver packets according to service level objectives. For network operators, understanding both where and why packet loss occurs within a network is essential for effective operation. Device-reported packet loss provides the most direct signal for identifying service impact. While certain types of packet loss, such as policy-based discards, are intentional and part of normal network operation, unintended packet loss can impact customer services.  To automate network operations, operators must be able to detect customer-impacting packet loss, determine its root cause, and apply appropriate mitigation actions. Precise classification of packet loss is thus crucial to ensure that anomalous packet loss is easily detected and that the right action is taken to mitigate the impact. Taking the wrong action can make problems worse; for example, removing a congested device from service can exacerbate congestion by redirecting traffic to other already congested links or devices.

Existing metrics for reporting packet loss, such as ifInDiscards, ifOutDiscards, ifInErrors, and ifOutErrors defined in "The Interfaces Group MIB" {{?RFC2863}} and "A YANG Data Model for Interface Management" {{?RFC8343}}, are insufficient for automating network operations. First, they lack precision; for instance, ifInDiscards aggregates all discarded inbound packets without specifying the cause, making it challenging to distinguish between intended and unintended discards. Second, these definitions are ambiguous, leading to inconsistent vendor implementations. For example, in some implementations ifInErrors accounts only for errored packets that are dropped, while in others, it includes all errored packets, whether they are dropped or not. Many implementations support more discard metrics than these, however, they have been inconsistently implemented due to the lack of a standardised classification scheme and clear semantics for packet loss reporting. For example, {{?RFC7270}} provides support for reporting discards per flow in IP Flow Information Export (IPFIX) {{?RFC7011}} using forwardingStatus, however, the defined drop reason codes also lack sufficient clarity to facilitate automated root cause analysis and impact mitigation (e.g., the "For us" reason code).

This document defines an Information Model (IM) and specifies a corresponding YANG Data Model (DM) for packet loss reporting which address these issues.  The IM provides precise classification of packet loss to enable accurate automated mitigation. The DM specifies a YANG implementation of this framework for network elements, while maintaining consistency through clear semantics.

The scope of this document is limited to reporting packet loss at Layer 3 and frames discarded at Layer 2. This document considers only the signals that may trigger automated mitigation actions and not how the actions are defined or executed.

{{problem}} describes the problem space and requirements. {{infomodel}} defines the IM and classification scheme. {{datamodel}} specifies the corresponding YANG data model and implementation requirements together with a set of usage examples, and the complete YANG module definition. The appendices provide additional context and implementation guidance.

# Terminology {#terminology}

{::boilerplate bcp14-tagged}

Tree diagrams used in this document follow the notation defined in {{?RFC8340}}.

This document makes use of the following terms:

Packet discard:
: It accounts for any instance where a packet is dropped by a device, regardless of whether the discard was intentional or unintentional.

Intended discards:
: Are packets dropped due to deliberate network policies or configurations designed to enforce security or Quality of Service (QoS). For example, packets dropped because they match an Access Control List (ACL) denying certain traffic types.

Unintended discards:
: Are packets that were dropped, which the network operator otherwise intended to deliver, i.e. which indicates an error state.  There are many possible reasons for unintended packet loss, including: erroring links may corrupt packets in transit; incorrect routing tables may result in packets being dropped because they do not match a valid route; configuration errors may result in a valid packet incorrectly matching an ACL and being dropped.
: Device discard counters do not by themselves establish operator intent. Discards reported under policy (e.g., ACL/policer) indicate only that traffic matched a configured rule; such discards may still be unintended if the configuration is in error. Determining intent for policy discards requires external context (e.g., configuration validation and change history) which is out of scope for this specification.

# Problem Statement   {#problem}

The fundamental problem for network operators is how to automatically detect when and where unintended packet loss is occurring and determine the appropriate action to mitigate it. For any network, there are a small set of potential actions that can be taken to mitigate customer impact when unintended packet loss is detected, for example:

1. Take a problematic device, link, or set of devices and/or links out of service.
2. Return a device, link, or set of devices and/or links back into service.
3. Move traffic to other links or devices to alleviate congestion or avoid problematic paths.
4. Roll back a recent change to a device that might have caused the problem.
5. Escalate to a network operator as a last resort when automated mitigation is not possible.

The ability to select the appropriate mitigation action depends on four key features of packet loss:

FEATURE-DISCARD-SCOPE:
: Determines which devices, interfaces, and/or flows are impacted.

FEATURE-DISCARD-RATE:
: The rate and/or magnitude of the discards, indicating the severity and urgency of the problem.  Rate may be expressed using absolute (e.g., pps (packets per second)) or relative (e.g., percent) values.

FEATURE-DISCARD-DURATION:
: The duration of the discards which helps to distinguish transient from persistent issues.

FEATURE-DISCARD-CLASS:
: The type or class of discards, which is crucial for selecting the appropriate type of mitigation. Examples may be:  error discards may require taking faulty components out of service, no-buffer discards may require traffic redistribution, or intended policy discards typically require no automated action.

While FEATURE-DISCARD-SCOPE, FEATURE-DISCARD-RATE, and FEATURE-DISCARD-DURATION are implicitly supported by the Interfaces Group MIB {{?RFC2863}} and the YANG Data Model for Interface Management {{?RFC8343}}, FEATURE-DISCARD-CLASS requires a more detailed classification scheme than they define. The IM provided in {{infomodel}} defines such a classification scheme to enable automated mapping from loss signals to appropriate mitigation actions.

# Information Model (IM)   {#infomodel}

The IM is defined using YANG {{!RFC7950}}, with Data Structure Extensions {{!RFC8791}}, allowing the model to remain abstract and decoupled from specific implementations in accordance with {{?RFC3444}}. This abstraction supports different DM implementations, such as YANG or IPFIX {{?RFC7011}}, while ensuring consistency across implementations. Using YANG for the IM enables this abstraction, leverages the community's familiarity with its syntax, and ensures lossless translation to the corresponding YANG data model, which is defined in {{datamodel}}.

## Structure {#infomodel-structure}

The IM defines a hierarchical classification scheme for packet discards, which captures where in a device the discards are accounted (component), in which direction they were flowing (direction), whether they were successfully processed or discarded (type), what protocol layer they belong to (layer), and the specific reason for any discards (sub-types). This structure enables both high-level monitoring of total discards and more detailed triage to map to mitigation actions.

The abstract structure of the IM is depicted in {{tree-im-abstract}}. The full YANG tree diagram of the IM is provided in {{sec-im-full-tree}}.

~~~~~~~~~~
module: ietf-packet-discard-reporting-sx

  structure packet-discard-reporting:
    +-- control-plane {control-plane-stats}?
    |  +-- traffic* [direction]
    |  |  ...
    |  +-- discards* [direction]
    |     ...
    +-- interface* [name] {interface-stats}?
    |  +-- name        string
    |  +-- traffic* [direction]
    |  |  +-- direction    identityref
    |  |  +-- l2
    |  |  |  ...
    |  |  +-- l3
    |  |  |  ...
    |  |  +-- qos
    |  |     +-- class* [id]
    |  |        ...
    |  +-- discards* [direction]
    |     +-- direction    identityref
    |     +-- l2
    |     |  ...
    |     +-- l3
    |     |  ...
    |     +-- errors
    |     |  +-- l2
    |     |  |  ...
    |     |  +-- l3
    |     |  |  ...
    |     |  +-- internal
    |     |     ...
    |     +-- policy
    |     |  +-- l2
    |     |  |  ...
    |     |  +-- l3
    |     |     ...
    |     +-- no-buffer
    |        +-- class* [id]
    |           ...
    +-- flow* [direction] {flow-reporting}?
    |  +-- direction    identityref
    |  +-- traffic
    |  |  +-- l2
    |  |  |  ...
    |  |  +-- l3
    |  |  |  ...
    |  |  +-- qos
    |  |     +-- class* [id]
    |  |        ...
    |  +-- discards
    |     +-- l2
    |     |  ...
    |     +-- l3
    |     |  ...
    |     +-- errors
    |     |  +-- l2
    |     |  |  ...
    |     |  +-- l3
    |     |  |  ...
    |     |  +-- internal
    |     |     ...
    |     +-- policy
    |     |  +-- l2
    |     |  |  ...
    |     |  +-- l3
    |     |     ...
    |     +-- no-buffer
    |        +-- class* [id]
    |           ...
    +-- device {device-stats}?
       +-- traffic
       |  +-- l2
       |  |  ...
       |  +-- l3
       |  |  ...
       |  +-- qos
       |     +-- class* [id]
       |        ...
       +-- discards
          +-- l2
          |  ...
          +-- l3
          |  ...
          +-- errors
          |  +-- l2
          |  |  ...
          |  +-- l3
          |  |  ...
          |  +-- internal
          |     ...
          +-- policy
          |  +-- l2
          |  |  ...
          |  +-- l3
          |     ...
          +-- no-buffer
             +-- class* [id]
                ...
~~~~~~~~~~
{: #tree-im-abstract title="Abstract IM Tree Structure"}

The discard reporting can be organized into several types: control plane, interface, flow, and device. In order to allow for better mapping to underlying DMs, the IM supports a set of "features" to control the supported type.

A complete classification path follows the pattern: component/direction/type/layer/sub-type/sub-sub-type/.../metric. {{wheredropped}} illustrates where these discards typically occur in a network device.  The elements of the tree are defined as follows:

- Component:
  - control-plane: discards of traffic to or from a device's control plane.
  - interface: discards of traffic to or from a specific network interface.
  - flow: discards of traffic associated with a specific traffic flow.
  - device: discards of traffic transiting the device.

- Direction:
  - ingress: counters for incoming packets or frames.
  - egress: counters for outgoing packets or frames.

- Type:
  - traffic: counters for successfully received or transmitted packets or frames.
  - discards: counters for packets or frames that were dropped.

- Layer:
  - l2: Layer 2 traffic and discards. This covers both frame and byte counts.
  - l3: Layer 3 traffic and discards. This covers both packet and byte counts.

The hierarchical structure allows for future extension while maintaining backward compatibility. New discard types can be added as new branches without affecting existing implementations.

The corresponding YANG module is defined in {{infomodel-module}}.

## Sub-type Definitions

discards/policy/:
: These are intended discards, meaning packets dropped by a device due to a configured policy, including: ACLs, traffic policers, Reverse Path Forwarding (RPF) checks, DDoS protection rules, and explicit null routes.

discards/error/:
: These are unintended discards due to errors in processing packets or frames.  There are multiple sub-classes.

discards/error/l2/rx/:
: These are frames discarded due to errors in the received Layer 2 frame, including: CRC errors, invalid MAC addresses, invalid VLAN tags, frame size violations and other malformed frame conditions.

discards/error/l3/rx/:
: These are discards which occur due to errors in the received packet, indicating an upstream problem rather than an issue with the device dropping the errored packets, including: header checksum errors,  MTU exceeded, invalid packet errors, i.e., incorrect version, incorrect header length, invalid options and other malformed packet conditions.

discards/error/l3/rx/ttl-expired:
: These are discards due to TTL (or Hop limit) expiry, which can occur for the following reasons: normal trace-route operations, end-system TTL/Hop limit set too low, routing loops in the network.

discards/error/l3/no-route/:
: These are discards which occur due to a packet not matching any route in the routing table, e.g., which may be due to routing configuration errors or may be transient discards during convergence.

discards/error/internal/:
: These are discards due to internal device issues, including: parity errors in device memory or other internal hardware errors.  Any errored discards not explicitly assigned to other classes are also accounted for here.

discards/no-buffer/:
:  These are discards due to buffer exhaustion (that is congestion related discards). These can be tail-drop discards or due to an active queue management algorithm, such as Random Early Detection (RED) {{RED93}} or Controlled Delay (CoDel) {{?RFC8289}}.

An example of possible signal-to-mitigation action mapping is provided in {{mapping}}.

## "ietf-packet-discard-reporting-sx" YANG Module {#infomodel-module}

The "ietf-packet-discard-reporting-sx" module uses the "sx" structure defined in {{!RFC8791}}.

~~~~~~~~~~
<CODE BEGINS>
{::include-fold ./yang/ietf-packet-discard-reporting-sx.yang}
<CODE ENDS>
~~~~~~~~~~

# Data Model (DM)   {#datamodel}

This DM implements the IM defined in {{infomodel}} for the interface, device, and control-plane components. It is a device model per {{Section 2.1 of ?RFC8969}}. Specifically, it is a device-local (network element) operational state model: counters are scoped to a single device (interfaces and control plane).

## Structure {#datamodel-structure}

There is a direct mapping between the IM components and their DM implementations, with each component in the hierarchy represented by corresponding YANG containers and leaf data nodes. The abstract tree is shown in {{tree-dm-abstract}}.

~~~~~~~~~~
module: ietf-packet-discard-reporting

  +--ro control-plane! {control-plane-stats}?
  |  +--ro traffic* [direction]
  |  |  ...
  |  +--ro discards* [direction]
  |     ...
  +--ro interface* [name] {interface-stats}?
  |  +--ro name        string
  |  +--ro traffic* [direction]
  |  |  +--ro direction    identityref
  |  |  +--ro l2
  |  |  |  ...
  |  |  +--ro l3
  |  |  |  ...
  |  |  +--ro qos
  |  |     +--ro class* [id]
  |  |        ...
  |  +--ro discards* [direction]
  |     +--ro direction    identityref
  |     +--ro l2
  |     |  ...
  |     +--ro l3
  |     |  ...
  |     +--ro errors
  |     |  +--ro l2
  |     |  |  ...
  |     |  +--ro l3
  |     |  |  ...
  |     |  +--ro internal
  |     |     ...
  |     +--ro policy
  |     |  +--ro l2
  |     |  |  ...
  |     |  +--ro l3
  |     |     ...
  |     +--ro no-buffer
  |        +--ro class* [id]
  |           ...
  +--ro device! {device-stats}?
     +--ro traffic
     |  +--ro l2
     |  |  ...
     |  +--ro l3
     |  |  ...
     |  +--ro qos
     |     +--ro class* [id]
     |        ...
     +--ro discards
        +--ro l2
        |  ...
        +--ro l3
        |  ...
        +--ro errors
        |  +--ro l2
        |  |  ...
        |  +--ro l3
        |  |  ...
        |  +--ro internal
        |     ...
        +--ro policy
        |  +--ro l2
        |  |  ...
        |  +--ro l3
        |     ...
        +--ro no-buffer
           +--ro class* [id]
              ...
~~~~~~~~~~
{: #tree-dm-abstract title="Abstract DM Tree Structure"}

The full tree structure is provided in {{sec-dm-full-tree}}.

## Implementation Requirements {#requirements}

The following requirements apply to the implementation of the DM and are intended to ensure consistent implementation across different vendors and platforms while allowing for platform-specific optimisations where needed. While the model defines a comprehensive set of counters and statistics, implementations MAY support a subset of the defined features based on device capabilities and operational requirements. However, implementations MUST clearly document which features are supported and how they map to the DM.

Requirements 1-13 relate to packets forwarded or discarded by the device, while requirement 14 relates to packets destined for or originating from the device:

1. All instances of Layer 2 frame or Layer 3 packet receipt, transmission, and discards MUST be accounted for.
2. All instances of Layer 2 frame or Layer 3 packet receipt, transmission, and discards SHOULD be attributed to the physical or logical interface of the device where they occur.  Where they cannot be attributed to the interface, they MUST be attributed to the device.
3. An individual frame MUST only be accounted for by either the Layer 2 traffic class or the Layer 2 discard classes within a single direction or context, i.e., ingress or egress or device.  This is to avoid double counting.
4. An individual packet MUST only be accounted for by either the Layer 3 traffic class or the Layer 3 discard classes within a single direction or context, i.e., ingress or egress or device.  This is to avoid double counting.
5. A frame accounted for at Layer 2 SHOULD NOT be accounted for at Layer 3 and vice versa.  An implementation MUST indicate which layers traffic and discards are counted against.  This is to avoid double counting.
6. The aggregate Layer 2 and Layer 3 traffic and discard classes SHOULD account for all underlying frames or packets received, transmitted, and discarded across all other classes.
7. The aggregate QoS traffic and no-buffer discard classes MUST account for all underlying packets received, transmitted, and discarded across all other classes.
8. In addition to the Layer 2 and Layer 3 aggregate classes, an individual discarded packet MUST only account against a single error, policy, or no-buffer discard subclass.
9. When there are multiple reasons for discarding a packet, the ordering of discard class reporting MUST be defined.
10. If Diffserv {{?RFC2475}} is not used, no-buffer discards SHOULD be reported as class[id="0"], which represents the default class.
11. When traffic is mirrored, the discard metrics MUST account for the original traffic rather than the reflected traffic.
12. No-buffer discards can be realized differently with different memory architectures. Whether a no-buffer discard is attributed to ingress or egress can differ accordingly.  For successful auto-mitigation, discards due to an egress interface congestion MUST be reportable on `egress`, while discards due to device-level congestion (e.g., due to exceeding the device forwarding rate) MUST be reportable on `ingress`.
13. When the ingress and egress headers differ—for example, at a tunnel endpoint—the discard class attribution MUST relate to the outer header at the point of discard.
14. Traffic to the device control plane has its own class. However, traffic from the device control plane MUST be accounted for in the same way as other egress traffic.

## Usage Examples {#examples}

If all of the requirements listed in {{requirements}} are met, a "good" unicast IPv4 packet received would increment:

- interface/traffic[direction="ingress"]/l3/address-family-stat[address-family="ipv4"]/unicast/packets
- interface/traffic[direction="ingress"]/l3/address-family-stat[address-family="ipv4"]/unicast/bytes
- interface/traffic[direction="ingress"]/qos/class[id="0"]/packets
- interface/traffic[direction="ingress"]/qos/class[id="0"]/bytes

A received unicast IPv6 packet discarded due to Hop Limit expiry would increment:

- interface/traffic[direction="ingress"]/l3/address-family-stat[address-family="ipv6"]/unicast/packets
- interface/traffic[direction="ingress"]/l3/address-family-stat[address-family="ipv6"]/unicast/bytes
- interface/discards[direction="ingress"]/l3/rx/ttl-expired/packets

An IPv4 packet discarded on egress due to no buffers would increment:

- interface/discards[direction="egress"]/l3/address-family-stat[address-family="ipv4"]/unicast/packets
- interface/discards[direction="egress"]/l3/address-family-stat[address-family="ipv4"]/unicast/bytes
- interface/discards[direction="egress"]/no-buffer/class[id="0"]/packets
- interface/discards[direction="egress"]/no-buffer/class[id="0"]/bytes

A multicast IPv6 packet dropped due to RPF check failure would increment:

- interface/discards[direction="ingress"]/l3/address-family-stat[address-family="ipv6"]/multicast/packets
- interface/discards[direction="ingress"]/l3/address-family-stat[address-family="ipv6"]/multicast/bytes
- interface/discards[direction="ingress"]/policy/l3/rpf/packets

A "good" Layer-2 frame received would increment:

- interface/traffic[direction="ingress"]/l2/frames
- interface/traffic[direction="ingress"]/l2/bytes
- interface/traffic[direction="ingress"]/qos/class[id="0"]/packets
- interface/traffic[direction="ingress"]/qos/class[id="0"]/bytes


## "ietf-packet-discard-reporting" YANG Module {#datamodel-module}

The "ietf-packet-discard-reporting" module imports "ietf-packet-discard-reporting-sx", "ietf-netconf-acm" {{!RFC8341}}, "ietf-interfaces" {{!RFC8343}},
"ietf-routing" {{!RFC8349}}, and "ietf-logical-network-element" {{!RFC8530}}.

~~~~~~~~~~
<CODE BEGINS>
{::include-fold ./yang/ietf-packet-discard-reporting.yang}
<CODE ENDS>
~~~~~~~~~~

# Deployment Considerations Experience {#experience}

This section captures practical insights gained from implementing the model across multiple vendors' platforms, as guidance for future implementers and operators:

1. The number and granularity of discard classes defined in the IM represent a compromise. It aims to provide sufficient detail to enable appropriate automated actions while avoiding excessive detail, which may hinder quick problem identification.  Additionally, it helps to limit the quantity of data produced per interface, constraining the data volume and device CPU impacts.  While further granularity is possible, the defined schema has generally proven to be sufficient for the task of mitigating unintended packet loss.
2. There are many possible ways to define the discard classification tree.  For example, an approach is to use a multi-rooted tree, rooted in each protocol. Instead, a better approach is to define a tree where protocol discards and causal discard classes are accounted for orthogonally.  This decision reduces the number of combinations of classes and has proven sufficient for determining mitigation actions.
3. Platforms often account for the number of packets discarded where the TTL has expired (or IPv6 Hop Limit exceeded), and the device CPU has returned an ICMP Time Exceeded message {{?RFC4884}}. There is typically a policer applied to limit the number of packets sent to the device CPU, however, which implicitly limits the rate of TTL discards that are processed.  One method to account for all packet discards due to TTL expired, even those that are dropped by a policer when being forwarded to the CPU, is to use accounting of all ingress packets received with TTL=1 as a proxy measure.
4. Where no route discards are implemented with a default null route, separate discard accounting is required for any explicit null routes configured in order to differentiate between interface/ingress/discards/policy/null-route/packets and interface/ingress/discards/errors/no-route/packets.
5. It is useful to account separately for transit packets discarded by ACLs or policers, and packets discarded by ACLs or policers which limit the number of packets to the device control plane.
6. It is not possible to identify a configuration error (e.g., when intended discards are unintended) with device discard metrics alone. For example, additional context is needed to determine if ACL discards are intended or due to a misconfigured ACL (i.e., with configuration validation before deployment or by detecting a significant change in ACL discards after a configuration change compared to before).
7. Aggregate counters need to be able to deal with the possibility of discontinuities in the underlying counters.
8. While the classification tree is seven layers deep, a minimal implementation may only implement the top six layers.

# Security Considerations {#security}

## Information Model {#security-infomodel}

The IM defined in {{infomodel-module}} specifies a YANG module using {{!RFC8791}} data extensions.  It defines a set of identities, types, and groupings. These nodes are intended to be reused by other YANG modules. The module by itself does not expose any data nodes that are writable, data nodes that contain read-only state, or RPCs. As such, there are no additional security issues related to the YANG module that need to be considered.

## Data Model {#security-datamodel}

This section is modeled after the template described in {{Section 3.7 of ?I-D.ietf-netmod-rfc8407bis}}.

The YANG module specified in {{datamodel-module}} defines a data model that is designed to be accessed via YANG-based management protocols, such as NETCONF {{?RFC6241}} and RESTCONF {{?RFC8040}}. These YANG-based management protocols (1) have to use a secure transport layer (e.g., SSH {{?RFC4252}}, TLS {{?RFC8446}}, and QUIC {{?RFC9000}}) and (2) have to use mutual authentication.

The Network Configuration Access Control Model (NACM) {{!RFC8341}} provides the means to restrict access for particular NETCONF or RESTCONF users to a preconfigured subset of all available NETCONF or RESTCONF protocol operations and content.

There are no particularly sensitive writable data nodes.

Some of the readable data nodes in this YANG module may be considered sensitive or vulnerable in some network environments.  It is thus important to control read access (e.g., via get, get-config, or notification) to these data nodes. Specifically, the following subtrees and data nodes have particular sensitivities/vulnerabilities:

Control-plane, interfaces, and devices:
: Access to these data nodes would reveal information about the attacks to which an element is subject, misconfigurations, etc.
: Also, an attacker who can inject packets can infer the efficiency of its attack by monitoring (the increase of) some discard counters (e.g., policy) and adjust its attack strategy accordingly.

# IANA Considerations {#iana}

IANA is requested to register the following URI in the "ns" subregistry within the "IETF XML Registry" {{!RFC3688}}:

~~~~
   URI:  urn:ietf:params:xml:ns:ietf-packet-discard-reporting-sx
   Registrant Contact:  The IESG.
   XML:  N/A; the requested URI is an XML namespace.

   URI:  urn:ietf:params:xml:ns:ietf-packet-discard-reporting
   Registrant Contact:  The IESG.
   XML:  N/A; the requested URI is an XML namespace.
~~~~

   IANA is requested to register the following YANG module in the "YANG Module
   Names" subregistry {{!RFC6020}} within the "YANG Parameters" registry:

~~~~
   Name:  ietf-packet-discard-reporting-sx
   Namespace:  urn:ietf:params:xml:ns:ietf-packet-discard-reporting-sx
   Prefix:  plr-sx
   Maintained by IANA?  N
   Reference:  RFC XXXX

   Name:  ietf-packet-discard-reporting
   Namespace:  urn:ietf:params:xml:ns:ietf-packet-discard-reporting
   Prefix:  plr
   Maintained by IANA?  N
   Reference:  RFC XXXX
~~~~


# Contributors {#contributors}

    Nadav Chachmon
    Cisco Systems, Inc.
    170 West Tasman Dr.
    San Jose, CA 95134
    United States of America
    Email: nchachmo@cisco.com

# Acknowledgments {#acknowledgements}

The content of this document has benefitted from feedback from JR Rivers, Ronan Waide, Chris DeBruin, and Marcos Sanz.

Thanks to Benoît Claise, Joe Clarke, Tom Petch, Mahesh Jethanandani, Paul Aitken, and Randy Bush for the review and comments.

Thanks to Ladislav Lhotka for the YANGDOCTORS review and Sergio Belotti for the OPSDIR review.

--- back


# Where Do Packets Get Dropped? {#wheredropped}

Understanding where packets are discarded in a network device is essential for interpreting discard signals and determining appropriate mitigation actions.  {{ex-drop}} depicts an example of where and why packets may be discarded in a typical single-ASIC, shared-buffered type device. While actual device architectures vary between vendors and platforms, with some using multiple ASICs, distributed forwarding, or different buffering architectures, this example illustrates the common processing stages where packets may be dropped. The logical model for classifying and reporting discards remains consistent regardless of the underlying hardware architecture.

Packets ingress on the left and egress on the right:

~~~~~~~~~~ aasvg
                              +-----------+
                              |           |
                              |  Control  |
                              |  Plane    |
                              +---+---^---+
                         from_cpu |   | to_cpu
                                  |   |
         +------------------------v---+------------------------+
         |                                                     |
    +----+----+  +----------+  +---------+  +----------+  +----+----+
    |         |  |          |  |         |  |          |  |         |
Rx--> PHY/MAC +--> Ingress  +--> Buffers +--> Egress   +--> PHY/MAC +-> Tx
    |         |  | Pipeline |  |         |  | Pipeline |  |         |
    +---------+  +----------+  +---------+  +----------+  +---------+

Unintended:
    error/rx/l2  error/l3/rx   no-buffer    error/l3/tx
                 error/l3/no-route
                 error/l3/rx/ttl-expired
                 error/internal
Intended:
                 policy/acl                 policy/acl
                 policy/policer             policy/policer
                 policy/urpf
                 policy/null-route

~~~~~~~~~~
{: #ex-drop title="Example of where packets get dropped"}

See Appendix B for examples of how these discard signals map to root causes and mitigation actions.

# Example Signal-to-mitigation Action Mapping {#mapping}

The effectiveness of automated mitigation depends on correctly mapping discard signals to root causes and appropriate actions.  {{ex-table}} gives example discard signal-to-mitigation action mappings based on the features described in section 3.


| DISCARD-CLASS | Discard cause | DISCARD-RATE | DISCARD-DURATION | Unintended? | Possible actions |
|:--------------|:--------------|:-------------|:----------------:|:-----------:|:-----------------|
| ingress/discards/errors/l2/rx | Upstream device or link error | >Baseline| O(1min) | Y | Take upstream link or device out-of-service |
| ingress/discards/errors/l3/rx/ttl-expired | Tracert | <=Baseline | | N | no action |
| ingress/discards/errors/l3/rx/ttl-expired | Convergence | >Baseline | O(1s) | Y | No action |
| ingress/discards/errors/l3/rx/ttl-expired | Routing loop | >Baseline | O(1min) | Y | Roll-back change |
| .\*/policy/.\* | Policy | | | N | No action |
| ingress/discards/errors/l3/no-route | Convergence | >Baseline | O(1s) | Y | No action |
| ingress/discards/errors/l3/no-route | Config error | >Baseline | O(1min) | Y | Roll-back change |
| ingress/discards/errors/l3/no-route | Invalid destination | >Baseline | O(10min) | N | Escalate to operator |
| ingress/discards/errors/internal | Device errors | >Baseline | O(1min) | Y | Take device out-of-service |
| egress/discards/no-buffer | Congestion | <=Baseline | | N | No action |
| egress/discards/no-buffer | Congestion | >Baseline | O(1min) | Y | Bring capacity back into service or move traffic |
{: #ex-table title="Example Signal-Cause-Mitigation Mapping"}

The 'Baseline' in the 'DISCARD-RATE' column is both DISCARD-CLASS and network dependent.

# Full Information Model Tree {#sec-im-full-tree}

The following YANG tree diagram shows the complete IM structure:

~~~~~~~~~~
{::include ./yang/trees/ietf-packet-discard-reporting-sx.tree}
~~~~~~~~~~

# Full Data Model Tree {#sec-dm-full-tree}

The following YANG tree diagram shows the complete DM structure:

~~~~~~~~~~
{::include ./yang/trees/ietf-packet-discard-reporting.tree}
~~~~~~~~~~
