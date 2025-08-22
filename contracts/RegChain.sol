// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * RegChain — Government-issued document registry (BNB Testnet)
 *
 * Core ideas:
 * - Government/issuer registers doc hash for a citizen (owner).
 * - Only hash + minimal metadata on-chain (immutable integrity anchor).
 * - Owner/issuer can grant/revoke view access to specific wallets.
 * - Optional per-viewer encrypted key blob is stored to enable decryption.
 *
 * Storage pointers:
 * - `uri` should point to BNB Greenfield object (or IPFS fallback).
 *
 * Security:
 * - Document bytes are never on-chain.
 * - Viewers read `canView` on-chain, fetch ciphertext from storage,
 *   then decrypt using an off-chain key derived from `viewerEncKey`.
 */

interface IAccessControlLite {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

abstract contract AccessControlSimple {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "ACCESS_DENIED");
        _;
    }

    constructor() {
        _roles[DEFAULT_ADMIN_ROLE][msg.sender] = true;
        emit RoleGranted(DEFAULT_ADMIN_ROLE, msg.sender, msg.sender);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _roles[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }
}

contract RegChain is AccessControlSimple {
    // --- Roles ---
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE"); // government / authorized issuer

    // --- Data structures ---
    struct Document {
        // immutable identity for the file content
        bytes32 hash;          // SHA-256 of the file
        address owner;         // citizen wallet
        string  uri;           // storage pointer (Greenfield object / IPFS CID)
        uint64  createdAt;     // block timestamp (cast)
    }

    // docHash -> Document
    mapping(bytes32 => Document) private _docs;
    // owner -> list of their doc hashes
    mapping(address => bytes32[]) private _ownerDocs;

    // docHash -> viewer -> access granted?
    mapping(bytes32 => mapping(address => bool)) private _canView;

    // OPTIONAL: docHash -> viewer -> encrypted symmetric key (e.g., AES key wrapped to viewer's pubkey)
    mapping(bytes32 => mapping(address => bytes)) private _viewerEncKey;

    // --- Events ---
    event DocumentRegistered(address indexed issuer, address indexed owner, bytes32 indexed docHash, string uri);
    event AccessGranted(bytes32 indexed docHash, address indexed viewer, bytes encKey);
    event AccessRevoked(bytes32 indexed docHash, address indexed viewer);

    // --- Modifiers ---
    modifier onlyOwnerOrIssuer(bytes32 docHash) {
        address owner = _docs[docHash].owner;
        require(owner != address(0), "DOC_NOT_FOUND");
        require(msg.sender == owner || hasRole(ISSUER_ROLE, msg.sender), "NOT_OWNER_OR_ISSUER");
        _;
    }

    // --- Core: registration by issuer ---
    /**
     * @notice Register a document for a citizen. Issuer-only.
     * @param owner  The wallet that should own this document.
     * @param docHash SHA-256 of the document bytes.
     * @param uri Storage pointer to the encrypted file (Greenfield preferred).
     */
    function registerDocumentFor(address owner, bytes32 docHash, string calldata uri)
        external
        onlyRole(ISSUER_ROLE)
    {
        require(owner != address(0), "BAD_OWNER");
        require(docHash != bytes32(0), "BAD_HASH");
        require(_docs[docHash].owner == address(0), "ALREADY_REGISTERED");

        _docs[docHash] = Document({
            hash: docHash,
            owner: owner,
            uri: uri,
            createdAt: uint64(block.timestamp)
        });

        _ownerDocs[owner].push(docHash);

        emit DocumentRegistered(msg.sender, owner, docHash, uri);
    }

    // --- Access control for viewers ---
    /**
     * @notice Grant viewer access to a document. Caller: owner or issuer.
     * @param docHash Document hash.
     * @param viewer  Wallet allowed to view.
     * @param encKey  Optional encrypted key material for the viewer (can be empty).
     */
    function grantAccess(bytes32 docHash, address viewer, bytes calldata encKey)
        external
        onlyOwnerOrIssuer(docHash)
    {
        require(viewer != address(0), "BAD_VIEWER");
        _canView[docHash][viewer] = true;
        if (encKey.length > 0) {
            _viewerEncKey[docHash][viewer] = encKey;
        }
        emit AccessGranted(docHash, viewer, encKey);
    }

    /**
     * @notice Revoke viewer access. Caller: owner or issuer.
     */
    function revokeAccess(bytes32 docHash, address viewer)
        external
        onlyOwnerOrIssuer(docHash)
    {
        _canView[docHash][viewer] = false;
        delete _viewerEncKey[docHash][viewer];
        emit AccessRevoked(docHash, viewer);
    }

    // --- Read functions ---
    function verifyDocument(bytes32 docHash) external view returns (bool) {
        return _docs[docHash].owner != address(0);
    }

    function getDocuments(address owner) external view returns (bytes32[] memory) {
        return _ownerDocs[owner];
    }

    function ownerOf(bytes32 docHash) external view returns (address) {
        return _docs[docHash].owner;
    }

    function getDocument(bytes32 docHash)
        external
        view
        returns (bytes32 hash, address owner, string memory uri, uint64 createdAt)
    {
        Document memory d = _docs[docHash];
        require(d.owner != address(0), "DOC_NOT_FOUND");
        return (d.hash, d.owner, d.uri, d.createdAt);
    }

    /**
     * @notice Check if `viewer` currently has access.
     */
    function canView(bytes32 docHash, address viewer) external view returns (bool) {
        return _canView[docHash][viewer];
    }

    /**
     * @notice Fetch the encrypted key blob for `viewer`.
     *         Only the viewer, the owner, or an issuer can read it.
     */
    function getViewerEncKey(bytes32 docHash, address viewer) external view returns (bytes memory) {
        address owner = _docs[docHash].owner;
        require(owner != address(0), "DOC_NOT_FOUND");
        require(
            msg.sender == viewer || msg.sender == owner || hasRole(ISSUER_ROLE, msg.sender),
            "FORBIDDEN"
        );
        return _viewerEncKey[docHash][viewer];
    }
}
