// Load environment from parent directory's .env file
require('dotenv').config({ path: require('path').resolve(__dirname, '..', '.env') });

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

        const webhookUrl = process.env.N8N_WEBHOOK_URL;
        if (!webhookUrl) {
            return interaction.editReply('Error: N8N_WEBHOOK_URL not configured');
        }

        try {
            const res = await fetch(webhookUrl, {
                method: 'GET',
                headers: { 'Content-Type': 'application/json' },
            });

            if (!res.ok) {
                return interaction.editReply('Failed to fetch data from webhook');
            }


            const data = await res.json();
            console.log(data);
            const reply = data[0].text;
            console.log(reply);

            await interaction.editReply(reply);
        } catch (error) {
            console.error('Webhook error:', error);
            await interaction.editReply('Error connecting to webhook');
        }
    }
});
