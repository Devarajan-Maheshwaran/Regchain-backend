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

// Connect to local Hardhat node or use RPC from env
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL || "http://localhost:8545");

// Wallet from private key to sign transactions
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || "", provider);

// Contract instance
const regChainContract = new ethers.Contract(process.env.CONTRACT_ADDRESS || "", RegChainAccessAbi.abi, wallet);

// Routes

// Example: Register document (issuer only)
app.post("/register", async (req, res) => {
  try {
    const { docHash, ownerAddress, pointer } = req.body;
    const tx = await regChainContract.registerDocumentFor(docHash, ownerAddress, pointer);
    await tx.wait();
    res.json({ success: true, txHash: tx.hash });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Other routes you can add:
// - Verify document
// - Grant access
// - Revoke access
// - Get documents by owner
// - Lookup viewer key

app.listen(PORT, () => {
  console.log(`API server listening on port ${PORT}`);
});
