namespace SmartGuard.API.Services.Discord
{
    public class DiscordOptions
    {
        public const string SectionName = "Discord";

        public string BotToken { get; set; } = string.Empty;
        public ulong ChannelId { get; set; } = 0;
        public string WebhookUrl { get; set; } = string.Empty;

        public bool IsBotConfigured =>
            !string.IsNullOrWhiteSpace(BotToken) &&
            !BotToken.Equals("chuoimakhoa", StringComparison.OrdinalIgnoreCase) &&
            BotToken.Length > 30 &&
            ChannelId != 0;
        public bool IsWebhookConfigured =>
            !string.IsNullOrWhiteSpace(WebhookUrl) &&
            WebhookUrl.StartsWith("https://discord.com/api/webhooks/", StringComparison.OrdinalIgnoreCase);
    }

    public interface IDiscordAlertService
    {
        Task SendAlertWithImageAsync(
            Guid alertId,
            string deviceName,
            string triggerReason,
            string severity,
            string? localImagePath,
            string? serverBaseUrl = null);

        Task UpdateAlertActionAsync(Guid alertId, string status, string responderName);
    }
}
