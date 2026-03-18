const path = require("path");
const { runProtocolEngine } = require("../protocol-runner");

runProtocolEngine({
  elmModulePath: path.join(__dirname, "chess.js"),
  args: process.argv.slice(2),
}).catch((error) => {
  console.error("ERROR: Failed to initialize Elm chess engine");
  console.error(error && error.message ? error.message : String(error));
  process.exit(1);
});
