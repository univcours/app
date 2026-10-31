# RookVanta ♜ — multiplayer chess

**Independent project** inside the \`rookvanta-mvp\` branch, in \`rookvanta/\`. No code or configurations from NovaGrid are modified.

## Features in this MVP

- Two-player live chess over Socket.IO, invite links and 6-character private room codes
- Server-validated chess rules using chess.js (castling, en passant, promotions, checkmate, stalemate and draws)
- Server-authoritative chess clocks: 3+2, 5+0, 10+0
- Interactive mobile chessboard with tap to select and highlighted legal destinations, automatic orientation for Black
- Arabic, French and English UI; invite link sharing, live move history, resign, draw offer/accept, rematch
- Secure per-player rejoin tokens in browser storage; unauthorized players cannot move or occupy a filled room
- PWA-friendly browser interface; prepared for later Android packaging

## Run locally

Requires Node.js 20+.

\`\`\`sh
cd rookvanta
npm install
npm start
\`\`\`

Open \`http://localhost:3000\` in **two browser tabs/devices**. Player 1 creates a match and shares the room code or invite link; Player 2 joins. For play across different networks, **deploy the Node server with WebSocket support and HTTPS**; GitHub Pages by itself cannot host this server.

## Deploy

Deploy the \`rookvanta/\` folder as a Node.js web service on a provider supporting long-lived WebSockets (for example Render or Railway) with:

- Install/build: \`npm ci\` (or \`npm install\` when there is no lockfile)
- Start command: \`npm start\`
- Environment: \`NODE_ENV=production\`, and the provider-assigned \`PORT\`
- Health check: \`/health\`

The client and server run on the **same domain**, so no client API URL or database credentials are needed.

## Important MVP limitations

- Games and timers are held in server memory and **will be lost after a server restart**. Deploy as one server instance. Persistent matches and horizontal scaling need Redis or a database.
- No user account, rankings, chat, payments, advertising, AI opponents, or matchmaking queue yet.
- Clocks continue even if a player disconnects. Existing player can rejoin with their local browser token. A cleared browser storage loses that seat.
- Public deployment requires abuse protection, limits and monitoring before significant traffic. Room codes are invitation links rather than authentication; the secret seat token authenticates a player.
- Product name is a working brand name, not a trademark clearance conclusion.

## Technical choices

Node.js, Socket.IO 4.8.x and chess.js 1.4.x. Only the server decides which moves are legal and when a game ends. A client cannot change the chess board by modifying browser code.
