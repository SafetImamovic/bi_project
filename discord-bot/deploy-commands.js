// Load environment from parent directory's .env file
require('dotenv').config({ path: require('path').resolve(__dirname, '..', '.env') });

const { REST, Routes } = require('discord.js');

const commands = [
    {
        name: 'verify-data',
        description: 'Verify ETL data counts via n8n webhook',
    },
];

const rest = new REST({ version: '10' }).setToken(process.env.DISCORD_TOKEN);

(async () => {
    try {
        console.log('Registering commands...');

        await rest.put(
            Routes.applicationGuildCommands(
                process.env.DISCORD_CLIENT_ID,
                process.env.DISCORD_GUILD_ID
            ),
            { body: commands }
        );

        console.log('Commands registered!');
    } catch (error) {
        console.error(error);
    }
})();
