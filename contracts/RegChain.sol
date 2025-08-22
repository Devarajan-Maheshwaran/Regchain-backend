// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RegChainAccess is AccessControl {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    struct Document {
        address owner;
        address issuer;
        string pointer; // off-chain file location (BNB Greenfield/IPFS/URL)
        mapping(address => string) viewerKey; // verifier => encrypted key
        mapping(address => bool) allowedViewers;
    }

    mapping(bytes32 => Document) private documents;
    mapping(address => bytes32[]) private ownerDocs;

    event DocumentRegistered(address indexed issuer, address indexed owner, bytes32 indexed docHash, string pointer);
    event AccessGranted(bytes32 docHash, address indexed owner, address indexed viewer, string viewerKey);
    event AccessRevoked(bytes32 docHash, address indexed owner, address indexed viewer);

    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ISSUER registers a document for the citizen (owner)
    function registerDocumentFor(bytes32 docHash, address owner, string calldata pointer)
        external onlyRole(ISSUER_ROLE)
    {
        require(docHash != 0, "Invalid hash");
        Document storage doc = documents[docHash];
        require(doc.owner == address(0), "Already registered");
        doc.owner = owner;
        doc.issuer = msg.sender;
        doc.pointer = pointer;
        ownerDocs[owner].push(docHash);
        emit DocumentRegistered(msg.sender, owner, docHash, pointer);
    }

    // OWNER grants access to a verifier with encrypted key
    function grantAccess(bytes32 docHash, address viewer, string calldata viewerKey)
        external
    {
        Document storage doc = documents[docHash];
        require(doc.owner == msg.sender, "Not owner");
        doc.allowedViewers[viewer] = true;
        doc.viewerKey[viewer] = viewerKey;
        emit AccessGranted(docHash, msg.sender, viewer, viewerKey);
    }

    // OWNER revokes access for a verifier
    function revokeAccess(bytes32 docHash, address viewer)
        external
    {
        Document storage doc = documents[docHash];
        require(doc.owner == msg.sender, "Not owner");
        doc.allowedViewers[viewer] = false;
        doc.viewerKey[viewer] = "";
        emit AccessRevoked(docHash, msg.sender, viewer);
    }

    // Anyone can verify document integrity
    function verifyDocument(bytes32 docHash) external view returns (bool) {
        return documents[docHash].owner != address(0);
    }

    // Get doc info (pointer, owner, issuer)
    function getDocumentInfo(bytes32 docHash) external view returns
        (address, address, string memory)
    {
        Document storage doc = documents[docHash];
        return (doc.owner, doc.issuer, doc.pointer);
    }

    // Owner can list their documents
    function getDocumentsByOwner(address owner)
        external view returns (bytes32[] memory)
    {
        return ownerDocs[owner];
    }

    // Verifier checks if they have access and gets their encrypted viewing key blob
    function getViewerKey(bytes32 docHash, address viewer)
        external view returns (string memory)
    {
        Document storage doc = documents[docHash];
        if (doc.allowedViewers[viewer]) {
            return doc.viewerKey[viewer];
        }
        return "";
    }
}
