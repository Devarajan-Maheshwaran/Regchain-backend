import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { ethers } from "ethers";
import RegChainAccessAbi from "../artifacts/contracts/RegChainAccess.sol/RegChainAccess.json";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 4000;
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL || "http://localhost:8545");
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || "", provider);
const contractAddress = process.env.CONTRACT_ADDRESS || "";
const regChainContract = new ethers.Contract(contractAddress, RegChainAccessAbi.abi, wallet);

// Register document (issuer only)
app.post("/register", async (req, res) => {
  try {
    const { docHash, ownerAddress, pointer } = req.body;
    if (!docHash || !ownerAddress || !pointer) {
      return res.status(400).json({ error: "docHash, ownerAddress and pointer are required" });
    }
    const tx = await regChainContract.registerDocumentFor(docHash, ownerAddress, pointer);
    await tx.wait();
    res.json({ success: true, txHash: tx.hash });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Grant access to verifier (owner only)
app.post("/grant-access", async (req, res) => {
  try {
    const { docHash, verifierAddress, key } = req.body;
    if (!docHash || !verifierAddress || !key) {
      return res.status(400).json({ error: "docHash, verifierAddress and key are required" });
    }
    const tx = await regChainContract.grantAccess(docHash, verifierAddress, key);
    await tx.wait();
    res.json({ success: true, txHash: tx.hash });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Revoke access (owner only)
app.post("/revoke-access", async (req, res) => {
  try {
    const { docHash, verifierAddress } = req.body;
    if (!docHash || !verifierAddress) {
      return res.status(400).json({ error: "docHash and verifierAddress are required" });
    }
    const tx = await regChainContract.revokeAccess(docHash, verifierAddress);
    await tx.wait();
    res.json({ success: true, txHash: tx.hash });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get documents owned by an owner
app.get("/documents/:ownerAddress", async (req, res) => {
  try {
    const ownerAddress = req.params.ownerAddress;
    if (!ownerAddress) {
      return res.status(400).json({ error: "ownerAddress is required" });
    }
    const docs = await regChainContract.getDocumentsByOwner(ownerAddress);
    res.json({ documents: docs });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Get viewer key for document and verifier
app.get("/viewer-key", async (req, res) => {
  try {
    const { docHash, verifierAddress } = req.query;
    if (!docHash || !verifierAddress || typeof docHash !== "string" || typeof verifierAddress !== "string") {
      return res.status(400).json({ error: "docHash and verifierAddress query parameters are required" });
    }
    const key = await regChainContract.getViewerKey(docHash, verifierAddress);
    res.json({ viewerKey: key });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`API server listening on port ${PORT}`);
});
