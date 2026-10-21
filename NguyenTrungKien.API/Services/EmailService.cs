using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace NguyenTrungKien.API.Services;

public interface IEmailService
{
    Task SendAsync(string toEmail, string toName, string subject, string html);
}

public class EmailService : IEmailService
{
    private readonly EmailOptions _opt;
    private readonly ILogger<EmailService> _log;

    public EmailService(IOptions<EmailOptions> opt, ILogger<EmailService> log)
    {
        _opt = opt.Value;
        _log = log;
    }

    public async Task SendAsync(string toEmail, string toName, string subject, string html)
    {
        if (!_opt.Enabled)
        {
            _log.LogWarning("[EMAIL DEMO] Tới {Email} | {Subject}\n{Body}", toEmail, subject, html);
            return;
        }

        var msg = new MimeMessage();
        msg.From.Add(new MailboxAddress(_opt.FromName, string.IsNullOrEmpty(_opt.FromEmail) ? _opt.UserName : _opt.FromEmail));
        msg.To.Add(new MailboxAddress(toName, toEmail));
        msg.Subject = subject;
        msg.Body = new BodyBuilder { HtmlBody = html }.ToMessageBody();

        using var smtp = new SmtpClient();
        await smtp.ConnectAsync(_opt.Host, _opt.Port, SecureSocketOptions.StartTls);
        await smtp.AuthenticateAsync(_opt.UserName, _opt.Password);
        await smtp.SendAsync(msg);
        await smtp.DisconnectAsync(true);
    }
}
