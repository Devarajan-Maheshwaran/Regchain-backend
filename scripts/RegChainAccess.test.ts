import { expect } from "chai";
import hre from "hardhat";
import { keccak256, toUtf8Bytes } from "ethers/lib/utils";
import "@nomicfoundation/hardhat-chai-matchers";

describe("RegChainAccess Contract", function () {
  let regChain: any;
  let issuer: any;
  let owner: any;
  let verifier: any;

  beforeEach(async function () {
    const ethers = hre.ethers;
    [issuer, owner, verifier] = await ethers.getSigners();

    const RegChain = await ethers.getContractFactory("RegChainAccess");
    regChain = await RegChain.deploy(issuer.address);
    await regChain.deployed();

    const ISSUER_ROLE = await regChain.ISSUER_ROLE();
    await regChain.connect(issuer).grantRole(ISSUER_ROLE, issuer.address);
  });

  it("Only issuer can register documents", async function () {
    const hash = keccak256(toUtf8Bytes("doc1"));
    const pointer = "ipfs://Qm...";

    await expect(
      regChain.connect(owner).registerDocumentFor(hash, owner.address, pointer)
    ).to.be.revertedWith("AccessControl");

    await expect(
      regChain.connect(issuer).registerDocumentFor(hash, owner.address, pointer)
    ).to.emit(regChain, "DocumentRegistered");
  });

  it("Owner can grant and revoke access to verifier", async function () {
    const hash = keccak256(toUtf8Bytes("doc2"));
    const pointer = "ipfs://Qm...";

    await regChain.connect(issuer).registerDocumentFor(hash, owner.address, pointer);

    await expect(
      regChain.connect(verifier).grantAccess(hash, verifier.address, "key")
    ).to.be.revertedWith("Not owner");

    await expect(
      regChain.connect(owner).grantAccess(hash, verifier.address, "key")
    ).to.emit(regChain, "AccessGranted");

    expect(await regChain.getViewerKey(hash, verifier.address)).to.equal("key");

    await expect(
      regChain.connect(owner).revokeAccess(hash, verifier.address)
    ).to.emit(regChain, "AccessRevoked");

    expect(await regChain.getViewerKey(hash, verifier.address)).to.equal("");
  });
});
