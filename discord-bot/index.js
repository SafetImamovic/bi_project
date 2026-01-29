require('dotenv').config();
const { Client, Collection, GatewayIntentBits } = require('discord.js');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));


const client = new Client({
    intents: [GatewayIntentBits.Guilds],
});

client.commands = new Collection();

client.once('ready', () => {
    console.log(`Logged in as ${client.user.tag}`);
});

client.login(process.env.DISCORD_TOKEN);

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;


    if (interaction.commandName === 'verify-data') {
        await interaction.deferReply({ ephemeral: true });

        const res = await fetch('https://unsocialised-sweetless-journee.ngrok-free.dev/webhook/346ac09a-5cbe-4970-8a7b-6765876ff5da', {
            method: 'GET',
            headers: { 'Content-Type': 'application/json' },
        });

        const data = await res.json();
        const reply = data.data.map(item => `${item.tbl}: ${item.cnt}`).join('\n');

        if (!res.ok) {
            return interaction.editReply('Failed');
        }

        await interaction.editReply(reply);
    }
});
