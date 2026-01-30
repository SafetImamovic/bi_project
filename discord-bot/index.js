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

    const baseWebhookUrl = process.env.N8N_WEBHOOK_URL;
    if (!baseWebhookUrl) {
        return interaction.reply({ content: 'Error: N8N_WEBHOOK_URL not configured', ephemeral: true });
    }

    // Extract base URL (remove the verify-data webhook path)
    const webhookBase = baseWebhookUrl.replace(/\/webhook\/.*$/, '/webhook');

    if (interaction.commandName === 'verify-data') {
        await interaction.deferReply({ ephemeral: true });

        try {
            const res = await fetch(baseWebhookUrl, {
                method: 'GET',
                headers: { 'Content-Type': 'application/json' },
            });

            if (!res.ok) {
                return interaction.editReply('Failed to fetch data from webhook');
            }

            const data = await res.json();
            const reply = data[0].text;
            await interaction.editReply(reply);
        } catch (error) {
            console.error('Webhook error:', error);
            await interaction.editReply('Error connecting to webhook');
        }
    }

    if (interaction.commandName === 'insurance-report') {
        await interaction.deferReply({ ephemeral: false });

        try {
            const res = await fetch(`${webhookBase}/insurance-report`, {
                method: 'GET',
                headers: { 'Content-Type': 'application/json' },
            });

            if (!res.ok) {
                return interaction.editReply('Failed to fetch insurance report');
            }

            const data = await res.json();
            await interaction.editReply(data.message || data[0]?.text || 'No data available');
        } catch (error) {
            console.error('Insurance report error:', error);
            await interaction.editReply('Error fetching insurance report');
        }
    }

    if (interaction.commandName === 'top-insurers') {
        await interaction.deferReply({ ephemeral: false });

        try {
            const res = await fetch(`${webhookBase}/top-insurers`, {
                method: 'GET',
                headers: { 'Content-Type': 'application/json' },
            });

            if (!res.ok) {
                return interaction.editReply('Failed to fetch top insurers');
            }

            const data = await res.json();
            await interaction.editReply(data.message || data[0]?.text || 'No data available');
        } catch (error) {
            console.error('Top insurers error:', error);
            await interaction.editReply('Error fetching top insurers');
        }
    }
});
