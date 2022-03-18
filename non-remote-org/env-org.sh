
######################################################################################
# The following section will be merged into env.sh and used to configure a remote peer
######################################################################################

# Type of network. Options are: POC or PROD
# If FABRIC_NETWORK_TYPE="PROD" I will generate NLB (network load balancers) to expose the orderers and anchor peers
# so they can communicate with remote peers located in other regions and/or accounts. This simulates a production network
# which consists of remote members, with peers on premise or on other Cloud platforms.
# If FABRIC_NETWORK_TYPE="POC" I will assume all peers and orderers are running in the same account / region and will
# assume local, in-cluster DNS using standard Kuberentes service names for lookup
FABRIC_NETWORK_TYPE="POC"


# Names of the peer organizations.
PEER_ORGS=$3
PEER_DOMAINS=$1
PEER_PREFIX="peer"

# Number of peers in each peer organization
NUM_PEERS=1

REMOTE_PEER=false

