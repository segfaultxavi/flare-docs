const FLARE_PACKAGE = "@flarenetwork/flare-periphery-contract-artifacts";
const FLARE_RPC = "https://flare-api.flare.network/ext/bc/C/rpc";

async function runGettingDataFeeds(_symbol) {
    console.log(`Retrieving current price of ${_symbol}...`);

    // 1. Import dependencies
    const ethers = await import("ethers");
    const flare = await import(FLARE_PACKAGE);

    // Node to submit queries to.
    const provider = new ethers.JsonRpcProvider(FLARE_RPC);

    // 2. Access the Contract Registry
    const flareContractRegistry = new ethers.Contract(
        "0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019",
        flare.nameToAbi("FlareContractRegistry", "flare").data,
        provider);

    // 3. Retrieve the FTSO Registry
    const ftsoRegistryAddr = await
        flareContractRegistry.getContractAddressByName("FtsoRegistry");
    const ftsoRegistry = new ethers.Contract(
        ftsoRegistryAddr,
        flare.nameToAbi("FtsoRegistry", "flare").data,
        provider);

    // 4. Get latest price
    const [_price, _timestamp, _decimals] =
        await ftsoRegistry["getCurrentPriceWithDecimals(string)"](_symbol);

    console.log(`${Number(_price) / Math.pow(10, Number(_decimals))} USD`);
    console.log(`Calculated at ${new Date(Number(_timestamp) * 1000)}`);
}

runGettingDataFeeds("BTC");
